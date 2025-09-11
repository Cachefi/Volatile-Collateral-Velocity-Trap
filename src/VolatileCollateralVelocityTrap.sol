// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VolatileCollateralVelocityTrap is ITrap {
    // The address of the volatile collateral token to monitor
    address public constant COLLATERAL_TOKEN_ADDRESS = 0x2000000000000000000000000000000000000000;

    // The address of the Chainlink price feed for the collateral token
    address public constant PRICE_FEED_ADDRESS = 0x3000000000000000000000000000000000000000;

    // The address of the whale/large holder to monitor
    address public constant WHALE_ADDRESS = 0x4000000000000000000000000000000000000000;

    // The address authorized to call the collect function
    address public constant WHITELISTED_OPERATOR = 0x5000000000000000000000000000000000000000;

    // Thresholds for triggering the trap
    uint256 public constant BALANCE_CHANGE_THRESHOLD = 1000 * 1e18; // e.g., 1000 tokens
    int256 public constant PRICE_CHANGE_THRESHOLD = 50 * 1e8; // e.g., $50

    modifier onlyWhitelisted() {
        require(msg.sender == WHITELISTED_OPERATOR, "Not whitelisted");
        _;
    }

    function collect() external view override onlyWhitelisted returns (bytes memory) {
        uint256 collateralBalance = IERC20(COLLATERAL_TOKEN_ADDRESS).balanceOf(WHALE_ADDRESS);
        (, int256 price, , , ) = AggregatorV3Interface(PRICE_FEED_ADDRESS).latestRoundData();
        return abi.encode(collateralBalance, price);
    }

    function shouldRespond(bytes[] calldata data) external pure override returns (bool, bytes memory) {
        if (data.length < 2) {
            return (false, "");
        }

        (uint256 balance0, int256 price0) = abi.decode(data[0], (uint256, int256));
        (uint256 balance1, int256 price1) = abi.decode(data[1], (uint256, int256));

        uint256 balanceDiff = balance1 > balance0 ? balance1 - balance0 : balance0 - balance1;
        int256 priceDiff = price1 > price0 ? price1 - price0 : price0 - price1;

        bool triggered = (balanceDiff > BALANCE_CHANGE_THRESHOLD) && (priceDiff > PRICE_CHANGE_THRESHOLD);

        if (triggered) {
            bytes memory responseData = abi.encode(WHALE_ADDRESS, balance0, balance1, price0, price1);
            return (true, responseData);
        }

        return (false, "");
    }
}