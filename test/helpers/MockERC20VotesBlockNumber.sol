// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MockERC20VotesBlockNumber is ERC20Votes {
  constructor()
    ERC20("MockERC20VotesBlockNumber", "MBLK")
    EIP712("MockERC20VotesBlockNumber", "1")
  {}

  function mint(address account, uint256 amount) public {
    _mint(account, amount);
    _delegate(account, account);
  }

  function burn(address account, uint256 amount) public {
    _burn(account, amount);
  }
}
