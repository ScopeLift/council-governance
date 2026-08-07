// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Extenral Dependencies
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// Internal Dependencies
import {CompoundCouncilVetoGovernor} from "src/CompoundCouncilVetoGovernor.sol";

contract CompoundCouncilVetoGovernorHarness is CompoundCouncilVetoGovernor {
  constructor(ConstructorParams memory _params) CompoundCouncilVetoGovernor(_params) {}

  function exposed_CheckGovernance() public {
    _checkGovernance();
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
