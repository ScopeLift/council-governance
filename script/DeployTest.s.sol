// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {GovernorVetoGuardian} from "src/extensions/GovernorVetoGuardian.sol";
import {CouncilERC20} from "src/CouncilERC20.sol";
import {MockERC20Votes} from "test/helpers/MockERC20Votes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployOptimisticGovernance is Script, StdAssertions {
  // --- Configuration ---

  // The main DAO Governor that will control council membership and can override vetos.
  // For the test deploy, we will assign deployer address.
  address MAIN_DAO_GOVERNOR;

  // The addresses of the initial council members.
  address[] private councilMembers = [
    0x9848A0c9412caCA9DfdCDC2e543b681462F49de9,
    0x4882C0AD0E4999c1616B9E55292726bBE82c36a0,
    0x14440b5eA01380DD3276a7E1157266fEadf7a6Ab,
    0xb11D758A95f1070aAf6d65E81d86190ac3595E6d,
    0xdDe3FaEC9Dd75753f9411511140cD0a169568037,
    0xb7D72a7bB319E33804A28135b5f271F16Dc55917,
    0xCAb91b447839E9598f4Cf73baEB475D8d9De1aC5
  ];

  // Addresses for DAO token holders to test vetoing.
  address private testVoter1 = 0x80b7FC8f23ad5fDEe6DAC5967F9Eae0F2F4Ae447;
  address private testVoter2 = 0xe49F75aE4bcEBe18e659ba0e2DC9CAF1c267408e;

  // Governance Parameters
  uint256 private constant TIMELOCK_MIN_DELAY = 1 days;
  uint48 private constant VETO_OVERRIDE_DURATION = 4 days;
  uint256 private constant VETO_QUORUM = 10_000e18; // 100k votes

  // --- Deployed Contract Instances ---
  CouncilERC20 public councilToken;
  MockERC20Votes public daoToken;
  TimelockController public timelock;
  BasicCouncilVetoGovernor public vetoGovernor;
  BasicCouncilGovernor public councilGovernor;
  address public vetoGuardian = makeAddr("VetoGuardian");

  /**
   * @notice Main entry point for the deployment script.
   */
  function run() public {
    MAIN_DAO_GOVERNOR = msg.sender;
    vm.startBroadcast();

    console.log("Starting deployment with deployer:", msg.sender);

    _deployTokensAndFundAccounts(msg.sender);
    _deployGovernorsAndTimelock(msg.sender);

    vm.stopBroadcast();

    console.log("\nDeployment Complete!");
    console.log("--------------------------");
    console.log("Council Governor Address:\t\t", address(councilGovernor));
    console.log("Council Membership Token Address:\t", address(councilToken));
    console.log("Veto Governor Address:\t\t", address(vetoGovernor));
    console.log("Veto Governor Timelock Address:\t", address(timelock));
    console.log("DAO Token Address:\t\t\t", address(daoToken));
    console.log("--------------------------");
    console.log("Deployer Address:\t\t\t", msg.sender);
    console.log("\n Council Member Accounts:");
    for (uint256 i = 0; i < councilMembers.length; i++) {
      console.log(councilMembers[i]);
    }
    console.log("\n Test Voter Accounts:");
    console.log(testVoter1);
    console.log(testVoter2);
    console.log("--------------------------");
  }

  /**
   * @notice Deploys the voting tokens and distributes them to council members and test voters.
   */
  function _deployTokensAndFundAccounts(address _deployer) internal {
    console.log("\nDeploying tokens and funding accounts...");

    // Deploy CouncilERC20, with the Main DAO Governor as the owner/admin
    councilToken = new CouncilERC20("Optimistic Council", "OC", MAIN_DAO_GOVERNOR, 1);

    // Mint one "council seat" token to each member
    // In a real scenario, this would be called by the Main DAO Governor
    for (uint256 i = 0; i < councilMembers.length; i++) {
      councilToken.mint(councilMembers[i], 1);

      // let's also transfer a bit of ETH their way...
      payable(councilMembers[i]).transfer(0.0001 ether);
    }

    // Deploy and fund a mock DAO token for veto testing
    daoToken = new MockERC20Votes();
    daoToken.mint(testVoter1, VETO_QUORUM * 2);
    daoToken.mint(testVoter2, VETO_QUORUM * 2);

    // let's also transfer a bit of ETH their way...
    payable(testVoter1).transfer(0.0001 ether);
    payable(testVoter2).transfer(0.0001 ether);
  }

  /**
   * @notice Deploys the Timelock and the two chained Governor contracts.
   * @dev Uses `vm.computeCreateAddress` to resolve the circular dependency where each governor
   *      needs the other's address during construction.
   */
  function _deployGovernorsAndTimelock(address _deployer) internal {
    console.log("Pre-computing governor addresses and deploying Timelock & Governors...");

    // Pre-compute the addresses for the governor contracts
    uint256 nonce = vm.getNonce(_deployer);
    // timelock is nonce + 0
    address predictedVetoGovernorAddress = vm.computeCreateAddress(_deployer, nonce + 1);
    address predictedCouncilGovernorAddress = vm.computeCreateAddress(_deployer, nonce + 2);

    // Configure Timelock roles
    address[] memory proposers = new address[](1);
    proposers[0] = predictedVetoGovernorAddress;
    address[] memory executors = new address[](1);
    executors[0] = predictedVetoGovernorAddress;

    // Deploy Timelock, giving the *future* VetoGovernor the PROPOSER role
    timelock = new TimelockController(TIMELOCK_MIN_DELAY, proposers, executors, address(0));

    BasicCouncilVetoGovernor.ConstructorParams memory vetoGovernorParams = BasicCouncilVetoGovernor
      .ConstructorParams(
      "BasicCouncilVetoGovernor",
      daoToken,
      1 hours, // initialVotingDelay
      1 days, // initialVotingPeriod
      0, // initialProposalThreshold
      vetoGuardian,
      MAIN_DAO_GOVERNOR, // The main DAO governor is the veto overrider
      VETO_OVERRIDE_DURATION,
      timelock,
      MAIN_DAO_GOVERNOR, // The main DAO governor is the governor admin
      predictedCouncilGovernorAddress
    );

    // Deploy the Veto Governor, passing the pre-computed CouncilGovernor address
    vetoGovernor = new BasicCouncilVetoGovernor(vetoGovernorParams);

    // Deploy the Council Governor, passing the now-deployed VetoGovernor address
    councilGovernor = new BasicCouncilGovernor(
      councilToken,
      vetoGovernor,
      MAIN_DAO_GOVERNOR, // The main DAO governor is the governor admin
      1 days,
      1 weeks,
      1
    );

    // Sanity check: ensure predicted addresses match actual addresses
    assertEq(address(vetoGovernor), predictedVetoGovernorAddress);
    assertEq(address(councilGovernor), predictedCouncilGovernorAddress);
  }
}
