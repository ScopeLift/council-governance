// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// External Dependencies
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

abstract contract DeploymentConfigurationBase {
  struct BaseDeploymentConfiguration {
    address mainDaoGovernor;
    IERC5805 mainDaoToken;
    address governorAdmin;
  }

  function _getBaseDeploymentConfiguration()
    public
    view
    virtual
    returns (BaseDeploymentConfiguration memory);
}
