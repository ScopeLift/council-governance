// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MockERC20VotesNoClock is ERC20, ERC20Permit {
  using Checkpoints for Checkpoints.Trace208;

  error ClockNotAvailable();

  mapping(address account => address) private _delegatee;
  mapping(address delegatee => Checkpoints.Trace208) private _delegateCheckpoints;
  Checkpoints.Trace208 private _totalCheckpoints;

  constructor() ERC20("MockERC20VotesNoClock", "NCLK") ERC20Permit("MockERC20VotesNoClock") {}

  function clock() public pure returns (uint48) {
    revert ClockNotAvailable();
  }

  function CLOCK_MODE() public pure returns (string memory) {
    revert ClockNotAvailable();
  }

  function getVotes(address account) public view virtual returns (uint256) {
    return _delegateCheckpoints[account].latest();
  }

  function getPastVotes(address account, uint256 timepoint) public view virtual returns (uint256) {
    return _delegateCheckpoints[account].upperLookupRecent(SafeCast.toUint48(timepoint));
  }

  function getPastTotalSupply(uint256 timepoint) public view virtual returns (uint256) {
    return _totalCheckpoints.upperLookupRecent(SafeCast.toUint48(timepoint));
  }

  function delegates(address account) public view virtual returns (address) {
    return _delegatee[account];
  }

  function delegate(address delegatee) public virtual {
    _delegate(_msgSender(), delegatee);
  }

  function delegateBySig(
    address delegatee,
    uint256 nonce,
    uint256 expiry,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public virtual {
    require(block.timestamp <= expiry, "signature expired");
    address signer = _recoverSigner(delegatee, nonce, expiry, v, r, s);
    _useCheckedNonce(signer, nonce);
    _delegate(signer, delegatee);
  }

  function mint(address account, uint256 amount) public {
    _mint(account, amount);
    _delegate(account, account);
  }

  function burn(address account, uint256 amount) public {
    _burn(account, amount);
  }

  function _delegate(address account, address delegatee) internal virtual {
    address oldDelegate = delegates(account);
    _delegatee[account] = delegatee;
    _moveDelegateVotes(oldDelegate, delegatee, balanceOf(account));
  }

  function _update(address from, address to, uint256 amount) internal virtual override {
    super._update(from, to, amount);
    if (from == address(0)) {
      _totalCheckpoints.push(
        SafeCast.toUint48(block.number), SafeCast.toUint208(_totalCheckpoints.latest() + amount)
      );
    }
    if (to == address(0)) {
      uint208 prev = _totalCheckpoints.latest();
      _totalCheckpoints.push(SafeCast.toUint48(block.number), SafeCast.toUint208(prev - amount));
    }
    _moveDelegateVotes(delegates(from), delegates(to), amount);
  }

  function _moveDelegateVotes(address from, address to, uint256 amount) internal virtual {
    if (from != to && amount > 0) {
      if (from != address(0)) {
        uint208 old = _delegateCheckpoints[from].latest();
        _delegateCheckpoints[from].push(
          SafeCast.toUint48(block.number), SafeCast.toUint208(old - amount)
        );
      }
      if (to != address(0)) {
        uint208 old = _delegateCheckpoints[to].latest();
        _delegateCheckpoints[to].push(
          SafeCast.toUint48(block.number), SafeCast.toUint208(old + amount)
        );
      }
    }
  }

  function _recoverSigner(
    address delegatee,
    uint256 nonce,
    uint256 expiry,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) internal view returns (address) {
    bytes32 structHash = keccak256(
      abi.encode(
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)"),
        delegatee,
        nonce,
        expiry
      )
    );
    bytes32 digest = _hashTypedDataV4(structHash);
    return ECDSA.recover(digest, v, r, s);
  }
}
