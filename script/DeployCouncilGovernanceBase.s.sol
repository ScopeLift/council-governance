// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {CouncilERC20} from "src/CouncilERC20.sol";

abstract contract DeployCouncilGovernanceBase is Script {
  struct CouncilTokenParams {
    string name;
    string symbol;
    address admin;
    uint256 maxTokensPerMember;
    address[] councilMembers;
  }

  struct TimelockParams {
    uint256 minDelay;
  }

  struct CouncilGovernorParams {
    string name;
    uint48 votingDelay;
    uint32 votingPeriod;
    uint256 proposalThreshold;
    uint256 quorumNumerator;
    uint256 superQuorumNumerator;
    address admin;
  }

  struct VetoGovernorParams {
    string name;
    address daoToken;
    uint48 votingDelay;
    uint32 votingPeriod;
    address vetoGuardian;
    address vetoOverrideRole;
    uint48 vetoOverrideDuration;
    uint48 votingPeriodExtension;
    uint16 votingPeriodExtensionThresholdPct;
    uint256 vetoThresholdNumerator;
    address admin;
    bool acknowledgeBlockNumberFallback;
  }

  CouncilERC20 public councilToken;
  TimelockController public timelock;
  BasicCouncilGovernor public councilGovernor;
  BasicCouncilVetoGovernor public vetoGovernor;

  bool internal isLogging = true;

  function run() public virtual {
    CouncilTokenParams memory _tokenParams = _getCouncilTokenParams();
    TimelockParams memory _timelockParams = _getTimelockParams();
    CouncilGovernorParams memory _councilParams = _getCouncilGovernorParams();
    VetoGovernorParams memory _vetoParams = _getVetoGovernorParams();
    address _broadcaster = tx.origin;

    _validateDeploymentParams(_tokenParams, _councilParams, _vetoParams);
    _validateVetoToken(_vetoParams);
    _logConfiguration(_tokenParams, _timelockParams, _councilParams, _vetoParams, _broadcaster);

    address[] memory _emptyAccounts = new address[](0);
    uint256 _transactionCount = _tokenParams.councilMembers.length + 8;

    vm.startBroadcast();
    // BROADCAST: deploy the timestamp-clock council token
    _logStep(1, _transactionCount, "Deploying CouncilERC20");
    councilToken = new CouncilERC20(
      _tokenParams.name, _tokenParams.symbol, _broadcaster, _tokenParams.maxTokensPerMember
    );
    for (uint256 _i = 0; _i < _tokenParams.councilMembers.length; _i += 1) {
      // BROADCAST: mint and self-delegate one council membership allocation
      _log(
        string.concat(
          "[",
          vm.toString(_i + 2),
          "/",
          vm.toString(_transactionCount),
          "] Minting one member allocation to ",
          vm.toString(_tokenParams.councilMembers[_i])
        )
      );
      councilToken.mint(_tokenParams.councilMembers[_i], _tokenParams.maxTokensPerMember);
    }
    // BROADCAST: transfer council-token ownership from the broadcaster to the configured admin
    _logStep(
      _tokenParams.councilMembers.length + 2,
      _transactionCount,
      string.concat("Transferring council-token ownership to ", vm.toString(_tokenParams.admin))
    );
    councilToken.transferOwnership(_tokenParams.admin);
    // BROADCAST: deploy the timelock with the broadcaster as temporary admin
    _logStep(_tokenParams.councilMembers.length + 3, _transactionCount, "Deploying timelock");
    timelock = new TimelockController(
      _timelockParams.minDelay, _emptyAccounts, _emptyAccounts, _broadcaster
    );
    vm.stopBroadcast();

    uint256 _currentNonce = vm.getNonce(_broadcaster);
    address _predictedVetoGovernor = vm.computeCreateAddress(_broadcaster, _currentNonce + 1);
    BasicCouncilGovernor.InitialCouncilParams memory _initialCouncilParams =
      BasicCouncilGovernor.InitialCouncilParams({
        initialVotingDelay: _councilParams.votingDelay,
        initialVotingPeriod: _councilParams.votingPeriod,
        initialProposalThreshold: _councilParams.proposalThreshold,
        initialQuorumFraction: _councilParams.quorumNumerator,
        initialSuperQuorumFraction: _councilParams.superQuorumNumerator
      });
    BasicCouncilVetoGovernor.ConstructorParams memory _initialVetoParams =
      BasicCouncilVetoGovernor.ConstructorParams({
        name: _vetoParams.name,
        token: _vetoParams.daoToken,
        votingDelay: _vetoParams.votingDelay,
        votingPeriod: _vetoParams.votingPeriod,
        proposalThreshold: 0,
        vetoGuardian: _vetoParams.vetoGuardian,
        vetoOverrideRole: _vetoParams.vetoOverrideRole,
        vetoOverrideDuration: _vetoParams.vetoOverrideDuration,
        votingPeriodExtension: _vetoParams.votingPeriodExtension,
        votingPeriodExtensionThresholdPct: _vetoParams.votingPeriodExtensionThresholdPct,
        vetoThresholdNumerator: _vetoParams.vetoThresholdNumerator,
        timelock: timelock,
        governorAdmin: _vetoParams.admin,
        council: address(0)
      });

    vm.startBroadcast();
    // BROADCAST: deploy the council governor wired to the predicted veto governor
    _logStep(
      _tokenParams.councilMembers.length + 4, _transactionCount, "Deploying council governor"
    );
    councilGovernor = new BasicCouncilGovernor(
      _councilParams.name,
      IERC5805(address(councilToken)),
      IGovernor(_predictedVetoGovernor),
      _councilParams.admin,
      _initialCouncilParams
    );
    _initialVetoParams.council = address(councilGovernor);
    // BROADCAST: deploy the configured veto-governor variant
    _logStep(_tokenParams.councilMembers.length + 5, _transactionCount, "Deploying veto governor");
    vetoGovernor = _deployVetoGovernor(_initialVetoParams);
    // BROADCAST: grant the veto governor the timelock proposer role
    _logStep(_tokenParams.councilMembers.length + 6, _transactionCount, "Granting proposer role");
    timelock.grantRole(timelock.PROPOSER_ROLE(), address(vetoGovernor));
    // BROADCAST: grant the veto governor the timelock executor role
    _logStep(_tokenParams.councilMembers.length + 7, _transactionCount, "Granting executor role");
    timelock.grantRole(timelock.EXECUTOR_ROLE(), address(vetoGovernor));
    // BROADCAST: renounce the broadcaster's temporary timelock admin role
    _logStep(
      _tokenParams.councilMembers.length + 8, _transactionCount, "Renouncing temporary admin"
    );
    timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), _broadcaster);
    vm.stopBroadcast();

    _validateDeployment(
      _tokenParams,
      _timelockParams,
      _councilParams,
      _vetoParams,
      _broadcaster,
      _predictedVetoGovernor
    );
    _log(string.concat("CouncilERC20 deployed at ", vm.toString(address(councilToken))));
    _log(string.concat("TimelockController deployed at ", vm.toString(address(timelock))));
    _log(string.concat("BasicCouncilGovernor deployed at ", vm.toString(address(councilGovernor))));
    _log(string.concat("Veto governor deployed at ", vm.toString(address(vetoGovernor))));
  }

  function disableLogging() public {
    isLogging = false;
  }

  function _getCouncilTokenParams() internal view virtual returns (CouncilTokenParams memory);
  function _getTimelockParams() internal view virtual returns (TimelockParams memory);
  function _getCouncilGovernorParams() internal view virtual returns (CouncilGovernorParams memory);
  function _getVetoGovernorParams() internal view virtual returns (VetoGovernorParams memory);
  function _validateVetoToken(VetoGovernorParams memory _params) internal view virtual;
  function _logVetoClock(VetoGovernorParams memory _params) internal view virtual;

  function _deployVetoGovernor(BasicCouncilVetoGovernor.ConstructorParams memory _params)
    internal
    virtual
    returns (BasicCouncilVetoGovernor);

  function _logConfiguration(
    CouncilTokenParams memory _tokenParams,
    TimelockParams memory _timelockParams,
    CouncilGovernorParams memory _councilParams,
    VetoGovernorParams memory _vetoParams,
    address _broadcaster
  ) internal view {
    _log(string.concat("Broadcaster: ", vm.toString(_broadcaster)));
    _log(string.concat("Council token: ", _tokenParams.name, " (", _tokenParams.symbol, ")"));
    _log(string.concat("Council token admin: ", vm.toString(_tokenParams.admin)));
    _log(string.concat("Council members: ", vm.toString(_tokenParams.councilMembers.length)));
    _log(string.concat("Tokens per member: ", vm.toString(_tokenParams.maxTokensPerMember)));
    _log(string.concat("Timelock delay (seconds): ", vm.toString(_timelockParams.minDelay)));
    _log(string.concat("Council governor: ", _councilParams.name));
    _log(string.concat("Council voting delay (seconds): ", vm.toString(_councilParams.votingDelay)));
    _log(
      string.concat("Council voting period (seconds): ", vm.toString(_councilParams.votingPeriod))
    );
    _log(
      string.concat("Council proposal threshold: ", vm.toString(_councilParams.proposalThreshold))
    );
    _log(string.concat("Council quorum (%): ", vm.toString(_councilParams.quorumNumerator)));
    _log(
      string.concat("Council super quorum (%): ", vm.toString(_councilParams.superQuorumNumerator))
    );
    _log(string.concat("Council governor admin: ", vm.toString(_councilParams.admin)));
    _log(string.concat("Veto governor: ", _vetoParams.name));
    _log(string.concat("DAO token: ", vm.toString(_vetoParams.daoToken)));
    _log(string.concat("Veto threshold (%): ", vm.toString(_vetoParams.vetoThresholdNumerator)));
    _log(string.concat("Veto guardian: ", vm.toString(_vetoParams.vetoGuardian)));
    _log(string.concat("Veto override role: ", vm.toString(_vetoParams.vetoOverrideRole)));
    _log(string.concat("Veto governor admin: ", vm.toString(_vetoParams.admin)));
    _logVetoClock(_vetoParams);
  }

  function _validateDeploymentParams(
    CouncilTokenParams memory _tokenParams,
    CouncilGovernorParams memory _councilParams,
    VetoGovernorParams memory _vetoParams
  ) internal pure {
    if (bytes(_tokenParams.name).length == 0) {
      revert("DeployCouncilGovernanceBase: empty token name");
    }
    if (bytes(_tokenParams.symbol).length == 0) {
      revert("DeployCouncilGovernanceBase: empty token symbol");
    }
    if (bytes(_councilParams.name).length == 0) {
      revert("DeployCouncilGovernanceBase: empty council governor name");
    }
    if (bytes(_vetoParams.name).length == 0) {
      revert("DeployCouncilGovernanceBase: empty veto governor name");
    }
    if (_tokenParams.admin == address(0)) {
      revert("DeployCouncilGovernanceBase: token admin is zero");
    }
    if (_councilParams.admin == address(0)) {
      revert("DeployCouncilGovernanceBase: council governor admin is zero");
    }
    if (_vetoParams.admin == address(0)) {
      revert("DeployCouncilGovernanceBase: veto governor admin is zero");
    }
    if (_vetoParams.daoToken == address(0)) {
      revert("DeployCouncilGovernanceBase: DAO token is zero");
    }
    if (_tokenParams.councilMembers.length == 0) {
      revert("DeployCouncilGovernanceBase: council member list is empty");
    }
    if (_tokenParams.maxTokensPerMember < 1e18) {
      revert(
        "DeployCouncilGovernanceBase: tokens per member is below 1e18; "
        "set at least one whole 18-decimal council token per member"
      );
    }
    if (_councilParams.votingPeriod == 0) {
      revert("DeployCouncilGovernanceBase: council voting period is zero");
    }
    if (_vetoParams.votingPeriod == 0) {
      revert("DeployCouncilGovernanceBase: veto voting period is zero");
    }
    if (_councilParams.quorumNumerator > 100) {
      revert("DeployCouncilGovernanceBase: council quorum exceeds 100");
    }
    if (_councilParams.superQuorumNumerator > 100) {
      revert("DeployCouncilGovernanceBase: council super quorum exceeds 100");
    }
    if (_councilParams.superQuorumNumerator < _councilParams.quorumNumerator) {
      revert("DeployCouncilGovernanceBase: super quorum is below quorum");
    }
    if (_vetoParams.vetoThresholdNumerator > 100) {
      revert("DeployCouncilGovernanceBase: veto threshold exceeds 100");
    }
    if (_vetoParams.votingPeriodExtensionThresholdPct > 100) {
      revert("DeployCouncilGovernanceBase: extension threshold exceeds 100");
    }
    for (uint256 _i = 0; _i < _tokenParams.councilMembers.length; _i += 1) {
      if (_tokenParams.councilMembers[_i] == address(0)) {
        revert("DeployCouncilGovernanceBase: council member is zero");
      }
      for (uint256 _j = _i + 1; _j < _tokenParams.councilMembers.length; _j += 1) {
        if (_tokenParams.councilMembers[_i] == _tokenParams.councilMembers[_j]) {
          revert("DeployCouncilGovernanceBase: duplicate council member");
        }
      }
    }
  }

  function _validateDeployment(
    CouncilTokenParams memory _tokenParams,
    TimelockParams memory _timelockParams,
    CouncilGovernorParams memory _councilParams,
    VetoGovernorParams memory _vetoParams,
    address _broadcaster,
    address _predictedVetoGovernor
  ) internal view {
    if (address(vetoGovernor) != _predictedVetoGovernor) {
      revert("DeployCouncilGovernanceBase: veto governor address prediction failed");
    }
    if (keccak256(bytes(councilToken.name())) != keccak256(bytes(_tokenParams.name))) {
      revert("DeployCouncilGovernanceBase: token name mismatch");
    }
    if (keccak256(bytes(councilToken.symbol())) != keccak256(bytes(_tokenParams.symbol))) {
      revert("DeployCouncilGovernanceBase: token symbol mismatch");
    }
    if (councilToken.owner() != _tokenParams.admin) {
      revert("DeployCouncilGovernanceBase: token admin mismatch");
    }
    if (councilToken.MAX_TOKENS_PER_MEMBER() != _tokenParams.maxTokensPerMember) {
      revert("DeployCouncilGovernanceBase: member allocation mismatch");
    }
    if (timelock.getMinDelay() != _timelockParams.minDelay) {
      revert("DeployCouncilGovernanceBase: timelock delay mismatch");
    }
    if (address(councilGovernor.token()) != address(councilToken)) {
      revert("DeployCouncilGovernanceBase: council token wiring mismatch");
    }
    if (address(councilGovernor.councilVetoGovernor()) != address(vetoGovernor)) {
      revert("DeployCouncilGovernanceBase: veto governor wiring mismatch");
    }
    if (councilGovernor.owner() != _councilParams.admin) {
      revert("DeployCouncilGovernanceBase: council admin mismatch");
    }
    if (address(vetoGovernor.token()) != _vetoParams.daoToken) {
      revert("DeployCouncilGovernanceBase: DAO token wiring mismatch");
    }
    if (address(vetoGovernor.timelock()) != address(timelock)) {
      revert("DeployCouncilGovernanceBase: timelock wiring mismatch");
    }
    if (vetoGovernor.COUNCIL() != address(councilGovernor)) {
      revert("DeployCouncilGovernanceBase: council wiring mismatch");
    }
    if (vetoGovernor.owner() != _vetoParams.admin) {
      revert("DeployCouncilGovernanceBase: veto admin mismatch");
    }
    uint256 _expectedSupply = _tokenParams.councilMembers.length * _tokenParams.maxTokensPerMember;
    if (councilToken.totalSupply() != _expectedSupply) {
      revert("DeployCouncilGovernanceBase: token supply mismatch");
    }
    for (uint256 _i = 0; _i < _tokenParams.councilMembers.length; _i += 1) {
      address _member = _tokenParams.councilMembers[_i];
      if (councilToken.balanceOf(_member) != _tokenParams.maxTokensPerMember) {
        revert("DeployCouncilGovernanceBase: member balance mismatch");
      }
      if (councilToken.delegates(_member) != _member) {
        revert("DeployCouncilGovernanceBase: member delegation mismatch");
      }
    }
    if (!timelock.hasRole(timelock.PROPOSER_ROLE(), address(vetoGovernor))) {
      revert("DeployCouncilGovernanceBase: proposer role missing");
    }
    if (!timelock.hasRole(timelock.EXECUTOR_ROLE(), address(vetoGovernor))) {
      revert("DeployCouncilGovernanceBase: executor role missing");
    }
    if (!timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock))) {
      revert("DeployCouncilGovernanceBase: timelock self-admin missing");
    }
    if (timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), _broadcaster)) {
      revert("DeployCouncilGovernanceBase: broadcaster retained admin");
    }
    if (timelock.hasRole(timelock.CANCELLER_ROLE(), _broadcaster)) {
      revert("DeployCouncilGovernanceBase: broadcaster has canceller role");
    }
    if (timelock.hasRole(timelock.CANCELLER_ROLE(), address(councilGovernor))) {
      revert("DeployCouncilGovernanceBase: council governor has canceller role");
    }
    if (timelock.hasRole(timelock.CANCELLER_ROLE(), address(vetoGovernor))) {
      revert("DeployCouncilGovernanceBase: veto governor has canceller role");
    }
  }

  function _logStep(uint256 _step, uint256 _total, string memory _message) internal view {
    _log(string.concat("[", vm.toString(_step), "/", vm.toString(_total), "] ", _message));
  }

  function _log(string memory _message) internal view {
    if (isLogging) console2.log(_message);
  }
}
