// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {DeploymentConfigurationBase} from "script/DeploymentConfigurationBase.s.sol";
import {CouncilERC20} from "src/CouncilERC20.sol";

contract DeployAndMintCouncilERC20 is Script, BaseLogger {
  function run(
    address _deployer,
    DeploymentConfigurationBase.CouncilERC20DeploymentConfiguration memory _config
  ) public returns (CouncilERC20 councilToken) {
    vm.startBroadcast(_deployer);
    councilToken = new CouncilERC20(
      _config.councilTokenName,
      _config.councilTokenSymbol,
      _config.councilTokenAdmin,
      _config.maxTokensPerMember
    );
    for (uint256 _i = 0; _i < _config.councilMembersLength; _i++) {
      councilToken.mint(_config.councilMembers[_i], _config.maxTokensPerMember);
    }
    vm.stopBroadcast();

    _log("CouncilERC20", address(councilToken));
  }
}
