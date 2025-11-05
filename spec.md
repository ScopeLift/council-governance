## BasicCouncilGovernor
- [ ] Constructor
    - [ ] when valid parameters
        - [ ] sets name correctly
        - [ ] sets CouncilERC20 token correctly
        - [ ] sets veto governor correctly

- [ ] GovernorCouncilQueuing::Propose
    - [ ] when caller is not a council member
        - [ ] reverts with `GovernorInsufficientProposerVotes`
    - [ ] when caller is a council member
        - [ ] when targets/values/calldatas length mismatch
            OR target.length == 0
            - [ ] reverts with `GovernorInvalidProposalLength`
        - [ ] when proposal hash collides with existing proposals
            - [ ] revert with `GovernorUnexpectedProposalState`
        - [ ] when valid proposal parameters
            - [ ] proposal is created
            - [ ] proposal state is set to `Pending`
            - [ ] proposalId is correctly calculated
            - [ ] description is stored at `_proposalDescriptions[proposalId]`
            - [ ] emits event `ProposalCreated`

- [ ] CastVote
    - [ ] when proposal state is `Pending`
        - [ ] reverts with `GovernorUnexpectedProposalState`
    - [ ] when proposal state is `Active`
        - [ ] when voter has already casted vote
            - [ ] reverts with `GovernorAlreadyCastVote`
        - [ ] when voter has not casted vote
            - [ ] when vote type is not `Against`, `For` or `Abstain`
                - [ ] revert with `GovernorInvalidVoteType`
            - [ ] when vote type is `Against`, `For` or `Abstain`
                - [ ] when voter has no vote
                    - [ ] hasVoted[voter] is set to `true`
                    - [ ] proposalVotes remains unchanged
                    - [ ] emit event `VoteCast`
                - [ ] when voter has vote
                    - [ ] hasVoted[voter] is set to `true`
                    - [ ] proposalVotes is updated
                    - [ ] emit event `VoteCast`

 - [ ] GovernorCouncilQueuing::State
    - [ ] when proposal state is not `Queued`, `Executed`, or `Canceled`
        - [ ] when votingDelay has not passed
            - [ ] proposal state is `Pending`
                - [ ] when proposal is canceled successfully
                    - [ ] proposal state is `Canceled`
        - [ ] when votingDelay has passed
            AND votingPeriod has not ended
        - [ ] when votingPeriod has not ended
            - [ ] when super quorum is not reached
                OR for votes <= against votes
                - [ ] proposal state is `Active`
            - [ ] when super quorum is reached
                AND for votes > against votes
                - [ ] proposal state is `Succeeded`
        - [ ] when votingPeriod has ended
            - [ ] when super quorum is not reached
                    OR quorum is not reached
                    OR quorum is reached AND for votes <= against votes
                - [ ] proposal state is `Defeated`
            - [ ] when super quorum is reached
                        OR quorum is reached AND for votes > against votes
                - [ ] proposal state is `Succeeded`
    - [ ] when proposal is queued successfully
        - [ ] when proposal state on veto governor is `Pending`, `Active`, `Succeeded`, `Queued`
            - [ ] proposal state is `Queued`
        - [ ] when proposal state on veto governor is `Executed`
            - [ ] proposal state is `Executed`
        - [ ] when proposal state on veto governor is `Defeated`, `Expired` or `Canceled`
            - [ ] proposal state is `Canceled` (Note: a defeated proposal that is within the override window can potentially flip the state back to `Succeeded`, but `Canceled` is originally understood as a terminal state)

- [ ] GovernorCouncilQueuing::Queue
    - [ ] when proposal state is not `Succeeded`
        - [ ] revert with `GovernorUnexpectedProposalState`
    - [ ] when proposal state is `Succeeded`
        - [ ] proposal is proposed on the veto governor
        - [ ] description is passed and then deleted
        - [ ] deadline is set by the veto governor
        - [ ] emits event `ProposalQueued`

