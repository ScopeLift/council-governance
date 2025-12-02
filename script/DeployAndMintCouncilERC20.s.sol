// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// Internal Dependencies
import {CouncilERC20} from "src/CouncilERC20.sol";

// Script Dependencies
import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";

contract DeployAndMintCouncilERC20 is Script, BaseLogger {
  struct CouncilERC20DeploymentConfiguration {
    string councilTokenName;
    string councilTokenSymbol;
    address councilTokenAdmin;
    uint256 maxTokensPerMember;
    address[] councilMembers;
    uint256 councilMembersLength;
  }

  function _getCouncilERC20DeploymentConfiguration()
    public
    view
    virtual
    returns (CouncilERC20DeploymentConfiguration memory)
  {}

  function run(address _deployer, CouncilERC20DeploymentConfiguration memory _config)
    public
    returns (CouncilERC20 councilToken)
  {
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
