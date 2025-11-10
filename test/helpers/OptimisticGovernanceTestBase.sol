// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {CouncilERC20} from "../../src/CouncilERC20.sol";
import {MockERC20Votes} from "./MockERC20Votes.sol";

contract OptimisticGovernanceTestBase is Test {
  uint256 constant COUNCIL_SIZE = 7;
  uint256 constant DAO_SIZE = 20;
  uint256 constant TIMELOCK_MIN_DELAY = 1 days;
  uint256 constant VETO_QUORUM = 10_000e18;

  address internal deployer = makeAddr("deployer");
  address[] internal councilMembers;
  address[] internal daoMembers;

  CouncilERC20 internal councilToken;
  MockERC20Votes internal daoToken;

  address[] internal targets;
  uint256[] internal values;
  bytes[] internal calldatas;

  struct Proposal {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string description;
  }

  function setUp() public virtual {
    daoToken = new MockERC20Votes();
    _createDaoMembers();

    councilToken = new CouncilERC20("CouncilERC20", "CERC", deployer);
    _createCouncilMembers();
  }

  function _createCouncilMembers() internal {
    for (uint256 i = 0; i < COUNCIL_SIZE; i++) {
      address member = makeAddr(string(abi.encodePacked("councilMember", vm.toString(i + 1))));
      councilMembers.push(member);
      vm.prank(deployer);
      councilToken.mint(member, 1);
    }
    skip(1);
  }

  function _selectCouncilMember(uint256 councilMemberIndex) internal view returns (address) {
    return councilMembers[councilMemberIndex % COUNCIL_SIZE];
  }

  function _createDaoMembers() internal {
    for (uint256 i = 0; i < DAO_SIZE; i++) {
      address member = makeAddr(string(abi.encodePacked("daoMember", vm.toString(i + 1))));
      daoMembers.push(member);
      daoToken.mint(member, VETO_QUORUM / 10);
    }
  }

  function _buildEmptyProposal() internal returns (Proposal memory _proposal) {
    _proposal = _buildEmptyProposal("Empty proposal");
  }

  function _buildEmptyProposal(string memory _description)
    internal
    returns (Proposal memory _proposal)
  {
    targets = new address[](1);
    values = new uint256[](1);
    calldatas = new bytes[](1);
    _proposal = Proposal(targets, values, calldatas, _description);
  }
}
