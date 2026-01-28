// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract Counter {
  uint256 public number;

  function setNumber(uint256 newNumber) public {
    number = newNumber;
  }

  function increment() public {
    number++;
  }

  function deposit() public payable {}

  function depositExact(uint256 amount) public payable {
    require(msg.value == amount);
  }
}
