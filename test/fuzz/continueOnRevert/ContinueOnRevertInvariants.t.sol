// Commented out for now until revert on fail == false per function customization is implemented

// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// // Invariants:
// // protocol must never be insolvent / undercollateralized
// // users cant create stablecoins with a bad health factor
// // a user should only be able to be liquidated if they have a bad health factor

// import {Test} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {SWEngine} from "../../../src/SWEngine.sol";
// import {StableWanCoin} from "../../../src/StableWanCoin.sol";
// import {HelperConfig} from "../../../script/HelperConfig.s.sol";
// import {DeploySW} from "../../../script/DeploySW.s.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
// import {ContinueOnRevertHandler} from "./ContinueOnRevertHandler.t.sol";
// import {console} from "forge-std/console.sol";

// contract ContinueOnRevertInvariants is StdInvariant, Test {
//     SWEngine public swe;
//     StableWanCoin public sw;
//     HelperConfig public helperConfig;

//     address public ethUsdPriceFeed;
//     address public btcUsdPriceFeed;
//     address public weth;
//     address public wbtc;

//     uint256 amountCollateral = 10 ether;
//     uint256 amountToMint = 100 ether;

//     uint256 public constant STARTING_USER_BALANCE = 10 ether;
//     address public constant USER = address(1);
//     uint256 public constant MIN_HEALTH_FACTOR = 1e18;
//     uint256 public constant LIQUIDATION_THRESHOLD = 50;

//     // Liquidation
//     address public liquidator = makeAddr("liquidator");
//     uint256 public collateralToCover = 20 ether;

//     ContinueOnRevertHandler public handler;

//     function setUp() external {
//         DeploySW deployer = new DeploySW();
//         (sw, swe, helperConfig) = deployer.run();
//         (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc) = helperConfig
//             .activeNetworkConfig();
//         handler = new ContinueOnRevertHandler(swe, sw);
//         targetContract(address(handler));
//         // targetContract(address(ethUsdPriceFeed)); Why can't we just do this?
//     }

//     function invariant_protocolMustHaveMoreValueThatTotalSupplyDollars()
//         public
//         view
//     {
//         uint256 totalSupply = sw.totalSupply();
//         uint256 wethDeposted = ERC20Mock(weth).balanceOf(address(swe));
//         uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(swe));

//         uint256 wethValue = swe.getUsdValue(weth, wethDeposted);
//         uint256 wbtcValue = swe.getUsdValue(wbtc, wbtcDeposited);

//         console.log("wethValue: %s", wethValue);
//         console.log("wbtcValue: %s", wbtcValue);

//         assert(wethValue + wbtcValue >= totalSupply);
//     }

//     // function invariant_userCantCreateStabelcoinWithPoorHealthFactor() public {}

//     function invariant_callSummary() public view {
//         handler.callSummary();
//     }
// }
