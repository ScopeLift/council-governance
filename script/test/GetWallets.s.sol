// SPDX-License-Identifier: MIT
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
    Vm.Wallet memory _deployer =
      vm.createWallet(uint256(keccak256(abi.encodePacked(wallet))) + walletNonce);
    console.log("Deployer Address:\t\t", _deployer.addr);
    console.log("Deployer Private Key:\t\t", vm.toString(bytes32(_deployer.privateKey)));
    for (uint256 _i = 0; _i < councilMembers; _i++) {
      Vm.Wallet memory _councilMember =
        vm.createWallet(uint256(keccak256(abi.encodePacked(wallet))) + walletNonce + _i + 1);
      console.log("Council Member", _i + 1, "Address:\t", _councilMember.addr);
      console.log(
        "Council Member", _i + 1, "Private Key:\t", vm.toString(bytes32(_councilMember.privateKey))
      );
      councilMemberWallets.push(_councilMember);
    }
    for (uint256 _i = 0; _i < testVoters; _i++) {
      Vm.Wallet memory _testVoter = vm.createWallet(
        uint256(keccak256(abi.encodePacked(wallet))) + walletNonce + councilMembers + _i + 1
      );
      console.log("Test Voter", _i + 1, "Address:\t", _testVoter.addr);
      console.log(
        "Test Voter", _i + 1, "Private Key:\t", vm.toString(bytes32(_testVoter.privateKey))
      );
      testVoterWallets.push(_testVoter);
    }
    console.log("\nCouncil Member Wallets:");
    for (uint256 _i = 0; _i < councilMemberWallets.length; _i++) {
      console.log(councilMemberWallets[_i].addr);
    }
    console.log("\nTest Voter Wallets:");
    for (uint256 _i = 0; _i < testVoterWallets.length; _i++) {
      console.log(testVoterWallets[_i].addr);
    }
  }
}
