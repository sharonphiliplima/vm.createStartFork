// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {StableWanCoin} from "../src/StableWanCoin.sol";
import {SWEngine} from "../src/SWEngine.sol";

contract DeploySW is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (StableWanCoin, SWEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (address weth, address wbtc, uint256 deployerKey, address oracle) = helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];

        vm.startBroadcast(deployerKey); //removed deployerkey
        StableWanCoin sw = new StableWanCoin();
        SWEngine swEngine = new SWEngine(tokenAddresses, oracle, address(sw));
        sw.transferOwnership(address(swEngine));
        vm.stopBroadcast();
        return (sw, swEngine, helperConfig);
    }
}
