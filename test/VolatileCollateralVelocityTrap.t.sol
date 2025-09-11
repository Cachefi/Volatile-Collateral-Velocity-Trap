import {Test} from "forge-std/Test.sol";
import {VolatileCollateralVelocityTrap} from "../src/VolatileCollateralVelocityTrap.sol";
import {TrapResponse} from "../src/TrapResponse.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

// Mock Contracts
contract MockPriceFeed is AggregatorV3Interface {
    int256 public price;

    function decimals() external view returns (uint8) {
        return 8;
    }

    function description() external view returns (string memory) {
        return "Mock Price Feed";
    }

    function version() external view returns (uint256) {
        return 1;
    }

    function getRoundData(uint80) external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, price, 1, 1, 1);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, price, 1, 1, 1);
    }

    function setPrice(int256 _price) external {
        price = _price;
    }
}

contract VolatileCollateralVelocityTrapTest is Test {
    VolatileCollateralVelocityTrap public trap;
    MockPriceFeed public mockPriceFeed;
    TrapResponse public trapResponse;

    address public constant WHITELISTED_OPERATOR = 0x5000000000000000000000000000000000000000;

    function setUp() public {
        // Deploy the trap contract
        trap = new VolatileCollateralVelocityTrap();

        // Deploy mocks
        mockPriceFeed = new MockPriceFeed();

        vm.etch(trap.PRICE_FEED_ADDRESS(), address(mockPriceFeed).code);

        // Deploy the response contract
        trapResponse = new TrapResponse();
    }

    function _setCollateralBalance(uint256 balance) internal {
        vm.mockCall(
            trap.COLLATERAL_TOKEN_ADDRESS(),
            abi.encodeWithSelector(
                IERC20.balanceOf.selector,
                trap.WHALE_ADDRESS()
            ),
            abi.encode(balance)
        );
    }

    function test_Collect() public {
        // Set mock values
        _setCollateralBalance(1000e18);
        MockPriceFeed(trap.PRICE_FEED_ADDRESS()).setPrice(2000e8);

        // Call collect
        vm.prank(WHITELISTED_OPERATOR);
        bytes memory data = trap.collect();

        // Decode and assert
        (uint256 balance, int256 price) = abi.decode(data, (uint256, int256));
        assertEq(balance, 1000e18);
        assertEq(price, 2000e8);
    }

    function test_ShouldRespond_NoTrigger_BalanceChangeBelowThreshold() public {
        // Set initial values
        _setCollateralBalance(1000e18);
        MockPriceFeed(trap.PRICE_FEED_ADDRESS()).setPrice(2000e8);
        vm.prank(WHITELISTED_OPERATOR);
        bytes memory data0 = trap.collect();

        // Change values (balance change below threshold)
        _setCollateralBalance(1001e18);
        MockPriceFeed(trap.PRICE_FEED_ADDRESS()).setPrice(1900e8);
        vm.prank(WHITELISTED_OPERATOR);
        bytes memory data1 = trap.collect();

        // Check shouldRespond
        bytes[] memory data = new bytes[](2);
        data[0] = data0;
        data[1] = data1;
        (bool triggered, ) = trap.shouldRespond(data);
        assertEq(triggered, false);
    }

    function test_ShouldRespond_NoTrigger_PriceChangeBelowThreshold() public {
        // Set initial values
        _setCollateralBalance(1000e18);
        MockPriceFeed(trap.PRICE_FEED_ADDRESS()).setPrice(2000e8);
        vm.prank(WHITELISTED_OPERATOR);
        bytes memory data0 = trap.collect();

        // Change values (price change below threshold)
        _setCollateralBalance(2001e18);
        MockPriceFeed(trap.PRICE_FEED_ADDRESS()).setPrice(1999e8);
        vm.prank(WHITELISTED_OPERATOR);
        bytes memory data1 = trap.collect();

        // Check shouldRespond
        bytes[] memory data = new bytes[](2);
        data[0] = data0;
        data[1] = data1;
        (bool triggered, ) = trap.shouldRespond(data);
        assertEq(triggered, false);
    }

    function test_ShouldRespond_Trigger() public {
        // Set initial values
        _setCollateralBalance(1000e18);
        MockPriceFeed(trap.PRICE_FEED_ADDRESS()).setPrice(2000e8);
        vm.prank(WHITELISTED_OPERATOR);
        bytes memory data0 = trap.collect();

        // Change values (both above threshold)
        _setCollateralBalance(3000e18);
        MockPriceFeed(trap.PRICE_FEED_ADDRESS()).setPrice(1900e8);
        vm.prank(WHITELISTED_OPERATOR);
        bytes memory data1 = trap.collect();

        // Check shouldRespond
        bytes[] memory data = new bytes[](2);
        data[0] = data0;
        data[1] = data1;
        (bool triggered, bytes memory responseData) = trap.shouldRespond(data);
        assertTrue(triggered);

        // Check response data
        (address whale, uint256 balance0, uint256 balance1, int256 price0, int256 price1) = abi.decode(responseData, (address, uint256, uint256, int256, int256));
        assertEq(whale, trap.WHALE_ADDRESS());
        assertEq(balance0, 1000e18);
        assertEq(balance1, 3000e18);
        assertEq(price0, 2000e8);
        assertEq(price1, 1900e8);
    }
}