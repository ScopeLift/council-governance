// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Dependencies
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

// Internal Dependencies
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";

contract BasicCouncilGovernorHarness is BasicCouncilGovernor {
  constructor(
    IERC5805 _councilToken,
    address _vetoGovernor,
    string memory _name,
    address _admin,
    BasicCouncilGovernor.InitialCouncilParams memory _params
  )
    BasicCouncilGovernor(
      _name, _councilToken, BasicCouncilVetoGovernor(payable(_vetoGovernor)), _admin, _params
    )
  {}

  function exposed_ProposalDescriptions(uint256 proposalId) public view returns (string memory) {
    return proposalDescriptions[proposalId];
  }

  function exposed_CheckGovernance() public {
    _checkGovernance();
  }

  function exposed_Cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) public {
    _cancel(_targets, _values, _calldatas, _descriptionHash);
  }

  function exposed_Executor() public view returns (address) {
    return _executor();
  }

  function exposed_QueueOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) public {
    _queueOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
  }

  function exposed_ExecuteOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) public {
    _executeOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
  }
}
