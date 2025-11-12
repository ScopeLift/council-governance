// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CouncilERC20 is ERC20, ERC20Votes, Ownable {
  constructor(string memory _name, string memory _symbol, address _admin)
    ERC20(_name, _symbol)
    EIP712(_name, "1")
    Ownable(_admin)
  {}

  function mint(address account, uint256 tokenId) public onlyOwner {
    _mint(account, tokenId);
    _delegate(account, account);
  }

  function burn(address account, uint256 tokenId) public onlyOwner {
    _burn(account, tokenId);
  }

  function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
    if (from != address(0) && to != address(0)) revert("Not allowed");
    ERC20Votes._update(from, to, value);
  }

  function clock() public view override returns (uint48) {
    return uint48(block.timestamp);
  }

  function CLOCK_MODE() public pure override returns (string memory) {
    return "mode=timestamp";
  }

  // TODO: is delegation ok?
}
