// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ICompVotes
/// @author [ScopeLift](https://scopelift.co)
/// @notice Minimal interface for COMP-style voting power checkpoints.
interface ICompVotes {
  /// @notice Returns the voting power of `account` at `blockNumber`.
  /// @dev Implementations generally require `blockNumber < block.number` (strictly prior).
  /// @param account The address to query voting power for.
  /// @param blockNumber The historical block number to query at.
  /// @return The voting power at `blockNumber`.
  function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}

/// @title GovernorVotesComp
/// @author [ScopeLift](https://scopelift.co)
/// @notice Governor vote-weight extension for COMP-style tokens that expose `getPriorVotes`.
/// @dev COMP uses block number checkpoints and does not implement ERC-5805 snapshot methods.
abstract contract GovernorVotesComp is Governor {
  IERC20 private immutable TOKEN;

  constructor(IERC20 tokenAddress) {
    TOKEN = tokenAddress;
  }

  /// @dev The token that voting power is sourced from.
  function token() public view virtual returns (IERC20) {
    return TOKEN;
  }

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
    override
    returns (uint256)
  {
    return uint256(ICompVotes(address(TOKEN)).getPriorVotes(account, timepoint));
  }
}
