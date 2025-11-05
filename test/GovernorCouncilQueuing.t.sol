// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {GovernorCouncilQueuing} from "src/extensions/GovernorCouncilQueuing.sol";

contract GovernorCouncilQueuingTest is Test {
  function setUp() public virtual {
    //  new GovernorCouncilQueuing
  }
}

contract UpdateCouncilVetoGovernor is GovernorCouncilQueuingTest {}

contract State is GovernorCouncilQueuingTest {}

contract Propose is GovernorCouncilQueuingTest {
// should save description
// (should create a proposal)
}

contract _executeOperations is GovernorCouncilQueuingTest {}

contract _queueOperations is GovernorCouncilQueuingTest {}

contract _checkVetoGovernorStateBitmap is GovernorCouncilQueuingTest {}
