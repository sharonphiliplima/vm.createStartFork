// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.19;

// import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
// import {Test} from "forge-std/Test.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

// import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
// import {SWEngine} from "../../../src/SWEngine.sol";
// import {StableWanCoin} from "../../../src/StableWanCoin.sol";
// import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
// import {console} from "forge-std/console.sol";

// interface IOracle {
//     function getPrice(address token) external view returns (uint256);
// }

// contract StopOnRevertHandler is Test {
//     using EnumerableSet for EnumerableSet.AddressSet;

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

//         // ethUsdPriceFeed = MockV3Aggregator(swEngine.getCollateralTokenPriceFeed(address(weth)));
//         // btcUsdPriceFeed = MockV3Aggregator(swEngine.getCollateralTokenPriceFeed(address(wbtc)));
//     }

//     // FUNCTOINS TO INTERACT WITH

//     ///////////////
//     // SWEngine //
//     ///////////////
//     function mintAndDepositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
//         // must be more than 0
//         amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

//         vm.startPrank(msg.sender);
//         collateral.mint(msg.sender, amountCollateral);
//         collateral.approve(address(swEngine), amountCollateral);
//         swEngine.depositCollateral(address(collateral), amountCollateral);
//         vm.stopPrank();
//     }

//     function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         uint256 maxCollateral = swEngine.getCollateralBalanceOfUser(msg.sender, address(collateral));

//         amountCollateral = bound(amountCollateral, 0, maxCollateral);
//         if (amountCollateral == 0) {
//             return;
//         }
//         swEngine.redeemCollateral(address(collateral), amountCollateral);
//     }

//     function burnSw(uint256 amountSw) public {
//         // Must burn more than 0
//         amountSw = bound(amountSw, 0, sw.balanceOf(msg.sender));
//         if (amountSw == 0) {
//             return;
//         }
//         swEngine.burnSw(amountSw);
//     }

//     // Only the SWEngine can mint SW!
//     // function mintSw(uint256 amountSw) public {
//     //     amountSw = bound(amountSw, 0, MAX_DEPOSIT_SIZE);
//     //     vm.prank(sw.owner());
//     //     sw.mint(msg.sender, amountSw);
//     // }

//     function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
//         uint256 minHealthFactor = swEngine.getMinHealthFactor();
//         uint256 userHealthFactor = swEngine.getHealthFactor(userToBeLiquidated);
//         if (userHealthFactor >= minHealthFactor) {
//             return;
//         }
//         debtToCover = bound(debtToCover, 1, uint256(type(uint96).max));
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         swEngine.liquidate(address(collateral), userToBeLiquidated, debtToCover);
//     }

//     /////////////////////////////
//     // StableWanCoin //
//     /////////////////////////////
//     function transferSw(uint256 amountSw, address to) public {
//         if (to == address(0)) {
//             to = address(1);
//         }
//         amountSw = bound(amountSw, 0, sw.balanceOf(msg.sender));
//         vm.prank(msg.sender);
//         sw.transfer(to, amountSw);
//     }

//     /////////////////////////////
//     // Aggregator //
//     /////////////////////////////
//     //     function updateCollateralPrice(uint96 newPrice, uint256 collateralSeed) public {
//     //         int256 intNewPrice = int256(uint256(newPrice));
//     //         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//     //         MockV3Aggregator priceFeed = MockV3Aggregator(swEngine.getCollateralTokenPriceFeed(address(collateral)));

//     //         priceFeed.updateAnswer(intNewPrice);
//     //     }

//     /// Helper Functions
//     function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
//         if (collateralSeed % 2 == 0) {
//             return weth;
//         } else {
//             return wbtc;
//         }
//     }
// }
