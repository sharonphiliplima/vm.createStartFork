// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DeploySW} from "../../script/DeploySW.s.sol";
import {SWEngine} from "../../src/SWEngine.sol";
import {StableWanCoin} from "../../src/StableWanCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20DecimalsMock} from "@openzeppelin/contracts/mocks/ERC20DecimalsMock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {MockMoreDebtSW} from "../mocks/MockMoreDebtSW.sol";
import {MockFailedMintSW} from "../mocks/MockFailedMintSW.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract SWEngineTest is StdCheats, Test {
    uint256 testWanFork;

    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount); // if redeemFrom != redeemedTo, then it was liquidated

    SWEngine public swe;
    StableWanCoin public sw;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    address public oracle;
    uint256 public deployerKey;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;
    address public user = address(1);

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;
    string TESTWAN_RPC_URL = vm.envString("TESTWAN_RPC_URL");

    constructor() {
        testWanFork = vm.createSelectFork(TESTWAN_RPC_URL);
    }

    function setUp() external {
        DeploySW deployer = new DeploySW();
        (sw, swe, helperConfig) = deployer.run();
        (weth, wbtc, deployerKey, oracle) = helperConfig.activeNetworkConfig();
        if (block.chainid == 999) {
            vm.deal(user, STARTING_USER_BALANCE);
        }
        // Should we put our integration tests here?
        // else {
        //     user = vm.addr(deployerKey);
        //     ERC20DecimalsMock mockErc = new ERC20DecimalsMock("MOCK", "MOCK", user, 100e18);
        //     MockV3Aggregator aggregatorMock = new MockV3Aggregator(
        //         helperConfig.DECIMALS(),
        //         helperConfig.ETH_USD_PRICE()
        //     );
        //     vm.etch(weth, address(mockErc).code);
        //     vm.etch(wbtc, address(mockErc).code);
        //     vm.etch(ethUsdPriceFeed, address(aggregatorMock).code);
        //     vm.etch(btcUsdPriceFeed, address(aggregatorMock).code);
        // }

        vm.startBroadcast(user);
        ERC20DecimalsMock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20DecimalsMock(wbtc).mint(user, STARTING_USER_BALANCE);
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public tokenAddresses;
    address[] public feedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(ethUsdPriceFeed);
        feedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(SWEngine.SWEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch.selector);
        new SWEngine(tokenAddresses, oracle, address(sw));
    }

    //////////////////
    // Price Tests //
    //////////////////

    function testGetTokenAmountFromUsd() public {
        // If we want $100 of WETH @ $2000/WETH, that would be 0.05 WETH
        uint256 expectedWeth = 0.05 ether;
        uint256 amountWeth = swe.getTokenAmountFromUsd(weth, 100 ether);
        assertEq(amountWeth, expectedWeth);
    }

    function testGetUsdValue() public {
        uint256 ethAmount = 15 ether; //15e18
        // 15e18 ETH * $2000/ETH = $30,000e18
        uint256 expectedUsd = 30000e18;
        uint256 usdValue = swe.getUsdValue(weth, ethAmount);
        assertEq(usdValue, expectedUsd);
        console.log("usdValue:", usdValue); //30000 000000000000000000
    }

    ///////////////////////////////////////
    // depositCollateral Tests //
    ///////////////////////////////////////

    // this test needs it's own setup
    function testRevertsIfTransferFromFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom mockSw = new MockFailedTransferFrom();
        tokenAddresses = [address(mockSw)];
        feedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        SWEngine mockSwe = new SWEngine(tokenAddresses, oracle, address(mockSw));
        mockSw.mint(user, amountCollateral);

        vm.prank(owner);
        mockSw.transferOwnership(address(mockSwe));
        // Arrange - User
        vm.startPrank(user);
        ERC20DecimalsMock(address(mockSw)).approve(address(mockSwe), amountCollateral);
        // Act / Assert
        vm.expectRevert(SWEngine.SWEngine__TransferFailed.selector);
        mockSwe.depositCollateral(address(mockSw), amountCollateral);
        vm.stopPrank();
    }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(swe), amountCollateral);

        vm.expectRevert(SWEngine.SWEngine__NeedsMoreThanZero.selector);
        swe.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20DecimalsMock randToken = new ERC20DecimalsMock("RAN", "RAN", 100);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(SWEngine.SWEngine__TokenNotAllowed.selector, address(randToken)));
        swe.depositCollateral(address(randToken), amountCollateral);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(swe), amountCollateral);
        swe.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = sw.balanceOf(user);
        assertEq(userBalance, 0);
    }

    function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalSwMinted, uint256 collateralValueInUsd) = swe.getAccountInformation(user);
        uint256 expectedDepositedAmount = swe.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalSwMinted, 0);
        assertEq(expectedDepositedAmount, amountCollateral);
    }

    ///////////////////////////////////////
    // depositCollateralAndMintSw Tests //
    ///////////////////////////////////////

    function testRevertsIfMintedSwBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint = (amountCollateral * (uint256(price) * swe.getAdditionalFeedPrecision())) / swe.getPrecision();
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(swe), amountCollateral);

        uint256 expectedHealthFactor = swe.calculateHealthFactor(amountToMint, swe.getUsdValue(weth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(SWEngine.SWEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        swe.depositCollateralAndMintSw(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    modifier depositedCollateralAndMintedSw() {
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(swe), amountCollateral);
        swe.depositCollateralAndMintSw(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedSw {
        uint256 userBalance = sw.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // mintSw Tests //
    ///////////////////////////////////
    // This test needs it's own custom setup
    function testRevertsIfMintFails() public {
        // Arrange - Setup
        MockFailedMintSW mockSw = new MockFailedMintSW();
        tokenAddresses = [weth];
        feedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        SWEngine mockSwe = new SWEngine(tokenAddresses, oracle, address(mockSw));
        mockSw.transferOwnership(address(mockSwe));
        // Arrange - User
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(mockSwe), amountCollateral);

        vm.expectRevert(SWEngine.SWEngine__MintFailed.selector);
        mockSwe.depositCollateralAndMintSw(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(swe), amountCollateral);
        swe.depositCollateralAndMintSw(weth, amountCollateral, amountToMint);
        vm.expectRevert(SWEngine.SWEngine__NeedsMoreThanZero.selector);
        swe.mintSw(0);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountBreaksHealthFactor() public depositedCollateral {
        // 0xe580cc6100000000000000000000000000000000000000000000000006f05b59d3b20000
        // 0xe580cc6100000000000000000000000000000000000000000000003635c9adc5dea00000
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint = (amountCollateral * (uint256(price) * swe.getAdditionalFeedPrecision())) / swe.getPrecision();

        vm.startPrank(user);
        uint256 expectedHealthFactor = swe.calculateHealthFactor(amountToMint, swe.getUsdValue(weth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(SWEngine.SWEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        swe.mintSw(amountToMint);
        vm.stopPrank();
    }

    function testCanMintSw() public depositedCollateral {
        vm.prank(user);
        swe.mintSw(amountToMint);

        uint256 userBalance = sw.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // burnSw Tests //
    ///////////////////////////////////

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(swe), amountCollateral);
        swe.depositCollateralAndMintSw(weth, amountCollateral, amountToMint);
        vm.expectRevert(SWEngine.SWEngine__NeedsMoreThanZero.selector);
        swe.burnSw(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(user);
        vm.expectRevert();
        swe.burnSw(1);
    }

    function testCanBurnSw() public depositedCollateralAndMintedSw {
        vm.startPrank(user);
        sw.approve(address(swe), amountToMint);
        swe.burnSw(amountToMint);
        vm.stopPrank();

        uint256 userBalance = sw.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ///////////////////////////////////
    // redeemCollateral Tests //
    //////////////////////////////////

    // this test needs it's own setup
    function testRevertsIfTransferFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransfer mockSw = new MockFailedTransfer();
        tokenAddresses = [address(mockSw)];
        feedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        SWEngine mockSwe = new SWEngine(tokenAddresses, oracle, address(mockSw));
        mockSw.mint(user, amountCollateral);

        vm.prank(owner);
        mockSw.transferOwnership(address(mockSwe));
        // Arrange - User
        vm.startPrank(user);
        ERC20DecimalsMock(address(mockSw)).approve(address(mockSwe), amountCollateral);
        // Act / Assert
        mockSwe.depositCollateral(address(mockSw), amountCollateral);
        vm.expectRevert(SWEngine.SWEngine__TransferFailed.selector);
        mockSwe.redeemCollateral(address(mockSw), amountCollateral);
        vm.stopPrank();
    }

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(swe), amountCollateral);
        swe.depositCollateralAndMintSw(weth, amountCollateral, amountToMint);
        vm.expectRevert(SWEngine.SWEngine__NeedsMoreThanZero.selector);
        swe.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(user);
        swe.redeemCollateral(weth, amountCollateral);
        uint256 userBalance = ERC20DecimalsMock(weth).balanceOf(user);
        assertEq(userBalance, amountCollateral);
        vm.stopPrank();
    }

    function testEmitCollateralRedeemedWithCorrectArgs() public depositedCollateral {
        vm.expectEmit(true, true, true, true, address(swe));
        emit CollateralRedeemed(user, user, weth, amountCollateral);
        vm.startPrank(user);
        swe.redeemCollateral(weth, amountCollateral);
        vm.stopPrank();
    }
    ///////////////////////////////////
    // redeemCollateralForSw Tests //
    //////////////////////////////////

    function testMustRedeemMoreThanZero() public depositedCollateralAndMintedSw {
        vm.startPrank(user);
        sw.approve(address(swe), amountToMint);
        vm.expectRevert(SWEngine.SWEngine__NeedsMoreThanZero.selector);
        swe.redeemCollateralForSw(weth, 0, amountToMint);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(swe), amountCollateral);
        swe.depositCollateralAndMintSw(weth, amountCollateral, amountToMint);
        sw.approve(address(swe), amountToMint);
        swe.redeemCollateralForSw(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        uint256 userBalance = sw.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ////////////////////////
    // healthFactor Tests //
    ////////////////////////

    function testProperlyReportsHealthFactor() public depositedCollateralAndMintedSw {
        uint256 expectedHealthFactor = 100 ether;
        uint256 healthFactor = swe.getHealthFactor(user);
        // $100 minted with $20,000 collateral at 50% liquidation threshold
        // means that we must have $200 collatareral at all times.
        // 20,000 * 0.5 = 10,000
        // 10,000 / 100 = 100 health factor
        assertEq(healthFactor, expectedHealthFactor);
    }

    function testHealthFactorCanGoBelowOne() public depositedCollateralAndMintedSw {
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        // Rememeber, we need $200 at all times if we have $100 of debt

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        uint256 userHealthFactor = swe.getHealthFactor(user);
        // 180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalSwMinted) = 0.9
        assert(userHealthFactor == 0.9 ether);
    }

    ///////////////////////
    // Liquidation Tests //
    ///////////////////////

    // This test needs it's own setup
    function testMustImproveHealthFactorOnLiquidation() public {
        // Arrange - Setup
        MockMoreDebtSW mockSw = new MockMoreDebtSW(ethUsdPriceFeed);
        tokenAddresses = [weth];
        feedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        SWEngine mockSwe = new SWEngine(tokenAddresses, oracle, address(mockSw));
        mockSw.transferOwnership(address(mockSwe));
        // Arrange - User
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(mockSwe), amountCollateral);
        mockSwe.depositCollateralAndMintSw(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        // Arrange - Liquidator
        collateralToCover = 1 ether;
        ERC20DecimalsMock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20DecimalsMock(weth).approve(address(mockSwe), collateralToCover);
        uint256 debtToCover = 10 ether;
        mockSwe.depositCollateralAndMintSw(weth, collateralToCover, amountToMint);
        mockSw.approve(address(mockSwe), debtToCover);
        // Act
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        // Act/Assert
        vm.expectRevert(SWEngine.SWEngine__HealthFactorNotImproved.selector);
        mockSwe.liquidate(weth, user, debtToCover);
        vm.stopPrank();
    }

    function testCantLiquidateGoodHealthFactor() public depositedCollateralAndMintedSw {
        ERC20DecimalsMock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20DecimalsMock(weth).approve(address(swe), collateralToCover);
        swe.depositCollateralAndMintSw(weth, collateralToCover, amountToMint);
        sw.approve(address(swe), amountToMint);

        vm.expectRevert(SWEngine.SWEngine__HealthFactorOk.selector);
        swe.liquidate(weth, user, amountToMint);
        vm.stopPrank();
    }

    modifier liquidated() {
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(swe), amountCollateral);
        swe.depositCollateralAndMintSw(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = swe.getHealthFactor(user);

        ERC20DecimalsMock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20DecimalsMock(weth).approve(address(swe), collateralToCover);
        swe.depositCollateralAndMintSw(weth, collateralToCover, amountToMint);
        sw.approve(address(swe), amountToMint);
        swe.liquidate(weth, user, amountToMint); // We are covering their whole debt
        vm.stopPrank();
        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20DecimalsMock(weth).balanceOf(liquidator);
        uint256 expectedWeth = swe.getTokenAmountFromUsd(weth, amountToMint)
            + (swe.getTokenAmountFromUsd(weth, amountToMint) / swe.getLiquidationBonus());
        uint256 hardCodedExpected = 6111111111111111110;
        assertEq(liquidatorWethBalance, hardCodedExpected);
        assertEq(liquidatorWethBalance, expectedWeth);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        // Get how much WETH the user lost
        uint256 amountLiquidated = swe.getTokenAmountFromUsd(weth, amountToMint)
            + (swe.getTokenAmountFromUsd(weth, amountToMint) / swe.getLiquidationBonus());

        uint256 usdAmountLiquidated = swe.getUsdValue(weth, amountLiquidated);
        uint256 expectedUserCollateralValueInUsd = swe.getUsdValue(weth, amountCollateral) - (usdAmountLiquidated);

        (, uint256 userCollateralValueInUsd) = swe.getAccountInformation(user);
        uint256 hardCodedExpectedValue = 70000000000000000020;
        assertEq(userCollateralValueInUsd, expectedUserCollateralValueInUsd);
        assertEq(userCollateralValueInUsd, hardCodedExpectedValue);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorSwMinted,) = swe.getAccountInformation(liquidator);
        assertEq(liquidatorSwMinted, amountToMint);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userSwMinted,) = swe.getAccountInformation(user);
        assertEq(userSwMinted, 0);
    }

    ///////////////////////////////////
    // View & Pure Function Tests //
    //////////////////////////////////
    // function testGetCollateralTokenPriceFeed() public {
    //     address priceFeed = swe.getCollateralTokenPriceFeed(weth);
    //     assertEq(priceFeed, ethUsdPriceFeed);
    // }

    function testGetCollateralTokens() public {
        address[] memory collateralTokens = swe.getCollateralTokens();
        assertEq(collateralTokens[0], weth);
    }

    function testGetMinHealthFactor() public {
        uint256 minHealthFactor = swe.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public {
        uint256 liquidationThreshold = swe.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValueFromInformation() public depositedCollateral {
        (, uint256 collateralValue) = swe.getAccountInformation(user);
        uint256 expectedCollateralValue = swe.getUsdValue(weth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public {
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(swe), amountCollateral);
        swe.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        uint256 collateralBalance = swe.getCollateralBalanceOfUser(user, weth);
        assertEq(collateralBalance, amountCollateral);
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(user);
        ERC20DecimalsMock(weth).approve(address(swe), amountCollateral);
        swe.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        uint256 collateralValue = swe.getAccountCollateralValue(user);
        uint256 expectedCollateralValue = swe.getUsdValue(weth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetSw() public {
        address swAddress = swe.getSw();
        assertEq(swAddress, address(sw));
    }

    function testLiquidationPrecision() public {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = swe.getLiquidationPrecision();
        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }

    // How do we adjust our invariant tests for this?
    // function testInvariantBreaks() public depositedCollateralAndMintedSw {
    //     MockV3Aggregator(ethUsdPriceFeed).updateAnswer(0);

    //     uint256 totalSupply = sw.totalSupply();
    //     uint256 wethDeposted = ERC20DecimalsMock(weth).balanceOf(address(swe));
    //     uint256 wbtcDeposited = ERC20DecimalsMock(wbtc).balanceOf(address(swe));

    //     uint256 wethValue = swe.getUsdValue(weth, wethDeposted);
    //     uint256 wbtcValue = swe.getUsdValue(wbtc, wbtcDeposited);

    //     console.log("wethValue: %s", wethValue);
    //     console.log("wbtcValue: %s", wbtcValue);
    //     console.log("totalSupply: %s", totalSupply);

    //     assert(wethValue + wbtcValue >= totalSupply);
    // }
}
