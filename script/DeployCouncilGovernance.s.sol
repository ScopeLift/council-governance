// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

import {CouncilERC20} from "src/CouncilERC20.sol";
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";

abstract contract DeployCouncilGovernance is Script {
  struct CouncilTokenParams {
    string name;
    string symbol;
    address admin;
    uint256 maxTokensPerMember;
    address[] members;
  }

  struct TimelockParams {
    uint256 minDelay;
  }

  struct CouncilGovernorParams {
    string name;
    uint48 votingDelay;
    uint32 votingPeriod;
    uint256 proposalThreshold;
    uint256 quorumFraction;
    uint256 superQuorumFraction;
    address admin;
  }

  struct VetoGovernorParams {
    string name;
    address token;
    uint48 votingDelay;
    uint32 votingPeriod;
    uint256 proposalThreshold;
    address vetoGuardian;
    address vetoOverrideRole;
    uint48 vetoOverrideDuration;
    uint48 votingPeriodExtension;
    uint16 votingPeriodExtensionThresholdPct;
    uint256 vetoThresholdNumerator;
    address governorAdmin;
  }

  CouncilERC20 public councilToken;
  TimelockController public timelock;
  BasicCouncilGovernor public councilGovernor;
  BasicCouncilVetoGovernor public vetoGovernor;

  bool internal isLogging = true;

  function disableLogging() public {
    isLogging = false;
  }

  function run() public virtual {
    CouncilTokenParams memory _tokenParams = _getCouncilTokenParams();
    TimelockParams memory _timelockParams = _getTimelockParams();
    CouncilGovernorParams memory _councilParams = _getCouncilGovernorParams();
    VetoGovernorParams memory _vetoParams = _getVetoGovernorParams();

    _validateCouncilTokenParams(_tokenParams);
    _validateTimelockParams(_timelockParams);
    _validateCouncilGovernorParams(_councilParams);
    _validateVetoGovernorParams(_vetoParams);

    _logConfiguration(_tokenParams, _timelockParams, _councilParams, _vetoParams);

    vm.startBroadcast(msg.sender);

    // BROADCAST: deploy the CouncilERC20
    _log("[1/N+2] Deploying CouncilERC20");
    councilToken = new CouncilERC20(
      _tokenParams.name, _tokenParams.symbol, _tokenParams.admin, _tokenParams.maxTokensPerMember
    );

    // BROADCAST: mint tokens to each council member (one transaction per member)
    for (uint256 _i = 0; _i < _tokenParams.members.length; _i++) {
      _log(
        string.concat(
          "[",
          _toStr(_i + 2),
          "/N+2] Minting ",
          _toStr(_tokenParams.maxTokensPerMember),
          " tokens to council member ",
          vm.toString(_tokenParams.members[_i])
        )
      );
      councilToken.mint(_tokenParams.members[_i], _tokenParams.maxTokensPerMember);
    }

    // BROADCAST: deploy the TimelockController with empty proposer/executor arrays
    address[] memory _empty = new address[](0);
    _log(
      string.concat(
        "[", _toStr(_tokenParams.members.length + 2), "/N+2] Deploying TimelockController"
      )
    );
    timelock = new TimelockController(_timelockParams.minDelay, _empty, _empty, msg.sender);

    vm.stopBroadcast();

    address _deployer = msg.sender;
    address _predictedVetoGovernor = _predictVetoGovernorAddress(_deployer);

    _log(string.concat("CouncilERC20 deployed at ", vm.toString(address(councilToken))));
    _log(string.concat("TimelockController deployed at ", vm.toString(address(timelock))));

    vm.startBroadcast(msg.sender);

    BasicCouncilGovernor.InitialCouncilParams memory _initialCouncilParams =
      BasicCouncilGovernor.InitialCouncilParams(
        _councilParams.votingDelay,
        _councilParams.votingPeriod,
        _councilParams.proposalThreshold,
        _councilParams.quorumFraction,
        _councilParams.superQuorumFraction
      );

    // BROADCAST: deploy the BasicCouncilGovernor with the predicted veto governor address
    _log(
      string.concat(
        "[", _toStr(_tokenParams.members.length + 3), "/N+7] Deploying BasicCouncilGovernor"
      )
    );
    councilGovernor = new BasicCouncilGovernor(
      _councilParams.name,
      IERC5805(address(councilToken)),
      IGovernor(_predictedVetoGovernor),
      _councilParams.admin,
      _initialCouncilParams
    );

    // BROADCAST: deploy the veto governor via adapter hook
    _log(
      string.concat("[", _toStr(_tokenParams.members.length + 4), "/N+7] Deploying veto governor")
    );
    vetoGovernor = _deployVetoGovernor(_vetoParams, timelock, address(councilGovernor));

    // BROADCAST: grant PROPOSER_ROLE to the veto governor on the timelock
    _log(
      string.concat(
        "[",
        _toStr(_tokenParams.members.length + 5),
        "/N+7] Granting PROPOSER_ROLE to veto governor"
      )
    );
    timelock.grantRole(timelock.PROPOSER_ROLE(), address(vetoGovernor));

    // BROADCAST: grant EXECUTOR_ROLE to the veto governor on the timelock
    _log(
      string.concat(
        "[",
        _toStr(_tokenParams.members.length + 6),
        "/N+7] Granting EXECUTOR_ROLE to veto governor"
      )
    );
    timelock.grantRole(timelock.EXECUTOR_ROLE(), address(vetoGovernor));

    // BROADCAST: renounce the deployer's DEFAULT_ADMIN_ROLE on the timelock
    _log(
      string.concat(
        "[", _toStr(_tokenParams.members.length + 7), "/N+7] Renouncing DEFAULT_ADMIN_ROLE"
      )
    );
    timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), _deployer);

    vm.stopBroadcast();

    _log(string.concat("BasicCouncilGovernor deployed at ", vm.toString(address(councilGovernor))));
    _log(string.concat("VetoGovernor deployed at ", vm.toString(address(vetoGovernor))));

    _validateDeployment(
      _deployer, _tokenParams, _timelockParams, _councilParams, _vetoParams, _predictedVetoGovernor
    );
  }

  function _getCouncilTokenParams() internal view virtual returns (CouncilTokenParams memory);
  function _getTimelockParams() internal view virtual returns (TimelockParams memory);
  function _getCouncilGovernorParams() internal view virtual returns (CouncilGovernorParams memory);
  function _getVetoGovernorParams() internal view virtual returns (VetoGovernorParams memory);

  function _deployVetoGovernor(
    VetoGovernorParams memory _params,
    TimelockController _timelock,
    address _councilGovernor
  ) internal virtual returns (BasicCouncilVetoGovernor);

  function _log(string memory _msg) internal view {
    if (isLogging) console2.log(_msg);
  }

  function _toStr(uint256 _value) internal pure returns (string memory) {
    return vm.toString(_value);
  }

  function _predictVetoGovernorAddress(address _deployer) internal view returns (address) {
    uint256 _nextNonce = vm.getNonce(_deployer) + 1;
    return vm.computeCreateAddress(_deployer, _nextNonce);
  }

  function _validateCouncilTokenParams(CouncilTokenParams memory _params) internal pure {
    if (bytes(_params.name).length == 0) {
      revert(
        "DeployCouncilGovernance: council token name is empty; " "set it to a non-empty string"
      );
    }
    if (bytes(_params.symbol).length == 0) {
      revert(
        "DeployCouncilGovernance: council token symbol is empty; " "set it to a non-empty string"
      );
    }
    if (_params.admin == address(0)) {
      revert(
        "DeployCouncilGovernance: council token admin is the zero address; "
        "set it to a non-zero address"
      );
    }
    if (_params.maxTokensPerMember == 0) {
      revert("DeployCouncilGovernance: maxTokensPerMember is zero; " "set it to a non-zero value");
    }
    if (_params.members.length == 0) {
      revert("DeployCouncilGovernance: council members list is empty; " "add at least one member");
    }
    for (uint256 _i = 0; _i < _params.members.length; _i++) {
      if (_params.members[_i] == address(0)) {
        revert(
          "DeployCouncilGovernance: council member at index "
          "is the zero address; all members must be non-zero"
        );
      }
      for (uint256 _j = _i + 1; _j < _params.members.length; _j++) {
        if (_params.members[_i] == _params.members[_j]) {
          revert(
            "DeployCouncilGovernance: duplicate council member found; " "all members must be unique"
          );
        }
      }
    }
  }

  function _validateTimelockParams(TimelockParams memory _params) internal pure {
    // minDelay may be zero to disable the timelock delay.
  }

  function _validateCouncilGovernorParams(CouncilGovernorParams memory _params) internal pure {
    if (bytes(_params.name).length == 0) {
      revert(
        "DeployCouncilGovernance: council governor name is empty; " "set it to a non-empty string"
      );
    }
    if (_params.admin == address(0)) {
      revert(
        "DeployCouncilGovernance: council governor admin is the zero address; "
        "set it to a non-zero address"
      );
    }
    if (_params.votingPeriod == 0) {
      revert(
        "DeployCouncilGovernance: council governor voting period is zero; "
        "set it to a non-zero value"
      );
    }
    if (_params.quorumFraction > 100) {
      revert(
        "DeployCouncilGovernance: council governor quorum fraction is above 100; "
        "set it to a value between 0 and 100"
      );
    }
    if (_params.superQuorumFraction > 100) {
      revert(
        "DeployCouncilGovernance: council governor super quorum fraction is above 100; "
        "set it to a value between 0 and 100"
      );
    }
    if (_params.superQuorumFraction < _params.quorumFraction) {
      revert(
        "DeployCouncilGovernance: council governor super quorum fraction is below quorum "
        "fraction; super quorum must be at least quorum"
      );
    }
  }

  function _validateVetoGovernorParams(VetoGovernorParams memory _params) internal view virtual {
    if (bytes(_params.name).length == 0) {
      revert(
        "DeployCouncilGovernance: veto governor name is empty; " "set it to a non-empty string"
      );
    }
    if (_params.token == address(0)) {
      revert(
        "DeployCouncilGovernance: veto governor token is the zero address; "
        "set it to the address of the DAO token"
      );
    }
    if (_params.votingPeriod == 0) {
      revert(
        "DeployCouncilGovernance: veto governor voting period is zero; "
        "set it to a non-zero value"
      );
    }
    if (_params.vetoThresholdNumerator > 100) {
      revert(
        "DeployCouncilGovernance: veto threshold numerator is above 100; "
        "set it to a value between 0 and 100"
      );
    }
    if (_params.votingPeriodExtensionThresholdPct > 100) {
      revert(
        "DeployCouncilGovernance: voting period extension threshold is above 100; "
        "set it to a value between 0 and 100"
      );
    }
  }

  function _logConfiguration(
    CouncilTokenParams memory _tokenParams,
    TimelockParams memory _timelockParams,
    CouncilGovernorParams memory _councilParams,
    VetoGovernorParams memory _vetoParams
  ) internal view virtual {
    _log("=== Deployment Configuration ===");
    _log("--- Council Token (timestamp-based) ---");
    _log(string.concat("  name:               ", _tokenParams.name));
    _log(string.concat("  symbol:             ", _tokenParams.symbol));
    _log(string.concat("  admin:              ", vm.toString(_tokenParams.admin)));
    _log(string.concat("  maxTokensPerMember: ", _toStr(_tokenParams.maxTokensPerMember)));
    _log(string.concat("  members (count):    ", _toStr(_tokenParams.members.length)));
    for (uint256 _i = 0; _i < _tokenParams.members.length; _i++) {
      _log(string.concat("    member ", _toStr(_i), ": ", vm.toString(_tokenParams.members[_i])));
    }

    _log("--- Timelock (timestamp-based) ---");
    _log(string.concat("  minDelay: ", _toStr(_timelockParams.minDelay)));

    _log("--- Council Governor (timestamp-based) ---");
    _log(string.concat("  name:               ", _councilParams.name));
    _log(string.concat("  votingDelay:        ", _toStr(_councilParams.votingDelay)));
    _log(string.concat("  votingPeriod:       ", _toStr(_councilParams.votingPeriod)));
    _log(string.concat("  proposalThreshold:  ", _toStr(_councilParams.proposalThreshold)));
    _log(string.concat("  quorumFraction:     ", _toStr(_councilParams.quorumFraction)));
    _log(string.concat("  superQuorumFraction:", _toStr(_councilParams.superQuorumFraction)));
    _log(string.concat("  admin:              ", vm.toString(_councilParams.admin)));

    _log("--- Veto Governor ---");
    _log(string.concat("  name:                          ", _vetoParams.name));
    _log(string.concat("  token:                         ", vm.toString(_vetoParams.token)));
    _log(string.concat("  votingDelay:                   ", _toStr(_vetoParams.votingDelay)));
    _log(string.concat("  votingPeriod:                  ", _toStr(_vetoParams.votingPeriod)));
    _log(string.concat("  proposalThreshold:             ", _toStr(_vetoParams.proposalThreshold)));
    _log(string.concat("  vetoGuardian:                  ", vm.toString(_vetoParams.vetoGuardian)));
    _log(
      string.concat("  vetoOverrideRole:              ", vm.toString(_vetoParams.vetoOverrideRole))
    );
    _log(
      string.concat("  vetoOverrideDuration:          ", _toStr(_vetoParams.vetoOverrideDuration))
    );
    _log(
      string.concat("  votingPeriodExtension:         ", _toStr(_vetoParams.votingPeriodExtension))
    );
    _log(
      string.concat(
        "  votingPeriodExtensionThresholdPct: ",
        _toStr(_vetoParams.votingPeriodExtensionThresholdPct)
      )
    );
    _log(
      string.concat("  vetoThresholdNumerator:        ", _toStr(_vetoParams.vetoThresholdNumerator))
    );
    _log(string.concat("  governorAdmin:                 ", vm.toString(_vetoParams.governorAdmin)));
  }

  function _validateDeployment(
    address _deployer,
    CouncilTokenParams memory _tokenParams,
    TimelockParams memory _timelockParams,
    CouncilGovernorParams memory _councilParams,
    VetoGovernorParams memory _vetoParams,
    address _predictedVetoGovernor
  ) internal view virtual {
    if (address(vetoGovernor) != _predictedVetoGovernor) {
      revert(
        string.concat(
          "DeployCouncilGovernance: predicted veto governor at ",
          vm.toString(_predictedVetoGovernor),
          " but deployed at ",
          vm.toString(address(vetoGovernor))
        )
      );
    }

    if (keccak256(bytes(councilToken.name())) != keccak256(bytes(_tokenParams.name))) {
      revert(
        string.concat(
          "DeployCouncilGovernance: council token name mismatch; expected ",
          _tokenParams.name,
          " got ",
          councilToken.name()
        )
      );
    }
    if (keccak256(bytes(councilToken.symbol())) != keccak256(bytes(_tokenParams.symbol))) {
      revert(
        string.concat(
          "DeployCouncilGovernance: council token symbol mismatch; expected ",
          _tokenParams.symbol,
          " got ",
          councilToken.symbol()
        )
      );
    }
    if (councilToken.owner() != _tokenParams.admin) {
      revert(
        string.concat(
          "DeployCouncilGovernance: council token admin mismatch; expected ",
          vm.toString(_tokenParams.admin),
          " got ",
          vm.toString(councilToken.owner())
        )
      );
    }
    if (councilToken.MAX_TOKENS_PER_MEMBER() != _tokenParams.maxTokensPerMember) {
      revert(
        string.concat(
          "DeployCouncilGovernance: council token maxTokensPerMember mismatch; expected ",
          _toStr(_tokenParams.maxTokensPerMember),
          " got ",
          _toStr(councilToken.MAX_TOKENS_PER_MEMBER())
        )
      );
    }

    if (timelock.getMinDelay() != _timelockParams.minDelay) {
      revert(
        string.concat(
          "DeployCouncilGovernance: timelock minDelay mismatch; expected ",
          _toStr(_timelockParams.minDelay),
          " got ",
          _toStr(timelock.getMinDelay())
        )
      );
    }

    if (keccak256(bytes(councilGovernor.name())) != keccak256(bytes(_councilParams.name))) {
      revert(
        string.concat(
          "DeployCouncilGovernance: council governor name mismatch; expected ",
          _councilParams.name,
          " got ",
          councilGovernor.name()
        )
      );
    }
    if (address(councilGovernor.token()) != address(councilToken)) {
      revert(
        string.concat(
          "DeployCouncilGovernance: council governor token mismatch; expected ",
          vm.toString(address(councilToken)),
          " got ",
          vm.toString(address(councilGovernor.token()))
        )
      );
    }
    if (address(councilGovernor.councilVetoGovernor()) != address(vetoGovernor)) {
      revert(
        string.concat(
          "DeployCouncilGovernance: council governor veto governor mismatch; expected ",
          vm.toString(address(vetoGovernor)),
          " got ",
          vm.toString(address(councilGovernor.councilVetoGovernor()))
        )
      );
    }
    if (councilGovernor.votingDelay() != _councilParams.votingDelay) {
      revert(
        string.concat(
          "DeployCouncilGovernance: council governor votingDelay mismatch; expected ",
          _toStr(_councilParams.votingDelay),
          " got ",
          _toStr(councilGovernor.votingDelay())
        )
      );
    }
    if (councilGovernor.votingPeriod() != _councilParams.votingPeriod) {
      revert(
        string.concat(
          "DeployCouncilGovernance: council governor votingPeriod mismatch; expected ",
          _toStr(_councilParams.votingPeriod),
          " got ",
          _toStr(councilGovernor.votingPeriod())
        )
      );
    }
    if (councilGovernor.proposalThreshold() != _councilParams.proposalThreshold) {
      revert(
        string.concat(
          "DeployCouncilGovernance: council governor proposalThreshold mismatch; expected ",
          _toStr(_councilParams.proposalThreshold),
          " got ",
          _toStr(councilGovernor.proposalThreshold())
        )
      );
    }
    if (councilGovernor.owner() != _councilParams.admin) {
      revert(
        string.concat(
          "DeployCouncilGovernance: council governor admin mismatch; expected ",
          vm.toString(_councilParams.admin),
          " got ",
          vm.toString(councilGovernor.owner())
        )
      );
    }

    if (keccak256(bytes(vetoGovernor.name())) != keccak256(bytes(_vetoParams.name))) {
      revert(
        string.concat(
          "DeployCouncilGovernance: veto governor name mismatch; expected ",
          _vetoParams.name,
          " got ",
          vetoGovernor.name()
        )
      );
    }
    if (address(vetoGovernor.token()) != _vetoParams.token) {
      revert(
        string.concat(
          "DeployCouncilGovernance: veto governor token mismatch; expected ",
          vm.toString(_vetoParams.token),
          " got ",
          vm.toString(address(vetoGovernor.token()))
        )
      );
    }
    if (address(vetoGovernor.timelock()) != address(timelock)) {
      revert(
        string.concat(
          "DeployCouncilGovernance: veto governor timelock mismatch; expected ",
          vm.toString(address(timelock)),
          " got ",
          vm.toString(address(vetoGovernor.timelock()))
        )
      );
    }
    if (vetoGovernor.COUNCIL() != address(councilGovernor)) {
      revert(
        string.concat(
          "DeployCouncilGovernance: veto governor council mismatch; expected ",
          vm.toString(address(councilGovernor)),
          " got ",
          vm.toString(vetoGovernor.COUNCIL())
        )
      );
    }
    if (vetoGovernor.votingDelay() != _vetoParams.votingDelay) {
      revert(
        string.concat(
          "DeployCouncilGovernance: veto governor votingDelay mismatch; expected ",
          _toStr(_vetoParams.votingDelay),
          " got ",
          _toStr(vetoGovernor.votingDelay())
        )
      );
    }
    if (vetoGovernor.votingPeriod() != _vetoParams.votingPeriod) {
      revert(
        string.concat(
          "DeployCouncilGovernance: veto governor votingPeriod mismatch; expected ",
          _toStr(_vetoParams.votingPeriod),
          " got ",
          _toStr(vetoGovernor.votingPeriod())
        )
      );
    }
    if (vetoGovernor.proposalThreshold() != _vetoParams.proposalThreshold) {
      revert(
        string.concat(
          "DeployCouncilGovernance: veto governor proposalThreshold mismatch; expected ",
          _toStr(_vetoParams.proposalThreshold),
          " got ",
          _toStr(vetoGovernor.proposalThreshold())
        )
      );
    }
    if (vetoGovernor.vetoGuardian() != _vetoParams.vetoGuardian) {
      revert(
        string.concat(
          "DeployCouncilGovernance: veto governor vetoGuardian mismatch; expected ",
          vm.toString(_vetoParams.vetoGuardian),
          " got ",
          vm.toString(vetoGovernor.vetoGuardian())
        )
      );
    }
    if (vetoGovernor.vetoOverrideRole() != _vetoParams.vetoOverrideRole) {
      revert(
        string.concat(
          "DeployCouncilGovernance: veto governor vetoOverrideRole mismatch; expected ",
          vm.toString(_vetoParams.vetoOverrideRole),
          " got ",
          vm.toString(vetoGovernor.vetoOverrideRole())
        )
      );
    }
    if (vetoGovernor.owner() != _vetoParams.governorAdmin) {
      revert(
        string.concat(
          "DeployCouncilGovernance: veto governor admin mismatch; expected ",
          vm.toString(_vetoParams.governorAdmin),
          " got ",
          vm.toString(vetoGovernor.owner())
        )
      );
    }

    for (uint256 _i = 0; _i < _tokenParams.members.length; _i++) {
      if (councilToken.balanceOf(_tokenParams.members[_i]) != _tokenParams.maxTokensPerMember) {
        revert(
          string.concat(
            "DeployCouncilGovernance: council member ",
            vm.toString(_tokenParams.members[_i]),
            " has incorrect token balance"
          )
        );
      }
      if (councilToken.delegates(_tokenParams.members[_i]) != _tokenParams.members[_i]) {
        revert(
          string.concat(
            "DeployCouncilGovernance: council member ",
            vm.toString(_tokenParams.members[_i]),
            " has incorrect delegation"
          )
        );
      }
    }

    uint256 _expectedSupply = _tokenParams.maxTokensPerMember * _tokenParams.members.length;
    if (councilToken.totalSupply() != _expectedSupply) {
      revert(
        string.concat(
          "DeployCouncilGovernance: council token total supply mismatch; expected ",
          _toStr(_expectedSupply),
          " got ",
          _toStr(councilToken.totalSupply())
        )
      );
    }

    if (!timelock.hasRole(timelock.PROPOSER_ROLE(), address(vetoGovernor))) {
      revert("DeployCouncilGovernance: veto governor does not have PROPOSER_ROLE on timelock");
    }
    if (!timelock.hasRole(timelock.EXECUTOR_ROLE(), address(vetoGovernor))) {
      revert("DeployCouncilGovernance: veto governor does not have EXECUTOR_ROLE on timelock");
    }
    if (!timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock))) {
      revert("DeployCouncilGovernance: timelock does not retain DEFAULT_ADMIN_ROLE");
    }
    if (timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), _deployer)) {
      revert("DeployCouncilGovernance: deployer still has DEFAULT_ADMIN_ROLE");
    }
    if (timelock.hasRole(timelock.CANCELLER_ROLE(), _deployer)) {
      revert("DeployCouncilGovernance: deployer has CANCELLER_ROLE");
    }
    if (timelock.hasRole(timelock.CANCELLER_ROLE(), address(councilGovernor))) {
      revert("DeployCouncilGovernance: council governor has CANCELLER_ROLE");
    }
    if (timelock.hasRole(timelock.CANCELLER_ROLE(), address(vetoGovernor))) {
      revert("DeployCouncilGovernance: veto governor has CANCELLER_ROLE");
    }
  }
}
