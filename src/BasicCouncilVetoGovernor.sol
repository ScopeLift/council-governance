// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorVetoCountingSimple} from "./extensions/GovernorVetoCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {GovernorPreventLateQuorum} from
  "@openzeppelin/contracts/governance/extensions/GovernorPreventLateQuorum.sol";

contract BasicCouncilVetoGovernor is
  Governor,
  GovernorVotes,
  GovernorVetoCountingSimple,
  GovernorPreventLateQuorum
{
  address public immutable COUNCIL;

  modifier onlyCouncil() {
    require(msg.sender == COUNCIL, "Only council");
    _;
  }

  constructor(IERC5805 _token, address _council, uint48 _lateQuorumVoteExtension)
    Governor("BasicVetoGovernor")
    GovernorVotes(_token)
    GovernorPreventLateQuorum(_lateQuorumVoteExtension)
  {
    COUNCIL = _council;
  }

  function votingDelay() public pure override returns (uint256) {
    return 7200; // 1 day
  }

  function votingPeriod() public pure override returns (uint256) {
    return 50_400; // 1 week
  }

  function proposalThreshold() public pure override returns (uint256) {
    return 0;
  }

  function quorum(uint256 /*timepoint*/ ) public pure override returns (uint256) {
    return 0;
  }

  function vetoQuorum(uint256 /*timepoint*/ ) public view virtual override returns (uint256) {
    return 0;
  }

  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) public override onlyCouncil returns (uint256) {
    return super.propose(targets, values, calldatas, description);
  }

  function execute(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) public payable override onlyCouncil returns (uint256) {
    return super.execute(targets, values, calldatas, descriptionHash);
  }

  function cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) public override onlyCouncil returns (uint256) {
    return super._cancel(targets, values, calldatas, descriptionHash);
  }

  function proposalDeadline(uint256 proposalId)
    public
    view
    override(Governor, GovernorPreventLateQuorum)
    returns (uint256)
  {
    return super.proposalDeadline(proposalId);
  }

  function _tallyUpdated(uint256 proposalId) internal override(Governor, GovernorPreventLateQuorum) {
    super._tallyUpdated(proposalId);
  }
}
