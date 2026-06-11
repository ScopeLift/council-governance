// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External Dependencies
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {
  GovernorTimelockControl,
  TimelockController
} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal Dependencies
import {
  GovernorVotesVetoThresholdFraction
} from "src/extensions/GovernorVotesVetoThresholdFraction.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";

/// @title ICompVotes
/// @author [ScopeLift](https://scopelift.co)
/// @notice Minimal interface for COMP-style voting power checkpoints.
interface ICompVotes {
  /// @notice Returns the voting power of `account` at `blockNumber`.
  /// @param account The address to query voting power for.
  /// @param blockNumber The historical block number to query at.
  /// @return The voting power at `blockNumber`.
  function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);

  /// @notice Returns the current total token supply.
  /// @dev Used to compute veto threshold because COMP does not expose `getPastTotalSupply`.
  function totalSupply() external view returns (uint256);
}

/// @title CompoundCouncilVetoGovernor
/// @author [ScopeLift](https://scopelift.co)
/// @notice Veto governor variant for COMP-style tokens.
/// @dev This governor uses a block-number clock. `votingDelay`, `votingPeriod`, and all timepoints
/// are expressed in blocks.
contract CompoundCouncilVetoGovernor is BasicCouncilVetoGovernor {
  constructor(BasicCouncilVetoGovernor.ConstructorParams memory _params)
    BasicCouncilVetoGovernor(_params)
  {}

  /// @dev Matches COMP to use block number.
  function clock() public view virtual override returns (uint48) {
    return uint48(block.number);
  }

  /// @dev Machine-readable description of the clock as specified in ERC-6372.
  function CLOCK_MODE() public pure virtual override returns (string memory) {
    return "mode=blocknumber&from=default";
  }

  /// @notice Returns the voting weight of `account` at `timepoint`.
  /// @param account The address to query voting power for.
  /// @param timepoint The historical block number to query at.
  function _getVotes(
    address account,
    uint256 timepoint,
    bytes memory /*params*/
  )
    internal
    view
    virtual
    override(Governor, GovernorVotes)
    returns (uint256)
  {
    return uint256(ICompVotes(address(token())).getPriorVotes(account, timepoint));
  }

  /// @notice Returns the veto threshold at a given `timepoint` as a fraction of total supply.
  /// @dev Uses the token's current `totalSupply()`, because COMP does not expose
  /// `getPastTotalSupply`. `vetoThresholdNumerator(timepoint)` is still checkpointed by the
  /// governor's `clock()`.
  function vetoThreshold(uint256 timepoint) public view virtual override returns (uint256) {
    return Math.mulDiv(
      uint256(ICompVotes(address(token())).totalSupply()),
      vetoThresholdNumerator(timepoint),
      vetoThresholdDenominator()
    );
  }
}
