// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VolatileCollateralVelocityTrap} from "../src/VolatileCollateralVelocityTrap.sol";
import {TrapResponse} from "../src/TrapResponse.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VolatileCollateralVelocityTrapTest is Test {
    VolatileCollateralVelocityTrap public trap;
    TrapResponse public trapResponse;
    address public guardian = address(this);

    function setUp() public {
        trap = new VolatileCollateralVelocityTrap();
        trapResponse = new TrapResponse(guardian);
    }

    function _setCollateralBalance(uint256 balance) internal {
        vm.mockCall(
            trap.COLLATERAL_TOKEN_ADDRESS(),
            abi.encodeWithSelector(IERC20.balanceOf.selector, trap.WHALE_ADDRESS()),
            abi.encode(balance)
        );
    }

    function _setPrice(int256 price, uint8 decimals) internal {
        vm.mockCall(
            trap.PRICE_FEED_ADDRESS(),
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(0, price, 0, 0, 0)
        );
        vm.mockCall(
            trap.PRICE_FEED_ADDRESS(),
            abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
            abi.encode(decimals)
        );
    }

    function test_Collect() public {
        _setCollateralBalance(1000e18);
        _setPrice(2000e8, 8);

        bytes memory data = trap.collect();

        (uint256 bal, int256 price, uint8 decs, uint256 ts) = abi.decode(data, (uint256, int256, uint8, uint256));

        assertEq(bal, 1000e18);
        assertEq(price, 2000e8);
        assertEq(decs, 8);
        assertTrue(ts > 0);
    }

    function test_ShouldRespond_Trigger_8_Decimals() public {
        // State 0
        _setCollateralBalance(1000e18);
        _setPrice(2000e8, 8);
        bytes memory data0 = trap.collect();

        // State 1
        vm.warp(block.timestamp + 1);
        _setCollateralBalance(3000e18);
        _setPrice(1900e8, 8);
        bytes memory data1 = trap.collect();

        bytes[] memory data = new bytes[](2);
        data[0] = data1;
        data[1] = data0;

        (bool triggered, bytes memory responseData) = trap.shouldRespond(data);
        assertTrue(triggered, "Trap should have triggered");

        (address whale, uint256 b0, uint256 b1, int256 p0, int256 p1, uint256 ts) = abi.decode(responseData, (address, uint256, uint256, int256, int256, uint256));
        assertEq(whale, trap.WHALE_ADDRESS());
        assertEq(b0, 1000e18);
        assertEq(b1, 3000e18);
        assertEq(p0, 2000e8);
        assertEq(p1, 1900e8);
        assertTrue(ts > 0);
    }

    function test_ShouldRespond_Trigger_18_Decimals() public {
        // State 0
        _setCollateralBalance(1000e18);
        _setPrice(2000e18, 18);
        bytes memory data0 = trap.collect();

        // State 1
        vm.warp(block.timestamp + 1);
        _setCollateralBalance(3000e18);
        _setPrice(1900e18, 18);
        bytes memory data1 = trap.collect();

        bytes[] memory data = new bytes[](2);
        data[0] = data1;
        data[1] = data0;

        (bool triggered, bytes memory responseData) = trap.shouldRespond(data);
        assertTrue(triggered, "Trap should have triggered with 18 decimals");

        (address whale, uint256 b0, uint256 b1, int256 p0_norm, int256 p1_norm, uint256 ts) = abi.decode(responseData, (address, uint256, uint256, int256, int256, uint256));
        assertEq(whale, trap.WHALE_ADDRESS());
        assertEq(b0, 1000e18);
        assertEq(b1, 3000e18);
        assertEq(p0_norm, 2000e8, "Price 0 should be normalized to 8 decimals");
        assertEq(p1_norm, 1900e8, "Price 1 should be normalized to 8 decimals");
        assertTrue(ts > 0);
    }

    function test_ShouldRespond_NoTrigger_PriceBelowThreshold() public {
        _setCollateralBalance(1000e18);
        _setPrice(2000e8, 8);
        bytes memory data0 = trap.collect();

        vm.warp(block.timestamp + 1);
        _setCollateralBalance(3000e18);
        _setPrice(1990e8, 8);
        bytes memory data1 = trap.collect();

        bytes[] memory data = new bytes[](2);
        data[0] = data1;
        data[1] = data0;

        (bool triggered, bytes memory reason) = trap.shouldRespond(data);
        assertEq(triggered, false, "Trap should not trigger if price change is too low");
        assertEq(string(reason), "price_below");
    }

    function test_ResponseContract_Guardian() public {
        (bool triggered, bytes memory responseData) = _getTriggerData();
        assertTrue(triggered);

        // Should succeed when called by guardian
        vm.prank(guardian);
        trapResponse.executeResponse(responseData);

        // Should fail when called by another address
        vm.expectRevert("unauthorized");
        vm.prank(address(0x123));
        trapResponse.executeResponse(responseData);
    }

    function _getTriggerData() internal returns (bool, bytes memory) {
        _setCollateralBalance(1000e18);
        _setPrice(2000e8, 8);
        bytes memory data0 = trap.collect();

        vm.warp(block.timestamp + 1);
        _setCollateralBalance(3000e18);
        _setPrice(1900e8, 8);
        bytes memory data1 = trap.collect();

        bytes[] memory data = new bytes[](2);
        data[0] = data1;
        data[1] = data0;

        return trap.shouldRespond(data);
    }
}