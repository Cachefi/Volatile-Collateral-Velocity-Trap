// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract VolatileCollateralVelocityTrap is ITrap {
    address public constant COLLATERAL_TOKEN_ADDRESS = 0x2000000000000000000000000000000000000000;
    address public constant PRICE_FEED_ADDRESS       = 0x3000000000000000000000000000000000000000;
    address public constant WHALE_ADDRESS            = 0x4000000000000000000000000000000000000000;

    // Absolute thresholds (tune as needed)
    uint256 public constant BALANCE_CHANGE_THRESHOLD = 1000e18;
    int256  public constant PRICE_CHANGE_ABS_1e8     = 50e8; // $50 in 1e8 units

    function collect() external view override returns (bytes memory) {
        uint256 bal = 0;
        int256 price = 0;
        uint8 decs = 8;
        // token balance
        if (COLLATERAL_TOKEN_ADDRESS.code.length > 0) {
            try IERC20(COLLATERAL_TOKEN_ADDRESS).balanceOf(WHALE_ADDRESS) returns (uint256 b) { bal = b; } catch {}
        }
        // price + decimals
        if (PRICE_FEED_ADDRESS.code.length > 0) {
            try AggregatorV3Interface(PRICE_FEED_ADDRESS).latestRoundData()
                returns (uint80, int256 ans, uint256, uint256, uint80) { price = ans; } catch {}
            try AggregatorV3Interface(PRICE_FEED_ADDRESS).decimals()
                returns (uint8 d) { decs = d; } catch {}
        }
        // include timestamp for optional freshness checks
        return abi.encode(bal, price, decs, block.timestamp);
    }

    function shouldRespond(bytes[] calldata data)
        external
        pure
        override
        returns (bool, bytes memory)
    {
        if (data.length < 2) return (false, bytes("insufficient"));

        (uint256 balNow, int256 pxNow, uint8 decNow, uint256 tsNow) = abi.decode(data[0], (uint256,int256,uint8,uint256));
        (uint256 balPrev, int256 pxPrev, uint8  decPrev,          ) = abi.decode(data[1], (uint256,int256,uint8,uint256));

        // balance abs diff
        uint256 balDiff = balNow > balPrev ? balNow - balPrev : balPrev - balNow;
        if (balDiff <= BALANCE_CHANGE_THRESHOLD) return (false, bytes("bal_below"));

        // normalize prices to 1e8 to compare absolute $ change
        int256 normNow  = pxNow;
        int256 normPrev = pxPrev;
        // scale if decimals != 8
        if (decNow > 8)  normNow  /= int256(10 ** (decNow - 8));
        if (decNow < 8)  normNow  *= int256(10 ** (8 - decNow));
        if (decPrev > 8) normPrev /= int256(10 ** (decPrev - 8));
        if (decPrev < 8) normPrev *= int256(10 ** (8 - decPrev));

        int256 pd = normNow >= normPrev ? (normNow - normPrev) : (normPrev - normNow);
        if (pd <= PRICE_CHANGE_ABS_1e8) return (false, bytes("price_below"));

        // pack context for responder
        return (true, abi.encode(WHALE_ADDRESS, balPrev, balNow, normPrev, normNow, tsNow));
    }
}