// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Dependencies
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title CouncilERC20
/// @author [ScopeLift](https://scopelift.co)
/// @notice ERC20 token representing membership in the Council.
/// @dev
/// - Each address can hold up to `MAX_TOKENS_PER_MEMBER` tokens.
/// - Holding tokens designates the holder as a Council member.
/// - Council members can participate in governance via the `CouncilGovernor` contract.
/// - Transfers and delegations between members are disabled.
/// - Only minting and burning by the admin are allowed.
contract CouncilERC20 is ERC20, ERC20Votes, Ownable {
  /*///////////////////////////////////////////////////////////////
                          Errors
  //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when member token balance exceeds the allowed maximum.
  error CouncilERC20_MaxTokensPerMemberExceeded();

  /// @notice Thrown when an operation is not supported.
  error CouncilERC20_OperationNotSupported();

  /// @notice Thrown when a zero value is provided.
  error CouncilERC20_ZeroValue();

  /*///////////////////////////////////////////////////////////////
                          State Variables
  //////////////////////////////////////////////////////////////*/

  /// @notice The maximum number of tokens that a member can hold.
  uint256 public immutable MAX_TOKENS_PER_MEMBER;

  /*///////////////////////////////////////////////////////////////
                          Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Constructor for the CouncilERC20 contract.
  /// @param _name The name of the council token.
  /// @param _symbol The symbol of the council token.
  /// @param _admin The address of the council admin.
  /// @param _maxTokensPerMember The maximum number of tokens that a member can hold.
  constructor(
    string memory _name,
    string memory _symbol,
    address _admin,
    uint256 _maxTokensPerMember
  ) ERC20(_name, _symbol) EIP712(_name, "1") Ownable(_admin) {
    if (_maxTokensPerMember == 0) revert CouncilERC20_ZeroValue();
    MAX_TOKENS_PER_MEMBER = _maxTokensPerMember;
  }

  /*///////////////////////////////////////////////////////////////
                          Public Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Mint a new token to an account.
  /// @param _account The address to mint the token to.
  /// @param _value The value of the token to mint.
  function mint(address _account, uint256 _value) public onlyOwner {
    // Check if the member's token balance exceeds the allowed maximum after mint
    if (balanceOf(_account) + _value > MAX_TOKENS_PER_MEMBER) {
      revert CouncilERC20_MaxTokensPerMemberExceeded();
    }

    // Mint and delegate the tokens to the member
    _mint(_account, _value);
    _delegate(_account, _account);
  }

  /// @notice Burn tokens from an account.
  /// @param _account The address to burn the tokens from.
  /// @param _value The value of the tokens to burn.
  /// @dev Only the owner can burn tokens.
  function burn(address _account, uint256 _value) public onlyOwner {
    _burn(_account, _value);
  }

  /// @notice Returns the current block timestamp as the clock.
  function clock() public view override returns (uint48) {
    return uint48(block.timestamp);
  }

  /// @notice Returns the clock mode used for voting snapshots.
  function CLOCK_MODE() public pure override returns (string memory) {
    return "mode=timestamp";
  }

  /// @notice Delegate not supported.
  function delegate(address) public pure override {
    revert CouncilERC20_OperationNotSupported();
  }

  /// @notice Delegate by signature not supported.
  function delegateBySig(address, uint256, uint256, uint8, bytes32, bytes32) public pure override {
    revert CouncilERC20_OperationNotSupported();
  }

  /*///////////////////////////////////////////////////////////////
                          Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @dev This function is overridden to prevent transfers between addresses
  function _update(address _from, address _to, uint256 _value)
    internal
    override(ERC20, ERC20Votes)
  {
    // Prevent transfers between addresses
    if (_from != address(0) && _to != address(0)) revert CouncilERC20_OperationNotSupported();
    ERC20Votes._update(_from, _to, _value);
  }
}
