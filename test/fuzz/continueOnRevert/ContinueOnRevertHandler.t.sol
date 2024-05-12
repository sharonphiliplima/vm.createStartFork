// Commented out for now until revert on fail == false per function customization is implemented

// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
// import {Test} from "forge-std/Test.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

// import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
// import {SWEngine, AggregatorV3Interface} from "../../../src/SWEngine.sol";
// import {StableWanCoin} from "../../../src/StableWanCoin.sol";
// import {Randomish, EnumerableSet} from "../Randomish.sol";
// import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
// import {console} from "forge-std/console.sol";

// contract ContinueOnRevertHandler is Test {
//     using EnumerableSet for EnumerableSet.AddressSet;
//     using Randomish for EnumerableSet.AddressSet;

//     // Deployed contracts to interact with
//     SWEngine public swEngine;
//     StableWanCoin public sw;
//     MockV3Aggregator public ethUsdPriceFeed;
//     MockV3Aggregator public btcUsdPriceFeed;
//     ERC20Mock public weth;
//     ERC20Mock public wbtc;

//     // Ghost Variables
//     uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

//     constructor(SWEngine _swEngine, StableWanCoin _sw) {
//         swEngine = _swEngine;
//         sw = _sw;

//         address[] memory collateralTokens = swEngine.getCollateralTokens();
//         weth = ERC20Mock(collateralTokens[0]);
//         wbtc = ERC20Mock(collateralTokens[1]);

//         ethUsdPriceFeed = MockV3Aggregator(
//             swEngine.getCollateralTokenPriceFeed(address(weth))
//         );
//         btcUsdPriceFeed = MockV3Aggregator(
//             swEngine.getCollateralTokenPriceFeed(address(wbtc))
//         );
//     }

//     // FUNCTOINS TO INTERACT WITH

//     ///////////////
//     // SWEngine //
//     ///////////////
//     function mintAndDepositCollateral(
//         uint256 collateralSeed,
//         uint256 amountCollateral
//     ) public {
//         amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         collateral.mint(msg.sender, amountCollateral);
//         swEngine.depositCollateral(address(collateral), amountCollateral);
//     }

//     function redeemCollateral(
//         uint256 collateralSeed,
//         uint256 amountCollateral
//     ) public {
//         amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         swEngine.redeemCollateral(address(collateral), amountCollateral);
//     }

//     function burnSw(uint256 amountSw) public {
//         amountSw = bound(amountSw, 0, sw.balanceOf(msg.sender));
//         sw.burn(amountSw);
//     }

//     function mintSw(uint256 amountSw) public {
//         amountSw = bound(amountSw, 0, MAX_DEPOSIT_SIZE);
//         sw.mint(msg.sender, amountSw);
//     }

//     function liquidate(
//         uint256 collateralSeed,
//         address userToBeLiquidated,
//         uint256 debtToCover
//     ) public {
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         swEngine.liquidate(
//             address(collateral),
//             userToBeLiquidated,
//             debtToCover
//         );
//     }

//     /////////////////////////////
//     // StableWanCoin //
//     /////////////////////////////
//     function transferSw(uint256 amountSw, address to) public {
//         amountSw = bound(amountSw, 0, sw.balanceOf(msg.sender));
//         vm.prank(msg.sender);
//         sw.transfer(to, amountSw);
//     }

//     /////////////////////////////
//     // Aggregator //
//     /////////////////////////////
//     function updateCollateralPrice(
//         uint128 newPrice,
//         uint256 collateralSeed
//     ) public {
//         // int256 intNewPrice = int256(uint256(newPrice));
//         int256 intNewPrice = 0;
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         MockV3Aggregator priceFeed = MockV3Aggregator(
//             swEngine.getCollateralTokenPriceFeed(address(collateral))
//         );

//         priceFeed.updateAnswer(intNewPrice);
//     }

//     /// Helper Functions
//     function _getCollateralFromSeed(
//         uint256 collateralSeed
//     ) private view returns (ERC20Mock) {
//         if (collateralSeed % 2 == 0) {
//             return weth;
//         } else {
//             return wbtc;
//         }
//     }

//     function callSummary() external view {
//         console.log("Weth total deposited", weth.balanceOf(address(swEngine)));
//         console.log("Wbtc total deposited", wbtc.balanceOf(address(swEngine)));
//         console.log("Total supply of SW", sw.totalSupply());
//     }
// }
