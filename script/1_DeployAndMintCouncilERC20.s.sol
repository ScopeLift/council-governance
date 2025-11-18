// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {CouncilERC20DeployInput} from "script/DeployInput.sol";
import {CouncilERC20} from "src/CouncilERC20.sol";

contract DeployAndMintCouncilERC20 is Script, BaseLogger, CouncilERC20DeployInput {
  function run(address _deployer) public returns (CouncilERC20 councilToken) {
    vm.startBroadcast(_deployer);
    councilToken = new CouncilERC20(NAME, SYMBOL, ADMIN, MAX_TOKENS_PER_MEMBER);
    for (uint256 _i = 0; _i < COUNCIL_MEMBERS_LENGTH(); _i++) {
      councilToken.mint(COUNCIL_MEMBERS[_i], MAX_TOKENS_PER_MEMBER);
    }
    vm.stopBroadcast();

    _log("CouncilERC20", address(councilToken));
  }
}
