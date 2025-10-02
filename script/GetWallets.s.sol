// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

contract GetWallets is Script {
  string wallet = "tally governor test";
  uint256 walletNonce = 0;
  uint256 councilMembers = 7;
  uint256 testVoters = 2;
  Vm.Wallet[] councilMemberWallets;
  Vm.Wallet[] testVoterWallets;

  function run() public {
    Vm.Wallet memory deployer =
      vm.createWallet(uint256(keccak256(abi.encodePacked(wallet))) + walletNonce);
    console.log("Deployer Address:\t\t", deployer.addr);
    console.log("Deployer Private Key:\t\t", vm.toString(bytes32(deployer.privateKey)));
    for (uint256 i = 0; i < councilMembers; i++) {
      Vm.Wallet memory councilMember =
        vm.createWallet(uint256(keccak256(abi.encodePacked(wallet))) + walletNonce + i + 1);
      console.log("Council Member", i + 1, "Address:\t", councilMember.addr);
      console.log(
        "Council Member", i + 1, "Private Key:\t", vm.toString(bytes32(councilMember.privateKey))
      );
      councilMemberWallets.push(councilMember);
    }
    for (uint256 i = 0; i < testVoters; i++) {
      Vm.Wallet memory testVoter = vm.createWallet(
        uint256(keccak256(abi.encodePacked(wallet))) + walletNonce + councilMembers + i + 1
      );
      console.log("Test Voter", i + 1, "Address:\t", testVoter.addr);
      console.log("Test Voter", i + 1, "Private Key:\t", vm.toString(bytes32(testVoter.privateKey)));
      testVoterWallets.push(testVoter);
    }
    console.log("\nCouncil Member Wallets:");
    for (uint256 i = 0; i < councilMemberWallets.length; i++) {
      console.log(councilMemberWallets[i].addr);
    }
    console.log("\nTest Voter Wallets:");
    for (uint256 i = 0; i < testVoterWallets.length; i++) {
      console.log(testVoterWallets[i].addr);
    }
  }
}
