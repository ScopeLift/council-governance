// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// External Dependencies
import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Internal Dependencies
import {CouncilERC20} from "src/CouncilERC20.sol";

contract CouncilERC20_Test is Test {
  CouncilERC20 internal token;

  address internal owner = makeAddr("owner");
  address internal councilMember1 = makeAddr("councilMember1");
  address internal councilMember2 = makeAddr("councilMember2");

  function setUp() public virtual {
    vm.label(owner, "owner");
    vm.label(councilMember1, "councilMember1");
    vm.label(councilMember2, "councilMember2");

    token = new CouncilERC20("Council Token", "CIL", owner, 1);
  }

  function _assumeSafeAddress(address _value) internal pure {
    vm.assume(_value != address(0));
  }

  function _assumeSafeUint(uint256 _value) internal pure {
    vm.assume(_value > 0);
  }

  function _assumeRealisticCouncilTokens(uint256 _value) internal pure returns (uint256) {
    return bound(_value, 1, type(uint128).max);
  }

  function _assumeRealisticBlockNumber(uint256 _value) internal pure {
    vm.assume(_value < 2 ** 48 - 1);
  }

  modifier addNewCouncilMember(address _account) {
    _assumeSafeAddress(_account);
    vm.startPrank(owner);
    token.mint(_account, token.MAX_TOKENS_PER_MEMBER());
    assertEq(token.balanceOf(_account), token.MAX_TOKENS_PER_MEMBER());
    vm.stopPrank();
    _;
  }
}

contract Constructor is CouncilERC20_Test {
  function testFuzz_SetsInitialParameters(
    string memory _name,
    string memory _symbol,
    uint256 _maxTokensPerMember
  ) public {
    _assumeSafeUint(_maxTokensPerMember);
    _assumeSafeAddress(owner);

    CouncilERC20 _token = new CouncilERC20(_name, _symbol, owner, _maxTokensPerMember);

    assertEq(_token.name(), _name);
    assertEq(_token.symbol(), _symbol);
    assertEq(_token.owner(), owner);
    assertEq(_token.MAX_TOKENS_PER_MEMBER(), _maxTokensPerMember);
  }

  function testFuzz_RevertWhen_OwnerIsZeroAddress(
    string memory _name,
    string memory _symbol,
    uint256 _maxTokensPerMember
  ) public {
    _assumeSafeUint(_maxTokensPerMember);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    new CouncilERC20(_name, _symbol, address(0), _maxTokensPerMember);
  }

  function testFuzz_RevertWhen_MaxTokensPerMemberIsZero(
    string memory _name,
    string memory _symbol,
    address _owner
  ) public {
    _assumeSafeAddress(_owner);
    vm.expectRevert(CouncilERC20.CouncilERC20_ZeroValue.selector);
    new CouncilERC20(_name, _symbol, _owner, 0);
  }
}

contract Mint is CouncilERC20_Test {
  function testFuzz_MintsTokens(address _account) public {
    _assumeSafeAddress(_account);
    vm.startPrank(owner);
    token.mint(_account, token.MAX_TOKENS_PER_MEMBER());
    vm.stopPrank();
    assertEq(token.balanceOf(_account), token.MAX_TOKENS_PER_MEMBER());
  }

  function test_RevertWhen_CalledByNonOwner() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, councilMember1)
    );
    vm.prank(councilMember1);
    token.mint(councilMember1, 1);
  }

  function test_RevertWhen_MaxTokensPerMemberExceeded(uint256 _value)
    public
    addNewCouncilMember(councilMember1)
  {
    _value = _assumeRealisticCouncilTokens(_value);
    vm.expectRevert(CouncilERC20.CouncilERC20_MaxTokensPerMemberExceeded.selector);
    vm.prank(owner);
    token.mint(councilMember1, _value);
  }
}

contract Burn is CouncilERC20_Test {
  function testFuzz_BurnsTokens(address _account) public addNewCouncilMember(_account) {
    // Burn the tokens
    vm.startPrank(owner);
    token.burn(_account, token.MAX_TOKENS_PER_MEMBER());
    vm.stopPrank();

    // Ensure the account has no tokens
    assertEq(token.balanceOf(_account), 0);
  }

  function test_RevertWhen_CalledByNonOwner() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, councilMember1)
    );
    vm.prank(councilMember1);
    token.burn(councilMember1, 1);
  }
}

contract Clock is CouncilERC20_Test {
  function testFuzz_ReturnsCurrentBlockNumber(uint256 _blockNumber) public {
    _assumeRealisticBlockNumber(_blockNumber);
    vm.warp(_blockNumber);
    assertEq(token.clock(), _blockNumber);
  }
}

contract Delegate is CouncilERC20_Test {
  function testFuzz_RevertWhen_Delegating(address _delegate) public {
    vm.expectRevert(CouncilERC20.CouncilERC20_OperationNotSupported.selector);
    token.delegate(_delegate);
  }
}

contract DelegateBySig is CouncilERC20_Test {
  function testFuzz_RevertWhen_DelegatingBySig(
    address _delegatee,
    uint256 _nonce,
    uint256 _expiry,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) public {
    vm.expectRevert(CouncilERC20.CouncilERC20_OperationNotSupported.selector);
    token.delegateBySig(_delegatee, _nonce, _expiry, _v, _r, _s);
  }
}

contract Transfer is CouncilERC20_Test {
  function testFuzz_RevertWhen_Transferring(address _to, uint256 _value) public {
    _assumeSafeAddress(_to);
    _assumeSafeUint(_value);
    vm.expectRevert(CouncilERC20.CouncilERC20_OperationNotSupported.selector);
    token.transfer(_to, _value);
  }
}

contract TransferFrom is CouncilERC20_Test {
  function testFuzz_RevertWhen_TransferringFrom(address _from, address _to, uint256 _value) public {
    _assumeSafeAddress(_from);
    _assumeSafeAddress(_to);
    _assumeSafeUint(_value);

    // Ensure from has allowance for the value
    vm.prank(_from);
    token.approve(address(this), _value);

    vm.expectRevert(CouncilERC20.CouncilERC20_OperationNotSupported.selector);
    token.transferFrom(_from, _to, _value);
  }
}