- [ ] GovernorCouncilQueuing::Execute
    - [ ] when proposal state is not `Queued`
        - [ ] revert with `GovernorUnexpectedProposalState`
    - [ ] when proposal state is `Queued`
        - [ ] when proposal state on veto governor is not `Queued`
            - [ ] revert with `TimelockUnexpectedOperationState`
        - [ ] when proposal state on veto governor is `Queued`
            - [ ] calls veto governor's `execute`
            - [ ] calls timelock's `_executeOperations`
            - [ ] when `minDelay` has not passed
                - [ ] revert with `TimelockUnexpectedOperationState`
            - [ ] when `minDelay` has passed
                - [ ] calls timelock
                - [ ] emits event `CallExecuted`
                - [ ] emits event `ProposalExecuted`
    - [ ] when proposal is executed by other parties

- [ ] GovernorCouncilQueuing::Cancel
    - [ ] when proposal state is NOT `Pending`
        OR caller is not proposer
        - [ ] reverts with `GovernorUnableToCancel`
    - [ ] when proposal state is NOT `Pending`
        - [ ] reverts with `GovernorUnexpectedProposalState`
    - [ ] when proposal state is `Pending`
        - [ ] when caller is the proposer
            - [ ] proposal state is now `Canceled`
            - [ ] `cancel` on veto governor is called, but since pending proposal doesn't get queued on the veto governor anyways, this reverts with a `GovernorNonexistentProposal`
- [ ] admin?

## GovernorCouncilQueuing
- [ ] `updateCouncilVetoGovernor`
    - [ ] when called by any address other than the main DAO governor timelock
        - [ ] reverts with `GovernorOnlyExecutor`
    - [ ] when called by the main DAO governor timelock
        - [ ] emits event `CouncilVetoGovernorChange`
        - [ ] veto governor address updated
        - [ ] when unexecuted proposals exist on the old veto governor (out of scope, move to integration tests)
            - [ ] the proposals will no longer be executable unless the address is set back to the old veto governor
- [ ] `_executeOperations`
    - [ ] calls `execute` on **CouncilVetoGovernor** with proposal params
- [ ] `_queueOperations`
    - [ ] calls `propose` on **CouncilVetoGovernor** with proposal params
    - [ ] deletes proposal description from storage
    - [ ] returns proposal deadline on **CouncilVetoGovernor**
- [ ] `propose`
    - [ ] save proposal description to storage
    - [ ] call `super.propose`
- [ ] `state`
    - [ ] when proposal state is not `Queued`
        - [ ] returns proposal state from CouncilGovernor
    - [ ] when proposal state is `Queued`
        - [ ] when **CouncilVetoGovernor** proposal state is `Pending`, `Active`, `Succeeded`, `Queued`
            - [ ] return `Queued`
        - [ ] when **CouncilVetoGovernor** proposal state is `Executed`
            - [ ] return `Executed`
        - [ ] when **CouncilVetoGovernor** proposal state is `Cancelled`, `Defeated`, `Expired`
            - [ ] return `Cancelled`
- [ ] `_checkVetoGovernorStateBitmap`
    - [ ] fetches proposal state from **CouncilVetoGovernor**
    - [ ] returns `true` if proposal state matches one of the allowed proposal states
    - [ ] returns `false` if proposal state doesn't match one of the allowed proposal states


## BasicCouncilVetoGovernor
- [ ] Constructor
    - [ ] when valid parameters
        - [ ] sets name correctly
        - [ ] sets DAO token address correctly
        - [ ] sets vetoOverrideRole address correctly
        - [ ] sets vetoOverrideDuration correctly
        - [ ] sets timelock address correctly
        - [ ] sets council governor address correctly

- [ ] Propose
    - [ ] when called by any address other than the Council Governor
        - [ ] revert with "Only council"
    - [ ] when called by the council governor
       - [ ] when targets/values/calldatas length mismatch
           OR target.length == 0
            - [ ] reverts with `GovernorInvalidProposalLength`
        - [ ] when proposal hash collides with existing proposals
            - [ ] revert with `GovernorUnexpectedProposalState`
        - [ ] when valid proposal parameters
            - [ ] proposal is created
            - [ ] proposal state is set to `Pending`
            - [ ] proposalId is correctly calculated
            - [ ] description is stored at `_proposalDescriptions[proposalId]`
            - [ ] emits event `ProposalCreated`

