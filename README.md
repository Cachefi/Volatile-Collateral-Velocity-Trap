# Volatile Collateral Velocity Trap

This project implements a Drosera trap to monitor the collateral velocity of a large token holder (a "whale") in a lending protocol. The trap is designed to be deployed on the Ethereum Hoodi network.

## How it Works

The system is composed of two main contracts:

1.  **`VolatileCollateralVelocityTrap.sol`**: This is the main trap contract, deployed via the Drosera CLI. It is stateless and contains hardcoded addresses for the assets and accounts it monitors.
    *   It tracks the balance of a specific ERC20 collateral token held by a whale.
    *   It monitors the price of that collateral token using a Chainlink price feed.
    *   The `collect()` function is called periodically by a Drosera node, which gathers the whale's collateral balance and the token's current price.
    *   The `shouldRespond()` function compares the data from two consecutive `collect()` calls. If both the change in the whale's balance and the change in the token's price exceed predefined thresholds, the trap is triggered.

2.  **`TrapResponse.sol`**: This contract is deployed separately using Foundry. Its purpose is to execute a response when the trap is triggered.
    *   When the `shouldRespond()` function in the main trap returns `true`, the Drosera network calls the `executeResponse()` function in this contract.
    *   In this proof-of-concept, the response contract simply emits an event (`TrapTriggered`) containing details about the triggering event. In a real-world scenario, this contract could contain logic to perform a specific action, such as liquidating a position or sending a notification.

## Testing

The trap's logic can be verified by running the tests included in the project. The tests use mock contracts to simulate the ERC20 token, and the Chainlink price feed.

To run the tests, use the following command:

```bash
forge test
```