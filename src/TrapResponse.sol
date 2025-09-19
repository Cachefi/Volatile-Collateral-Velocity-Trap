// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TrapResponse {
    event TrapTriggered(
        address indexed whale,
        uint256 balanceBefore,
        uint256 balanceAfter,
        int256 priceBefore1e8,
        int256 priceAfter1e8,
        uint256 atTs
    );

    address public immutable guardian;
    constructor(address _guardian) {
        guardian = _guardian;
    }

    // drosera.toml: response_function = "executeResponse(bytes)"
    function executeResponse(bytes calldata data) external {
        require(msg.sender == guardian, "unauthorized");
        (address whale, uint256 b0, uint256 b1, int256 p0, int256 p1, uint256 ts) =
            abi.decode(data, (address, uint256, uint256, int256, int256, uint256));
        emit TrapTriggered(whale, b0, b1, p0, p1, ts);
    }
}