- [ ] CastVote
    - [ ] when proposal state is not `Active`
        - [ ] reverts with `GovernorUnexpectedProposalState`
    - [ ] when proposal state is `Active`
        - [ ] when voter has already casted vote
            - [ ] reverts with `GovernorAlreadyCastVote`
        - [ ] when voter has not casted vote
            - [ ] when vote type is not `Against`
                - [ ] revert with `GovernorInvalidVoteType`
            - [ ] when vote type is `Against`
                - [ ] when voter has no vote
                    - [ ] hasVoted[voter] is set to `true`
                    - [ ] vetoVotes remains unchanged
                    - [ ] emit event `VoteCast`
                - [ ] when voter has vote
                    - [ ] hasVoted[voter] is set to `true`
                    - [ ] vetoVotes increases by the number of votes
                    - [ ] emit event `VoteCast`

 - [ ] GovernorVetoOverride::State
    - [ ] when votingDelay has not passed
        - [ ] when proposal is canceled
            - [ ] proposal state is `Canceled`
        - [ ] when proposal is not canceled
            - [ ] proposal state is `Pending`
    - [ ] when votingDelay has passed
        AND votingPeriod has not ended
        - [ ] proposal state is `Active`
    - [ ] when votingPeriod has ended
        - [ ] when vetoVotes >= quorum
            - [ ] when vetoVotes is not overridden
                - [ ] proposal state is `Defeated`
            - [ ] when veto is overridden
                - [ ] when time since proposalDeadline < vetoOverrideDuration
                    - [ ] proposal state is `Succeeded` (and the main DAO can queue the proposal within this time frame)
                - [ ] when time since proposalDeadline >= vetoOverrideDuration
                    - [ ] proposal state is `Defeated`
        - [ ] when vetoVotes < quorum
            - [ ] proposal state is `Succeeded`
        - [ ] when proposal is queued successfully
            - [ ] proposal state is `Queued`
        - [ ] when proposal is executed successfully
            - [ ] proposal state is `Executed`

- [ ] Queue
    - [ ] when any address calls queue
        - [ ] when proposal state is not `Succeeded`
            - [ ] revert with `GovernorUnexpectedProposalState`
        - [ ] when proposal state is `Succeeded`
            - [ ] proposal is queued
            - [ ] emits event `ProposalQueued`

- [ ] Execute
    - [ ] when called by any address other than the Council Governor
        - [ ] revert with "Only council"
    - [ ] when called by the council governor
        - [ ] when proposal state is not `Queued`
        - [ ] revert with `GovernorUnexpectedProposalState`
    - [ ] when proposal state is `Queued`
        - [ ] when proposal state on veto governor is not `Queued`
            - [ ] revert with `TimelockUnexpectedOperationState`
        - [ ] when proposal state on veto governor is `Queued`
            - [ ] calls veto governor's `execute`
            - [ ] calls timelock's `_executeOperations`
            - [ ] when `minDelay` has not passed
                - [ ] revert with `TimelockUnexpectedOperationState`
            - [ ] when `minDelay` has passed
                - [ ] calls timelock
                - [ ] emits event `CallExecuted`
                - [ ] emits event `ProposalExecuted`
    - [ ] when proposal is executed by main DAO
    - [ ] when target is on another blockchain

- [ ] Cancel
    - [ ] when called by any address other than the Council Governor
        - [ ] revert with "Only council"
    - [ ] when called by the council governor
        - [ ] reverts with `GovernorNonexistentProposal`
            // when proposal is pending on the council governor, the proposal is non existent on the veto governor. Therefore, the non-existent proposal on the veto governor is not cancelable.
            // when proposal is pending on the veto governor, the proposal is queued on the council governor. To invoke cancel on the veto governor, cancel on the council governor needs to be invoked first, but cancel cannot be invoked on a queued proposal. Therefore, the pending proposal on the veto governor is not cancelable.

