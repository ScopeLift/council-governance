// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

abstract contract DeploymentConfigurationBase {
  struct BaseDeploymentConfiguration {
    address mainDaoGovernor;
    IERC5805 mainDaoToken;
    address governorAdmin;
  }

  struct CouncilERC20DeploymentConfiguration {
    string councilTokenName;
    string councilTokenSymbol;
    address councilTokenAdmin;
    uint256 maxTokensPerMember;
    address[] councilMembers;
    uint256 councilMembersLength;
  }

  struct TimelockDeploymentConfiguration {
    uint256 timelockMinDelay;
  }

  struct VetoGovernorDeploymentConfiguration {
    string vetoGovernorName;
    IERC5805 mainDaoToken;
    uint48 vetoGovernorInitialVotingDelay;
    uint32 vetoGovernorInitialVotingPeriod;
    uint256 vetoGovernorInitialProposalThreshold;
    address vetoOverrideRole;
    uint48 vetoOverrideDuration;
    address vetoGuardian;
    address vetoGovernorAdmin;
  }

  struct CouncilGovernorDeploymentConfiguration {
    string councilGovernorName;
    uint48 councilGovernorInitialVotingDelay;
    uint32 councilGovernorInitialVotingPeriod;
    uint256 councilGovernorInitialProposalThreshold;
    address councilGovernorAdmin;
  }

  function _getBaseDeploymentConfiguration()
    public
    view
    virtual
    returns (BaseDeploymentConfiguration memory);

  function _getCouncilERC20DeploymentConfiguration()
    public
    view
    virtual
    returns (CouncilERC20DeploymentConfiguration memory)
  {}

  function _getTimelockDeploymentConfiguration()
    public
    view
    virtual
    returns (TimelockDeploymentConfiguration memory)
  {}

  function _getVetoGovernorDeploymentConfiguration()
    public
    view
    virtual
    returns (VetoGovernorDeploymentConfiguration memory)
  {}

  function _getCouncilGovernorDeploymentConfiguration()
    public
    view
    virtual
    returns (CouncilGovernorDeploymentConfiguration memory)
  {}
}
