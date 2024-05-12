// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StableWanCoin} from "./StableWanCoin.sol";

/*
 * @title SWEngine
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * @notice  This contract is the rockstar behind the StableWanCoin system, 
 * making DAI look like it's still in its training wheels. 
 * We ditched the governance, threw out the fees, 
 * and decided to back our stablecoin with the crypto equivalent of Batman and Superman – wanETH and wanBTC, 
 * because why settle for anything less than superhero collateral?
 * 
 * Think of this contract as the DJ at the DeFi party, 
 * seamlessly mixing and balancing the beats of minting, redeeming, and collateral juggling. 
 * No dance-off with governance proposals here, just algorithmic stability that's tighter than a cat wearing skinny jeans.
 * 
 * It's like MakerDAO's cool cousin, sipping on digital cocktails and ensuring a 1 token = $1 peg, 
 * because in our world, stability is not just a feature; it's our middle name (if contracts had middle names).
 * 
 * Cheers to being exogenously collateralized, dollar-pegged, and algorithmically stable – the triad of tranquility in the ever-volatile world of DeFi!
 * 
 */
interface IOracle {
    function getPrice(address token) external view returns (uint256);
}

contract SWEngine is ReentrancyGuard {
    ///////////////////
    // Errors
    ///////////////////
    error SWEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error SWEngine__NeedsMoreThanZero();
    error SWEngine__TokenNotAllowed(address token);
    error SWEngine__TransferFailed();
    error SWEngine__BreaksHealthFactor(uint256 healthFactorValue);
    error SWEngine__MintFailed();
    error SWEngine__HealthFactorOk();
    error SWEngine__HealthFactorNotImproved();

    ///////////////////
    // Types
    ///////////////////
    //using OracleLib for AggregatorV3Interface;

    ///////////////////
    // State Variables
    ///////////////////
    StableWanCoin private immutable i_sw;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;

    /// @dev Mapping of token address to price feed address
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    /// @dev Amount of collateral deposited by user
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited; // q is this 1e18?
    /// @dev Amount of SW minted by user
    mapping(address user => uint256 amount) private s_SWMinted;
    /// @dev If we know exactly how many tokens we have, we could make this immutable!
    address[] private s_collateralTokens;
    address public s_oracle;

    ///////////////////
    // Events
    ///////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount); // if redeemFrom != redeemedTo, then it was liquidated

    ///////////////////
    // Modifiers
    ///////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert SWEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (IOracle(s_oracle).getPrice(token) == 0) {
            revert SWEngine__TokenNotAllowed(token);
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////
    // constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address swAddress) {
    //     if (tokenAddresses.length != priceFeedAddresses.length) {
    //         revert SWEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    //     }
    //     // These feeds will be the USD pairs
    //     // For example ETH / USD or MKR / USD
    //     for (uint256 i = 0; i < tokenAddresses.length; i++) {
    //         s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
    //         s_collateralTokens.push(tokenAddresses[i]);
    //     }
    //     i_sw = StableWanCoin(swAddress);
    // }

    constructor(address[] memory tokenAddresses, address oracle, address swAddress) {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_sw = StableWanCoin(swAddress);
        s_oracle = oracle;
    }

    ///////////////////
    // External Functions
    ///////////////////
    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountSwToMint: The amount of SW you want to mint
     * @notice This function will deposit your collateral and mint SW in one transaction
     */
    function depositCollateralAndMintSw(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountSwToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintSw(amountSwToMint);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountSwToBurn: The amount of SW you want to burn
     * @notice This function will withdraw your collateral and burn SW in one transaction
     */
    function redeemCollateralForSw(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountSwToBurn)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
    {
        _burnSw(amountSwToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming
     * @param amountCollateral: The amount of collateral you're redeeming
     * @notice This function will redeem your collateral.
     * @notice If you have SW minted, you will not be able to redeem until you burn your SW
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @notice careful! You'll burn your SW here! Make sure you want to do this...
     * @dev you might want to use this if you're nervous you might get liquidated and want to just burn
     * you SW but keep your collateral in.
     */
    function burnSw(uint256 amount) external moreThanZero(amount) {
        _burnSw(amount, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender); // I don't think this would ever hit...
    }

    /*
     * @param collateral: The ERC20 token address of the collateral you're using to make the protocol solvent again.
     * This is collateral that you're going to take from the user who is insolvent.
     * In return, you have to burn your SW to pay off their debt, but you don't pay off your own.
     * @param user: The user who is insolvent. They have to have a _healthFactor below MIN_HEALTH_FACTOR
     * @param debtToCover: The amount of SW you want to burn to cover the user's debt.
     *
     * @notice: You can partially liquidate a user.
     * @notice: You will get a 10% LIQUIDATION_BONUS for taking the users funds.
     * @notice: This function working assumes that the protocol will be roughly 150% overcollateralized in order for this to work.
     * @notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate anyone.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert SWEngine__HealthFactorOk();
        }
        // If covering 100 SW, we need to $100 of collateral
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // And give them a 10% bonus
        // So we are giving the liquidator $110 of WETH for 100 SW
        // We should implement a feature to liquidate in the event the protocol is insolvent
        // And sweep extra amounts into a treasury
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        // Burn SW equal to debtToCover
        // Figure out how much collateral to recover based on how much burnt

        _redeemCollateral(collateral, tokenAmountFromDebtCovered + bonusCollateral, user, msg.sender);
        _burnSw(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        // This conditional should never hit, but just in case
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert SWEngine__HealthFactorNotImproved();
        }
        revertIfHealthFactorIsBroken(msg.sender);
    }

    ///////////////////
    // Public Functions
    ///////////////////
    /*
     * @param amountSwToMint: The amount of SW you want to mint
     * You can only mint SW if you hav enough collateral
     */
    function mintSw(uint256 amountSwToMint) public moreThanZero(amountSwToMint) nonReentrant {
        s_SWMinted[msg.sender] += amountSwToMint;
        revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_sw.mint(msg.sender, amountSwToMint);

        if (minted != true) {
            revert SWEngine__MintFailed();
        }
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert SWEngine__TransferFailed();
        }
    }

    ///////////////////
    // Private Functions
    ///////////////////
    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert SWEngine__TransferFailed();
        }
    }

    function _burnSw(uint256 amountSwToBurn, address onBehalfOf, address swFrom) private {
        s_SWMinted[onBehalfOf] -= amountSwToBurn;

        bool success = i_sw.transferFrom(swFrom, address(this), amountSwToBurn);
        // This conditional is hypothetically unreachable
        if (!success) {
            revert SWEngine__TransferFailed();
        }
        i_sw.burn(amountSwToBurn);
    }

    //////////////////////////////
    // Private & Internal View & Pure Functions
    //////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalSwMinted, uint256 collateralValueInUsd)
    {
        totalSwMinted = s_SWMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalSwMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalSwMinted, collateralValueInUsd);
    }

    /**
     * // SPDX-License-Identifier: MIT
     * pragma solidity 0.8.18;
     *
     * interface IOracle {
     * function getPrice(address token) external view returns (uint256);
     * }
     *
     * contract Example {
     * address public oracle = address(0x73D72a5A5C5d910f414AdEEA6C44580A2C61A5F2);
     * address public wanBTC = address(0x50c439B6d602297252505a6799d84eA5928bCFb6);
     * address public wanETH = address(0xE3aE74D1518A76715aB4C7BeDF1af73893cd435A);
     *
     * function getWanBtcPrice() external view returns(uint256) {
     *     return IOracle(oracle).getPrice(wanBTC);
     * }
     *
     * function getWanEthPrice() external view returns(uint256) {
     *     return IOracle(oracle).getPrice(wanETH);
     * }
     * }
     *
     */

    //amount is in WEI and the return value is also 1e18!
    // function _getUsdValue(address token, uint256 amount) private view returns (uint256) {
    //     // //uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    //     // uint256 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    //     // uint256 private constant LIQUIDATION_PRECISION = 100;
    //     // uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    //     // uint256 private constant PRECISION = 1e18;
    //     // uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    //     // uint256 private constant FEED_PRECISION = 1e8;
    //     AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
    //     (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
    //     // 1 ETH = 1000 USD
    //     // The returned value from Chainlink will be 1000 * 1e8
    //     // Most USD pairs have 8 decimals, so we will just pretend they all do
    //     // We want to have everything in terms of WEI, so we add 10 zeros at the end
    //     return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    // }

    //return value of the Oracle is 1e18!
    function _getUsdValue(address token, uint256 amount) private view returns (uint256) {
        return (IOracle(s_oracle).getPrice(token) * amount) / PRECISION;
    }

    function _calculateHealthFactor(uint256 totalSwMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalSwMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalSwMinted;
    }

    function revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert SWEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    // External & Public View & Pure Functions
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    function calculateHealthFactor(uint256 totalSwMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalSwMinted, collateralValueInUsd);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalSwMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    function getUsdValue(
        address token,
        uint256 amount // in WEI
    ) external view returns (uint256) {
        return _getUsdValue(token, amount);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 index = 0; index < s_collateralTokens.length; index++) {
            address token = s_collateralTokens[index];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    // function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
    //     AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
    //     (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
    //     // $100e18 USD Debt
    //     // 1 ETH = 2000 USD
    //     // The returned value from Chainlink will be 2000 * 1e8
    //     // Most USD pairs have 8 decimals, so we will just pretend they all do
    //     return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    // }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        return ((usdAmountInWei * PRECISION) / (IOracle(s_oracle).getPrice(token)));
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getSw() external view returns (address) {
        return address(i_sw);
    }

    // function getCollateralTokenPriceFeed(address token) external view returns (address) {
    //     return s_priceFeeds[token];
    // }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}
