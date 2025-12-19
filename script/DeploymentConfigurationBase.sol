// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// External Dependencies
import {IComp} from "src/IComp.sol";

abstract contract DeploymentConfigurationBase {
  struct BaseDeploymentConfiguration {
    address mainDaoGovernor;
    IComp mainDaoToken;
    address governorAdmin;
  }

  function _getBaseDeploymentConfiguration()
    public
    view
    virtual
    returns (BaseDeploymentConfiguration memory);
}
