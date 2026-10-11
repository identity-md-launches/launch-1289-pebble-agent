// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {PebbleAgent} from "../src/PebbleAgent.sol";

/// @dev A closed set of holders lets the invariant account for every smallest unit.
contract PebbleHandler is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    PebbleAgent public immutable token;
    address[4] public actors;
    mapping(address => uint256) public modelBalance;
    mapping(address => mapping(address => uint256)) public modelAllowance;

    constructor() {
        token = new PebbleAgent();
        actors = [makeAddr("holder 0"), makeAddr("holder 1"), makeAddr("holder 2"), makeAddr("holder 3")];
        for (uint256 i; i < actors.length; ++i) {
            assertTrue(token.transfer(actors[i], SUPPLY / actors.length));
            modelBalance[actors[i]] = SUPPLY / actors.length;
        }
    }

    function move(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 amount = bound(amountSeed, 0, modelBalance[from]);
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        modelBalance[from] -= amount;
        modelBalance[to] += amount;
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amountSeed, bool unlimited) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        uint256 amount = unlimited ? type(uint256).max : bound(amountSeed, 0, SUPPLY * 2);
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        modelAllowance[owner][spender] = amount;
    }

    function moveApproved(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed, uint256 amountSeed) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 allowance = modelAllowance[owner][spender];
        uint256 limit = modelBalance[owner] < allowance ? modelBalance[owner] : allowance;
        uint256 amount = bound(amountSeed, 0, limit);
        vm.prank(spender);
        assertTrue(token.transferFrom(owner, to, amount));
        modelBalance[owner] -= amount;
        modelBalance[to] += amount;
        if (allowance != type(uint256).max) modelAllowance[owner][spender] -= amount;
    }

    function attemptUnauthorizedTransfer(uint256 ownerSeed, uint256 toSeed, uint256 amountSeed) external {
        address owner = actors[ownerSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 amount = bound(amountSeed, 1, SUPPLY);
        // The handler is the deployer but is never an approved spender.
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, amount)
        );
        token.transferFrom(owner, to, amount);
    }
}

contract PebbleAgentInvariantTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    PebbleHandler private handler;
    PebbleAgent private token;

    function setUp() public {
        handler = new PebbleHandler();
        token = handler.token();
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = PebbleHandler.move.selector;
        selectors[1] = PebbleHandler.approve.selector;
        selectors[2] = PebbleHandler.moveApproved.selector;
        selectors[3] = PebbleHandler.attemptUnauthorizedTransfer.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_TotalSupplyIsFixedAndAllTokensAreAccountedFor() public view {
        assertEq(token.totalSupply(), SUPPLY);
        uint256 sum;
        for (uint256 i; i < 4; ++i) {
            sum += token.balanceOf(handler.actors(i));
        }
        assertEq(sum, SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(handler)), 0);
        assertEq(token.balanceOf(address(token)), 0);
    }

    function invariant_BalancesAndAllowancesMatchIndependentModel() public view {
        for (uint256 i; i < 4; ++i) {
            address owner = handler.actors(i);
            assertEq(token.balanceOf(owner), handler.modelBalance(owner));
            assertEq(token.allowance(owner, address(handler)), 0);
            for (uint256 j; j < 4; ++j) {
                address spender = handler.actors(j);
                assertEq(token.allowance(owner, spender), handler.modelAllowance(owner, spender));
            }
        }
    }
}
