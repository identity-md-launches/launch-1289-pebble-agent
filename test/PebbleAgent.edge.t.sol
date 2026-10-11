// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {PebbleAgent} from "src/PebbleAgent.sol";

/// @dev Complements the deployment and basic ERC-20 tests with allowance lifecycle and rollback properties.
/// forge-config: default.fuzz.runs = 1000
contract PebbleAgentEdgeTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    PebbleAgent private token;
    address private alice;
    address private bob;
    address private spender;

    function setUp() public {
        token = new PebbleAgent();
        alice = makeAddr("edge alice");
        bob = makeAddr("edge bob");
        spender = makeAddr("edge spender");
    }

    function test_OneSmallestUnitIsTransferredExactly() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(address(this), alice, 1);
        assertTrue(token.transfer(alice, 1));
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_EntireSupplyCanBeSpentOnceWithExactAllowance() public {
        assertTrue(token.approve(spender, SUPPLY));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, SUPPLY));
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(alice), SUPPLY);

        // Replenishing the owner's balance must not replenish an exhausted approval.
        vm.prank(alice);
        assertTrue(token.transfer(address(this), SUPPLY));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), bob, 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_MaximumMinusOneIsFiniteAndDecrements() public {
        assertTrue(token.approve(spender, type(uint256).max - 1));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), spender), type(uint256).max - 2);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
    }

    function test_InfiniteApprovalCanBeReducedAndRevoked() public {
        assertTrue(token.approve(spender, type(uint256).max));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertTrue(token.approve(spender, 2));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), spender), 1);

        assertTrue(token.approve(spender, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), alice, 1);
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(alice), 2);
        assertEq(token.balanceOf(address(this)), SUPPLY - 2);
    }

    function test_SelfTransferStillRequiresSufficientBalance() public {
        assertTrue(token.transfer(alice, 1));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 1, 2));
        vm.prank(alice);
        token.transfer(alice, 2);

        vm.prank(alice);
        assertTrue(token.approve(spender, 2));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 1, 2));
        vm.prank(spender);
        token.transferFrom(alice, alice, 2);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.allowance(alice, spender), 2);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_TransferFromByOwnerRequiresAndConsumesSelfApproval() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 1));
        token.transferFrom(address(this), alice, 1);
        assertTrue(token.approve(address(this), 1));
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), address(this)), 0);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
    }

    function test_ZeroDelegatedTransferEmitsAndPreservesExistingApproval() public {
        assertTrue(token.approve(spender, 7));
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(address(this), alice, 0);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 0));
        assertEq(token.allowance(address(this), spender), 7);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_ZeroApprovalToZeroSpenderIsRejected() public {
        assertTrue(token.approve(spender, 7));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 0);
        assertEq(token.allowance(address(this), address(0)), 0);
        assertEq(token.allowance(address(this), spender), 7);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_AllowancesAreIsolatedByOwnerAndSpender() public {
        assertTrue(token.transfer(alice, 10));
        assertTrue(token.approve(spender, 4));
        assertTrue(token.approve(bob, 6));
        vm.prank(alice);
        assertTrue(token.approve(spender, 8));

        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 3));
        assertEq(token.allowance(alice, spender), 5);
        assertEq(token.allowance(address(this), spender), 4);
        assertEq(token.allowance(address(this), bob), 6);
        assertEq(token.allowance(alice, bob), 0);

        // A direct transfer does not use or reset either spender's authority.
        assertTrue(token.transfer(bob, 1));
        assertEq(token.allowance(address(this), spender), 4);
        assertEq(token.allowance(address(this), bob), 6);
        assertEq(token.balanceOf(alice), 7);
        assertEq(token.balanceOf(bob), 4);
        assertEq(token.balanceOf(address(this)), SUPPLY - 11);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_InsufficientAllowanceIsAtomic(uint256 held, uint256 amount, uint256 allowed) public {
        held = bound(held, 1, SUPPLY);
        amount = bound(amount, 1, held);
        allowed = bound(allowed, 0, amount - 1);
        assertTrue(token.transfer(alice, held));
        vm.prank(alice);
        assertTrue(token.approve(spender, allowed));

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, allowed, amount)
        );
        vm.prank(spender);
        token.transferFrom(alice, bob, amount);
        _assertFailedSpendState(held, allowed);
    }

    function testFuzz_InsufficientBalanceIsAtomic(uint256 held, uint256 amount, bool unlimited, bool selfTransfer)
        public
    {
        held = bound(held, 0, SUPPLY);
        amount = bound(amount, held + 1, type(uint256).max - 1);
        uint256 allowed = unlimited ? type(uint256).max : amount;
        assertTrue(token.transfer(alice, held));
        vm.prank(alice);
        assertTrue(token.approve(spender, allowed));

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, held, amount));
        vm.prank(spender);
        token.transferFrom(alice, selfTransfer ? alice : bob, amount);
        _assertFailedSpendState(held, allowed);

        // A failed spend must not prevent a later valid spend using the same approval.
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, held));
        assertEq(token.allowance(alice, spender), unlimited ? allowed : allowed - held);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), held);
    }

    function testFuzz_ZeroRecipientDoesNotBurnOrConsumeApproval(uint256 allowed, uint256 amount) public {
        amount = bound(amount, 0, allowed < SUPPLY ? allowed : SUPPLY);
        assertTrue(token.transfer(alice, SUPPLY));
        vm.prank(alice);
        assertTrue(token.approve(spender, allowed));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(alice, address(0), amount);
        _assertFailedSpendState(SUPPLY, allowed);
    }

    function testFuzz_ApprovalReplacementAfterPartialSpend(uint256 first, uint256 spent, uint256 replacement) public {
        first = bound(first, 1, SUPPLY);
        spent = bound(spent, 1, first);
        assertTrue(token.approve(spender, first));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, spent));
        assertEq(token.allowance(address(this), spender), first - spent);

        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Approval(address(this), spender, replacement);
        assertTrue(token.approve(spender, replacement));
        assertEq(token.allowance(address(this), spender), replacement);
        assertEq(token.balanceOf(alice), spent);
        assertEq(token.balanceOf(address(this)), SUPPLY - spent);
        assertEq(token.totalSupply(), SUPPLY);
    }

    /// @dev Metamorphic property: splitting a payment cannot change its total effect or allowance cost.
    function testFuzz_SplitAndLumpDelegatedPaymentsAreEquivalent(uint256 total, uint256 first, bool unlimited) public {
        total = bound(total, 0, SUPPLY);
        first = bound(first, 0, total);
        uint256 allowed = unlimited ? type(uint256).max : total;
        PebbleAgent lumpToken = new PebbleAgent();
        assertTrue(token.approve(spender, allowed));
        assertTrue(lumpToken.approve(spender, allowed));

        vm.startPrank(spender);
        assertTrue(token.transferFrom(address(this), alice, first));
        assertTrue(token.transferFrom(address(this), alice, total - first));
        assertTrue(lumpToken.transferFrom(address(this), alice, total));
        vm.stopPrank();

        assertEq(token.balanceOf(alice), total);
        assertEq(token.balanceOf(alice), lumpToken.balanceOf(alice));
        assertEq(token.balanceOf(address(this)), SUPPLY - total);
        assertEq(token.balanceOf(address(this)), lumpToken.balanceOf(address(this)));
        assertEq(token.allowance(address(this), spender), unlimited ? type(uint256).max : 0);
        assertEq(token.allowance(address(this), spender), lumpToken.allowance(address(this), spender));
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(lumpToken.totalSupply(), SUPPLY);
    }

    function _assertFailedSpendState(uint256 held, uint256 allowed) private view {
        assertEq(token.balanceOf(alice), held);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(spender), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - held);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.allowance(alice, spender), allowed);
        assertEq(token.totalSupply(), SUPPLY);
    }
}
