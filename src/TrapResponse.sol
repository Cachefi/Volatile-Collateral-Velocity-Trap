// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TrapResponse {
    event TrapTriggered(
        address indexed whale,
        uint256 balanceBefore,
        uint256 balanceAfter,
        int256 priceBefore,
        int256 priceAfter
    );

    function executeResponse(bytes calldata data) external {
        (address whale, uint256 balanceBefore, uint256 balanceAfter, int256 priceBefore, int256 priceAfter) = abi.decode(data, (address, uint256, uint256, int256, int256));
        emit TrapTriggered(whale, balanceBefore, balanceAfter, priceBefore, priceAfter);
    }
}
