// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20VotesTimestampMock} from
  "@openzeppelin/contracts/mocks/token/ERC20VotesTimestampMock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MockERC20Votes is ERC20VotesTimestampMock {
  constructor() ERC20("MockERC20Votes", "MCK") EIP712("MockERC20Votes", "1") {}

  function mint(address account, uint256 amount) public {
    _mint(account, amount);
    // auto-delegate to make things easier
    _delegate(account, account);
  }

  function burn(address account, uint256 amount) public {
    _burn(account, amount);
  }
}
