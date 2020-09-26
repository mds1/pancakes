// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./PancakeToken.sol";

/**
 * @notice Main contract
 */
contract PancakeManager {
  using SafeMath for uint256;
  using SignedSafeMath for int256;
  using SafeERC20 for IERC20;

  // ======================================= State Varaibles =======================================
  // Token contract instances
  PancakeToken public buttermilk;
  PancakeToken public chocolateChip;

  // Chainlink price feed contract instances
  AggregatorV3Interface internal immutable priceFeedEthUsd;
  AggregatorV3Interface internal immutable priceFeedDaiUsd;

  // DAI Contract
  IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

  // Uniswap parameters
  address public uniswapRouterAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  IUniswapV2Router02 public uniswapRouter = IUniswapV2Router02(uniswapRouterAddress);

  // Prices returned from Chainlink
  uint256 public currentPriceEthUsd; // used to compute price deltas at each update
  uint256 public currentPriceDaiUsd; // only required for testing

  // Target return rate for Tier 1 (Buttermilk) users, where 1e8 = 1%
  uint256 public targetReturn = 1e7; // 0.1% per day

  // Value of each token in USD, value of 1e18 means 1 token is worth 1 USD
  uint256 public buttermilkPrice = 1e18;
  uint256 public chocolateChipPrice = 1e18;

  // Using two booleans two manage the three phases of operation:
  //   1. Deposits enabled, withdraws disabled (pre-kickoff)
  //   2. No deposits or withdrawals allowed (180 day lockup period)
  //   3. Withdrawals enabled (after the 180 day lockup period)
  bool public depositsEnabled;
  bool public withdrawalsEnabled;

  // Number of tokens in each tier is constant and equal, so this variable isn't used now, but it
  // may be useful in a future version to account for unequal demand between the tiers
  // uint256 public numberOfTokens;

  // =========================================== Events ============================================
  event ButtermilkDeployed(address contractAddress);
  event ChocolateChipDeployed(address contractAddress);

  constructor() public {
    // Deploy tokens
    buttermilk = new PancakeToken("Buttermilk Pancake", "BUTTR", address(this));
    chocolateChip = new PancakeToken("Chocolate Chip Pancake", "CHOCO", address(this));

    emit ButtermilkDeployed(address(buttermilk));
    emit ChocolateChipDeployed(address(chocolateChip));

    // Configure price feeds
    priceFeedEthUsd = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    priceFeedDaiUsd = AggregatorV3Interface(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9);

    // Enable deposits
    depositsEnabled = true;
  }

  // ========================================== Modifiers ==========================================

  /**
   * @notice Only allows function to be called before kickoff
   */
  modifier beforeLockup() {
    require(depositsEnabled && !withdrawalsEnabled, "PancakeManager: Initializaion phase ended");
    _;
  }

  /**
   * @notice Only allows function to be called during the lockup period
   */
  modifier duringLockup() {
    require(!depositsEnabled && !withdrawalsEnabled, "PancakeManager: Not in lockup phase");
    _;
  }

  /**
   * @notice Only allows function to be called after the lockup period
   */
  modifier afterLockup() {
    require(!depositsEnabled && withdrawalsEnabled, "PancakeManager: Not in finalization phase");
    _;
  }

  // ============================================ Join =============================================
  /**
   * @notice Deposit funds into Tier 1 with DAI
   * @param _amount Amount of DAI to deposit
   */
  function depositButtermilkDai(uint256 _amount) external beforeLockup {
    _setDaiUsdPrice();
    DAI.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 _output = _amount.mul(currentPriceDaiUsd).div(1e8);
    buttermilk.mint(msg.sender, _output);
  }

  /**
   * @notice Deposit funds into Tier 1 with ETH
   */
  function depositButtermilkEth() external payable beforeLockup {
    _setEthUsdPrice();
    uint256 _output = msg.value.mul(currentPriceEthUsd).div(1e8);
    buttermilk.mint(msg.sender, _output);
  }

  /**
   * @notice Deposit funds into Tier 2 with DAI
   * @param _amount Amount of DAI to deposit
   */
  function depositChocolateChipDai(uint256 _amount) external beforeLockup {
    _setDaiUsdPrice();
    DAI.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 _output = _amount.mul(currentPriceDaiUsd).div(1e8);
    chocolateChip.mint(msg.sender, _output);
  }

  /**
   * @notice Deposit funds into Tier 2 with ETH
   */
  function depositChocolateChipEth() external payable beforeLockup {
    _setEthUsdPrice();
    uint256 _output = msg.value.mul(currentPriceEthUsd).div(1e8);
    chocolateChip.mint(msg.sender, _output);
  }

  // =========================================== Kickoff ===========================================

  /**
   @notice Officially starts the pool. All funds are converted to ETH and no one else can join
   */
  function kickoff() external {
    require(depositsEnabled, "PancakeManager: Already started");
    require(
      buttermilk.totalSupply() == chocolateChip.totalSupply(),
      "PancakeManager: Invalid start condition"
    );

    // Convert all DAI to ETH and mark as initialized
    _swapDaiForEth();

    // Set properties
    _setEthUsdPrice();
    // numberOfTokens = buttermilk.totalSupply();
    depositsEnabled = false;
  }

  // ====================================== Update Balances ========================================

  /**
   * @notice Updates USD value that each token is redeemable for, designed to be called each day
   */
  function update() external duringLockup {
    // Save off the old price, and then update the current price
    uint256 _lastPriceEthUsd = currentPriceEthUsd;
    _setEthUsdPrice();

    // Get the return between the two time periods. We scale by 1e8 to keep precision
    uint256 _priceDifference = currentPriceEthUsd.sub(_lastPriceEthUsd);
    uint256 _returnPercent = (_priceDifference).mul(1e8).div(_lastPriceEthUsd);

    // Get previous values
    uint256 _prevT1Price = buttermilkPrice;
    uint256 _prevT2Price = chocolateChipPrice;
    uint256 _prevTotalValueT1 = _prevT1Price; // true since we're not scaling by number of tokens
    uint256 _prevTotalValueT2 = _prevT2Price; // true since we're not scaling by number of tokens

    // Get total profit (scaled by 1e18*1e8)
    uint256 _totalProfit = (_prevTotalValueT1.add(_prevTotalValueT2)).mul(_returnPercent);

    // Calculate desired Buttermilk profit for this timespan (scaled by 1e18*1e8)
    uint256 _desiredT1Profit = _prevTotalValueT1.mul(targetReturn).div(100);

    // Calculate delta values for each token
    int256 _addToT1;
    int256 _addToT2;
    if (_prevTotalValueT2.add(_totalProfit).sub(_desiredT1Profit) >= 0) {
      // Case 1: There are sufficient funds in T2 to give T1 holders the full return, so we give
      // this to T1 holders and T2 holders get the remainder or take a small loss
      _addToT1 = int256(_desiredT1Profit); // always positive
      _addToT2 = int256(_totalProfit.sub(_desiredT1Profit)); // can be negative
    } else {
      // Case 2: There are not sufficient profits, so T1 holders are given all potential profits
      // and T2 holders take a loss
      _addToT1 = int256(_prevTotalValueT2.add(_totalProfit)); // can be negative
      _addToT2 = int256(_prevTotalValueT2).mul(-1); // always negative
    }

    // Scale amounts to add down by 1e18 since token price uses 18 digits and these are 26 digits
    _addToT1 = _addToT1.div(1e8);
    _addToT2 = _addToT2.div(1e8);

    // Update value of each token after checking to ensure we won't end up with a negative price
    //   requirement: prevTnPrice + addToTn >= 0 --> prevTnPrice >= -addToTn
    require(int256(_prevT1Price) >= _addToT1.mul(-1), "PancakeManager: Invalid T1 condition");
    require(int256(_prevT2Price) >= _addToT2.mul(-1), "PancakeManager: Invalid T2 condition");
    buttermilkPrice = uint256(int256(_prevT1Price).add(_addToT1));
    chocolateChipPrice = uint256(int256(_prevT1Price).add(_addToT2));
  }

  // ====================================== Oracle functions =======================================
  /**
   * @notice Gets ETH/USD price.
   * @dev Divide result by 1e8 to get human-readable value
   */
  function _setEthUsdPrice() internal {
    (
      uint80 roundId,
      int256 price,
      uint256 startedAt,
      uint256 timestamp,
      uint80 answeredInRound
    ) = priceFeedEthUsd.latestRoundData();

    // TEMP FOR DEV/TESTING: IF PRICE IS NOT ZERO, FORCE A CHANGE
    bool isPriceZero = currentPriceEthUsd == 0;

    // Silence unused variable compiler warnings
    roundId;
    startedAt;
    answeredInRound;

    // If the round is not complete yet, timestamp is 0
    require(timestamp > 0, "Round not complete");
    currentPriceEthUsd = uint256(price);

    // TEMP FOR DEV/TESTING: IF PRICE IS NOT ZERO, FORCE A 10% increase
    if (!isPriceZero) {
      currentPriceEthUsd = currentPriceEthUsd.mul(110).div(100);
    }
  }

  /**
   * @notice Gets DAI/USD price.
   * @dev Divide result by 1e8 to get human-readable value
   */
  function _setDaiUsdPrice() internal {
    (
      uint80 roundId,
      int256 price,
      uint256 startedAt,
      uint256 timestamp,
      uint80 answeredInRound
    ) = priceFeedDaiUsd.latestRoundData();

    // Silence unused variable compiler warnings
    roundId;
    startedAt;
    answeredInRound;

    // If the round is not complete yet, timestamp is 0
    require(timestamp > 0, "Round not complete");
    currentPriceDaiUsd = uint256(price);
  }

  // ====================================== Uniswap functions ======================================
  /**
   * @notice Converts all DAI in this contract to ETH
   */
  function _swapDaiForEth() internal {
    require(DAI.approve(uniswapRouterAddress, uint256(-1)), "PancakeManager: Approval failed");

    address[] memory _path = new address[](2);
    _path[0] = address(DAI);
    _path[1] = uniswapRouter.WETH();

    uniswapRouter.swapExactTokensForETH(
      DAI.balanceOf(address(this)), // amountIn
      0, // amountOutMin
      _path, // path
      address(this), // recipient
      block.timestamp // deadline
    );
  }

  // ======================================= Other functions =======================================
  /**
   * @notice Fallback function to receive ETH after swapping with Uniswap
   */
  receive() external payable {}
}
