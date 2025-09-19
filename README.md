# Volatile Collateral Velocity Trap

This project implements a robust, Drosera-based security trap to monitor the collateral velocity of a large token holder (a "whale"). It is designed to be deployed on the Ethereum Hoodi network and incorporates best practices for security and resilience.

## How it Works

The system is composed of two main contracts:

1.  **`VolatileCollateralVelocityTrap.sol`**: This is the main trap contract, deployed via the Drosera CLI. It is stateless and contains hardcoded addresses for the assets and accounts it monitors.

    *   **Robust Data Collection**: The `collect()` function is designed to be highly resilient. It wraps external calls to the token and price feed contracts in `try/catch` blocks. If a data source is unavailable or reverts, the trap gracefully defaults to zero values for that sample instead of crashing, ensuring the monitoring process is never interrupted.
    *   **Dynamic Price Normalization**: The trap monitors the price of the collateral token using a Chainlink price feed. It dynamically fetches the feed's `decimals()` to normalize the price to a standard 8-decimal precision. This ensures the price change threshold is applied correctly, regardless of the underlying asset's price scale.
    *   **Trigger Logic**: The `shouldRespond()` function compares the data from two consecutive `collect()` calls. If both the absolute change in the whale's balance and the normalized change in the token's price exceed predefined thresholds, the trap is triggered.

2.  **`TrapResponse.sol`**: This contract is deployed separately using Foundry and contains the logic to be executed when the trap is triggered.

    *   **Secure Execution**: The `executeResponse()` function is protected by a `guardian` access control mechanism. Only the authorized Drosera network executor (whose address is set during deployment) can call this function, preventing unauthorized triggers.
    *   **Event Emission**: In this proof-of-concept, the response contract emits a `TrapTriggered` event containing detailed context about the event (balances, prices, and timestamp). In a real-world scenario, this contract could execute more complex logic, such as a liquidation or a notification.

## Configuration and Testing

*   **`drosera.toml`**: The project is configured for use with the Drosera network. Operator access is managed off-chain via the `private_trap = true` and `whitelist` settings, which is the recommended approach for the Drosera network.

*   **Testing**: The trap's logic is verified with a comprehensive test suite using Foundry. The tests use `vm.mockCall` to simulate various scenarios, including different price feed decimals and unauthorized calls to the response contract.

To run the tests, use the following command:

```bash
forge test
```
