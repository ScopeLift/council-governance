// SPDX-License-Identifier: AGPL-3.0-only
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
