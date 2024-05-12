// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;

    // struct NetworkConfig {
    //     address wethUsdPriceFeed;
    //     address wbtcUsdPriceFeed;
    //     address weth;
    //     address wbtc;
    //     uint256 deployerKey;
    // }

    struct NetworkConfig {
        address weth;
        address wbtc;
        uint256 deployerKey;
        address oracle;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 999) {
            activeNetworkConfig = getTestnetWanConfig();
        }
        // else {
        //     activeNetworkConfig = getOrCreateAnvilEthConfig();
        // }
    }

    // function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
    //     sepoliaNetworkConfig = NetworkConfig({
    //         wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
    //         wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
    //         weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81, //contract WETH9
    //         wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
    //         deployerKey: vm.envUint("PRIVATE_KEY")
    //     });
    // }

    function getTestnetWanConfig() public view returns (NetworkConfig memory testnetWanNetworkConfig) {
        testnetWanNetworkConfig = NetworkConfig({
            weth: 0x48344649B9611a891987b2Db33fAada3AC1d05eC, //contract WETH9
            wbtc: 0x07FDb4e8f8E420d021B9abEB2B1f6DcE150Ef77c,
            deployerKey: 0xd7aae673421e6525556984afc3ad26deb3b6386f5c386024bc198fb3d2a4dc63,
            oracle: 0x7Fa955ad6C4B3BB4d11996b6e6AEeB476e25D853
        });
    }

    //Do I insert the oracle address at the helper config or somewhere else?
    //I see to be taking a risk? here with Centralised Oracles - some wrapped oracle in Wanchain!

    //Wanchain mainnet Oracle details -
    //WrappedOracle: 0x73D72a5A5C5d910f414AdEEA6C44580A2C61A5F2
    // wanETH: 0xE3aE74D1518A76715aB4C7BeDF1af73893cd435A
    // wanBTC: 0x50c439B6d602297252505a6799d84eA5928bCFb6

    // the return value was a 1e18 decimals USD value.
    //So, no priceFeeds are needed!
    //What are my steps?
    //1. See how the protocol is implemented ...
    // function getTestnetWanConfig() public view returns (NetworkConfig memory testnetWanNetworkConfig) {
    //     testnetWanNetworkConfig = NetworkConfig({
    //         wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
    //         wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
    //         weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81, //contract WETH9
    //         wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
    //         deployerKey: vm.envUint("PRIVATE_KEY")
    //     });
    // }

    // function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
    //     // Check to see if we set an active network config
    //     // if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
    //     //     return activeNetworkConfig;
    //     // }

    //     vm.startBroadcast();
    //     MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
    //     ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);

    //     MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
    //     ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);
    //     vm.stopBroadcast();

    //     anvilNetworkConfig = NetworkConfig({
    //         weth: address(wethMock),
    //         wbtc: address(wbtcMock),
    //         deployerKey: DEFAULT_ANVIL_PRIVATE_KEY,
    //         oracle: 0x7Fa955ad6C4B3BB4d11996b6e6AEeB476e25D853 //it's never gonna work like that. LOL
    //     });
    // }
}
