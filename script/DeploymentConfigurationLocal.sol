// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Script Dependencies
import {DeploymentConfigurationBase} from "script/DeploymentConfigurationBase.sol";
import {DeploymentInputLocal} from "script/DeploymentInputLocal.sol";
import {DeployAndMintCouncilERC20} from "script/DeployAndMintCouncilERC20.s.sol";
import {DeployTimelock} from "script/DeployTimelock.s.sol";
import {DeployVetoGovernor} from "script/DeployVetoGovernor.s.sol";
import {DeployCouncilGovernor} from "script/DeployCouncilGovernor.s.sol";

contract DeploymentConfigurationLocal is
  DeploymentConfigurationBase,
  DeploymentInputLocal,
  DeployAndMintCouncilERC20,
  DeployTimelock,
  DeployVetoGovernor,
  DeployCouncilGovernor
{
  function _getBaseDeploymentConfiguration()
    public
    pure
    override
    returns (BaseDeploymentConfiguration memory)
  {
    return BaseDeploymentConfiguration({
      mainDaoGovernor: MAIN_DAO_GOVERNOR,
      mainDaoToken: MAIN_DAO_TOKEN,
      governorAdmin: GOVERNOR_ADMIN
    });
  }

  function _getCouncilERC20DeploymentConfiguration()
    public
    view
    override
    returns (CouncilERC20DeploymentConfiguration memory)
  {
    return CouncilERC20DeploymentConfiguration({
      councilTokenName: COUNCIL_TOKEN_NAME,
      councilTokenSymbol: COUNCIL_TOKEN_SYMBOL,
      councilTokenAdmin: COUNCIL_TOKEN_ADMIN,
      maxTokensPerMember: MAX_TOKENS_PER_MEMBER,
      councilMembers: COUNCIL_MEMBERS,
      councilMembersLength: COUNCIL_MEMBERS_LENGTH()
    });
  }

  function _getTimelockDeploymentConfiguration()
    public
    pure
    override
    returns (TimelockDeploymentConfiguration memory)
  {
    return TimelockDeploymentConfiguration({timelockMinDelay: TIMELOCK_MIN_DELAY});
  }

  function _getVetoGovernorDeploymentConfiguration()
    public
    view
    override
    returns (VetoGovernorDeploymentConfiguration memory)
  {
    BaseDeploymentConfiguration memory _baseConfig = _getBaseDeploymentConfiguration();
    return VetoGovernorDeploymentConfiguration({
      vetoGovernorName: VETO_GOVERNOR_NAME,
      mainDaoToken: _baseConfig.mainDaoToken,
      vetoGovernorInitialVotingDelay: VETO_GOVERNOR_INITIAL_VOTING_DELAY,
      vetoGovernorInitialVotingPeriod: VETO_GOVERNOR_INITIAL_VOTING_PERIOD,
      vetoGovernorInitialProposalThreshold: VETO_GOVERNOR_INITIAL_PROPOSAL_THRESHOLD,
      vetoOverrideRole: VETO_OVERRIDE_ROLE,
      vetoOverrideDuration: VETO_OVERRIDE_DURATION,
      vetoGuardian: VETO_GUARDIAN,
      vetoGovernorAdmin: _baseConfig.governorAdmin
    });
  }

  function _getCouncilGovernorDeploymentConfiguration()
    public
    pure
    override
    returns (CouncilGovernorDeploymentConfiguration memory)
  {
    BaseDeploymentConfiguration memory _baseConfig = _getBaseDeploymentConfiguration();
    return CouncilGovernorDeploymentConfiguration({
      councilGovernorName: COUNCIL_GOVERNOR_NAME,
      councilGovernorInitialVotingDelay: COUNCIL_GOVERNOR_INITIAL_VOTING_DELAY,
      councilGovernorInitialVotingPeriod: COUNCIL_GOVERNOR_INITIAL_VOTING_PERIOD,
      councilGovernorInitialProposalThreshold: COUNCIL_GOVERNOR_INITIAL_PROPOSAL_THRESHOLD,
      councilGovernorAdmin: _baseConfig.governorAdmin
    });
  }
}
