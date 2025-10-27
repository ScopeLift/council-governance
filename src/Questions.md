### Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           COUNCIL GOVERNANCE LAYER                          │
└─────────────────────────────────────────────────────────────────────────────┘

1. COUNCIL MEMBER PROPOSES
   ├─ CouncilERC20: 1 token per member (non-transferable, delegatable)
   ├─ Proposal threshold: 1 vote
   ├─ Voting delay: 1 day
   └─ Voting period: 1 week

2. COUNCIL VOTING
   ├─ Quorum: 4 votes
   ├─ Super quorum: 7 votes (fast-track)
   └─ Council members vote For/Against

3. PROPOSAL OUTCOMES
   ├─ DEFEATED: < 4 votes OR lost vote
   │   └─ ❌ Proposal ends
   │
   ├─ SUCCEEDED: 4+ votes AND won vote
   │   └─ 📤 Queued to Veto Governor
   │
   └─ SUPER QUORUM: 7+ votes
       └─ 🚀 Fast-track to Veto Governor

┌─────────────────────────────────────────────────────────────────────────────┐
│                           VETO GOVERNANCE LAYER                            │
└─────────────────────────────────────────────────────────────────────────────┘

4. VETO GOVERNOR RECEIVES PROPOSAL
   ├─ Only council can propose to veto governor
   ├─ Voting delay: 1 hour
   └─ Voting period: 1 day

5. COMMUNITY VETO VOTING
   ├─ Quorum: 10,000 tokens
   ├─ Community votes AGAINST (veto)
   └─ If veto quorum reached → DEFEATED

6. VETO OUTCOMES
   ├─ VETOED: 10,000+ tokens vote against
   │   ├─ Proposal state: DEFEATED
   │   └─ ⏰ Veto Override Window Opens (vetoOverrideDuration)
   │       └─ Veto Override Role can override within deadline
   │
   └─ NOT VETOED: < 10,000 tokens vote against
       └─ 📤 Queued to Timelock

┌─────────────────────────────────────────────────────────────────────────────┐
│                              TIMELOCK LAYER                                │
└─────────────────────────────────────────────────────────────────────────────┘

7. TIMELOCK EXECUTION
   ├─ Proposal waits for timelock delay
   ├─ Council calls execute() on CouncilGovernor
   ├─ CouncilGovernor calls execute() on VetoGovernor
   └─ VetoGovernor executes via Timelock

8. FINAL EXECUTION
   ├─ Timelock executes the actual operations
   ├─ Proposal state: EXECUTED
   └─ ✅ Changes applied to protocol

┌─────────────────────────────────────────────────────────────────────────────┐
│                            CANCELLATION FLOW                              │
└─────────────────────────────────────────────────────────────────────────────┘

9. PROPOSAL CANCELLATION
   ├─ Proposer cancels on CouncilGovernor
   ├─ CouncilGovernor cancels on VetoGovernor
   └─ VetoGovernor cancels on Timelock (if queued)

┌─────────────────────────────────────────────────────────────────────────────┐
│                            OVERRIDE MECHANISM                             │
└─────────────────────────────────────────────────────────────────────────────┘

10. VETO OVERRIDE (Emergency)
    ├─ Proposal gets vetoed by community
    ├─ Veto Override Role calls overrideVeto()
    ├─ Must be within vetoOverrideDuration after deadline
    └─ Proposal state changes: DEFEATED → SUCCEEDED
        └─ Can now proceed to execution
```

### CouncilERC20

- `constructor`
  - Do we need `EIP712(_name, "1")`
- `_update`
  - ~~Should we do `if (from != address(0) && to != address(0)) revert("Not allowed");` cause this will break `burn`.~~
- `_delegate`
  - We should likely revert `_delegate` right?
- `_mint` 
  - TODO: ensure `amount == 1` and balance of `to == 0`

### BasicCouncilGovernor

- `votingDelay`, `votingPeriod`, `proposalThreshold`, `quorum`, `superQuorum`, would these be passed via constructor eventually or is that an overkill ?
- `proposalVotes` are we intending to implement `GovernorSuperQuorum.proposalVotes` ? If so, is that an option we set at the constructor level ?

### GovernorCouncilQueuing

- Why have `GovernorCouncilQueuing.sol` , why not implement that logic into `BasicCouncilGovernor.sol` ? (unless there is a diff flavour you percieve that can be added later ? if so what kind? )
- Why do we need `mapping(uint256 proposalId => string) private _proposalDescriptions;` ? I know we delete the entry on `_queueOperations` (to avoid double queuing i assume but is it really needed)
- Can the `state` logic be updated to 
```javascript
if (_checkVetoGovernorStateBitmap(proposalId, _encodeStateBitmap(ProposalState.Executed))) {
    return ProposalState.Executed;  // Completed
} else if (_checkVetoGovernorStateBitmap(proposalId, 
    _encodeStateBitmap(ProposalState.Canceled) |
    _encodeStateBitmap(ProposalState.Defeated)
)) {
    return ProposalState.Canceled;  // Canceled / Vetoed
} else {
    return ProposalState.Queued;  // Still processing (Pending/Active/Queued/Succeeded/Defeated)
}
```
- Should we worry about the state when a  proposal hasn't been queued to veto governor but the proposer decides to invoke `_cancel` ? Else calling ` councilVetoGovernor.cancel` would revert
- Why do we allow updating the vetoGovernor contract ? Is it just future proofing ? 

### BasicCouncilVetoGovernor

- `proposalNeedsQueuing` , shouldn't this be false always ? or because it pushes to timelock we have to respect the timelock's delay ?

### GovernorVetoOverride

- Would it not be cleaner to to udpate `overrideVeto` to happens only if 
  - proposal is defeated
  - and the veto call is made before the `vetoOverrideDuration` ends for that proposal 
  - Also: why do we need a `vetoOverrideDuration` ? Feels like an overkill
- `state` can then be updated to something as simple as 
```javascript
  function state(uint256 proposalId) public view virtual override returns (ProposalState) {
    if (isVetoOverridden[proposalId]) {
        return ProposalState.Succeeded;
    }
    return _state;
  }
```

### GovernorVetoCountingSimple
- Reading `_quorumReached` confused me but i know we do this to preserve the logic in `Governor.state` function
Would it make sense to (purely for readbility) 
```javascript
  /// @inheritdoc Governor
  function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
    // Council Proposal is by default in quorum before veto voting begins
    // Once veto voting is done and vetVotes > veto threshold, then the council proposal is defeated
    return !(_proposalFromCouncilIsVetoed(proposalId));
  }

  /// If veto votes >= veto quorum, then proposal has been vetoed
  function _proposalFromCouncilIsVetoed(uint256 proposalId) {
    ProposalVote storage proposalVote = _proposalVotes[proposalId];
    return (proposalVote.vetoVotes >= quorum(proposalSnapshot(proposalId)))
  }
 ```