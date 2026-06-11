// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract DeploymentConfigurationBase {
  struct BaseDeploymentConfiguration {
    address mainDaoGovernor;
    address mainDaoToken;
    address governorAdmin;
  }

  function _getBaseDeploymentConfiguration()
    public
    view
    virtual
    returns (BaseDeploymentConfiguration memory);
}