## GovernorVetoCountingSimple
- [ ] proposalVotes
    - [ ] when anyone calls
        - [ ] returns the sum of vetoVotes
- [ ] _quorumReached
    - [ ] when vetoVotes >= quorum
        - [ ] return true
    - [ ] when vetoVotes < quorum
        - [ ] return false

## GovernorVetoOverride
- [ ] setVetoOverrideRole
    - [ ] when called by any address other than the main DAO timelock
        - [ ] reverts with `GovernorOnlyExecutor`
    - [ ] when called by the main DAO timelock
        - [ ] sets vetoOverrideRole
        - [ ] emits event `VetoOverrideRoleSet`

- [ ] setVetoOverrideDuration
    - [ ] when called by any address other than the main DAO timelock
        - [ ] reverts with `GovernorOnlyExecutor`
    - [ ] when called by the main DAO timelock
        - [ ] sets vetoOverrideDuration
        - [ ] emits event `VetoOverrideDurationSet`

- [ ] overrideVeto
    - [ ] when called by any address other than the vetoOverrideRole
        - [ ] reverts with `GovernorVetoOverride: caller is not the veto override role`
    - [ ] when called by the vetoOverrideRole
        - [ ] sets isVetoOverriden[proposal] to `true`
        - [ ] allows a defeated proposal to be queued from `proposalDeadline` for `vetoOverrideDuration`
        - [ ] emits event `VetoOverridden`

- [ ] overrideGuardian

## CouncilERC20
- [ ] Mint
    - [ ] when called by non owner
        - [ ] reverts with `OwnableUnauthorizedAccount`
    - [ ] when called by the owner (the main DAO Governor Timelock)
        - [ ] when address `to` is address(0)
            - [ ] reverts with `ERC20InvalidReceiver`
        - [ ] when address `to` is not address(0)
            - [ ] when address `to` balance > 0
                - [ ] reverts with `<SomeCustomError>`
            - [ ] when address `to` balance == 0
            - [ ] when `value` > 1
                - [ ] reverts with `<SomeCustomError>`
            - [ ] when `value` == 1
                - [ ] account balance is set to 1
                - [ ] total supply increases by 1
                - [ ] account vote weight is set to 1 through self delegation
                - [ ] emit event `Transfer`
                - [ ] emit event `DelegateChanged`
                - [ ] emit event `DelegateVotesChanged`
            - [ ] when `value` == 0
                - [ ] account balance remains 0
                - [ ] total supply remains unchanged
                - [ ] account vote weight remains 0
                - [ ] emit event `Transfer`
                - [ ] emit event `DelegateChanged`
                - [ ] emit event `DelegateVotesChanged`

- [ ] Burn
    - [ ] when called by non owner
        - [ ] reverts with `OwnableUnauthorizedAccount`
    - [ ] when caled by the owner (the main DAO Governor Timelock)
        - [ ] when address `from` is address(0)
            - [ ] reverts with `ERC20InvalidReceiver`
        - [ ] when address `from` is not address(0)
            - [ ] when `value` > 1
                - [ ] reverts with `ERC20InsufficientBalance`
            - [ ] when `value` == 1
                - [ ] account balance is set to 0
                - [ ] total supply decreases by 1
                - [ ] account vote weight is set to 0
                - [ ] emit event `Transfer`
                - [ ] emit event `DelegateVotesChanged`
            - [ ] when `value` == 0
                - [ ] account balance remains 1
                - [ ] total supply remains unchanged
                - [ ] account vote weight remains 1
                - [ ] emit event `Transfer`
                - [ ] emit event `DelegateVotesChanged`

- [ ] Transfer
    - [ ] when called by any address
        - [ ] revert with `<SomeCustomError>`

- [ ] TransferFrom
    - [ ] when called by any address
        - [ ] revert with `<SomeCustomError>`

- [ ] Delegate
    - [ ] when called by any address
        - [ ] revert with `<SomeCustomError>`

- [ ] DelegateBySig
    - [ ] when called by any address
        - [ ] revert with `<SomeCustomError>`
