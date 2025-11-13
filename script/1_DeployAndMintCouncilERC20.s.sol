// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {CouncilERC20DeployInput} from "script/DeployInput.sol";
import {CouncilERC20} from "src/CouncilERC20.sol";

contract DeployCouncilERC20 is Script, BaseLogger, CouncilERC20DeployInput {
  function run() public returns (CouncilERC20 councilToken) {
    vm.startBroadcast();
    councilToken = new CouncilERC20(NAME, SYMBOL, ADMIN, MAX_TOKENS_PER_MEMBER);
    for (uint256 i = 0; i < councilMembers.length; i++) {
      councilToken.mint(councilMembers[i], MAX_TOKENS_PER_MEMBER);
    }
    vm.stopBroadcast();

    _log("CouncilERC20", address(councilToken));
  }
}
