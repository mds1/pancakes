// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./PancakeToken.sol";

/**
 * @notice Main contract
 */
contract PancakeManager is ReentrancyGuard {
  using SafeMath for uint256;
  using SignedSafeMath for int256;
  using SafeERC20 for IERC20;
  using Address for address payable;

  // ======================================= State Varaibles =======================================
  // Token contract instances
  PancakeToken public buttermilk;
  PancakeToken public chocolateChip;

  // Chainlink price feed contract instance
  AggregatorV3Interface public constant priceFeedEthUsd = AggregatorV3Interface(
    0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
  );

  // Prices returned from Chainlink
  uint256 public currentPriceEthUsd; // used to compute price deltas at each update

  // Target return rate for Tier 1 (Buttermilk) users, where 1e8 = 1%
  uint256 public constant targetReturn = 1e7; // 0.1% per day

  // Value of each token in USD, value of 1e18 means 1 token is worth 1 USD
  uint256 public buttermilkPrice = 1e18;
  uint256 public chocolateChipPrice = 1e18;

  // Using two booleans two manage the three phases of operation:
  //   1. Deposits enabled, withdraws disabled (pre-kickoff)
  //   2. No deposits or withdrawals allowed (180 day lockup period)
  //   3. Withdrawals enabled (after the 180 day lockup period)
  bool public depositsEnabled;
  bool public withdrawalsEnabled;

  // Variables for managing the lockup period and redemption
  uint256 public startTime; // time that kickoff was initiated
  uint256 public lockupDuration = 180 * 24 * 3600; // lockup period duration, in seconds

  // Placeholder address to represent ETH
  address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

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

    // Enable deposits
    depositsEnabled = true;

    // Get ETH price that we'll use for the full initialization phase (for simplicity)
    _setEthUsdPrice();
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
   * @notice Deposit funds into Tier 1 with ETH
   */
  function depositButtermilk() external payable beforeLockup {
    uint256 _output = msg.value.mul(currentPriceEthUsd).div(1e8);
    buttermilk.mint(msg.sender, _output);
  }

  /**
   * @notice Deposit funds into Tier 2 with ETH
   */
  function depositChocolateChip() external payable beforeLockup {
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

    // Set properties
    _setEthUsdPrice();
    depositsEnabled = false;
    startTime = block.timestamp;
    // numberOfTokens = buttermilk.totalSupply(); // currently not used
  }

  // ====================================== Update Balances ========================================

  /**
   * @notice Updates USD value that each token is redeemable for, designed to be called each day
   * during the lockup phase
   */
  function update() external duringLockup {
    // Save off the old price, and then update the current price
    int256 _lastPriceEthUsd = int256(currentPriceEthUsd);
    _setEthUsdPrice();

    // Get the return between the two time periods. We scale by 1e8 to keep precision
    int256 _priceDifference = int256(currentPriceEthUsd).sub(_lastPriceEthUsd);
    int256 _returnPercent = _priceDifference.mul(1e8).div(_lastPriceEthUsd);

    // Get previous values
    uint256 _prevT1Price = buttermilkPrice;
    uint256 _prevT2Price = chocolateChipPrice;
    uint256 _prevTotalValueT1 = _prevT1Price; // works since we're not scaling by number of tokens
    uint256 _prevTotalValueT2 = _prevT2Price; // works since we're not scaling by number of tokens

    // Get total profit (scaled by 1e18*1e8)
    int256 _totalProfit = (int256(_prevTotalValueT1).add(int256(_prevTotalValueT2))).mul(
      _returnPercent
    );

    // Calculate desired Buttermilk profit for this timespan (scaled by 1e18*1e8)
    uint256 _desiredT1Profit = _prevTotalValueT1.mul(targetReturn).div(100);

    // Calculate delta values for each token
    int256 _addToT1;
    int256 _addToT2;
    if (int256(_prevTotalValueT2).add(_totalProfit).sub(int256(_desiredT1Profit)) >= 0) {
      // Case 1: There are sufficient funds in T2 to give T1 holders the full return, so we give
      // this to T1 holders and T2 holders get the remainder or take a small loss
      _addToT1 = int256(_desiredT1Profit); // always positive
      _addToT2 = int256(_totalProfit.sub(int256(_desiredT1Profit))); // can be negative
    } else {
      // Case 2: There are not sufficient profits, so T1 holders are given all potential profits
      // and T2 holders take a loss
      _addToT1 = int256(_prevTotalValueT2).add(_totalProfit); // can be negative
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
    chocolateChipPrice = uint256(int256(_prevT2Price).add(_addToT2));
  }

  // ========================================= Withdrawal ==========================================

  /**
   * @notice Sets the contract's state to enable withdrawals
   */
  function enableWithdrawals() external duringLockup {
    uint256 _endTime = startTime + lockupDuration;
    require(block.timestamp >= _endTime, "PancakeManager: Lockup duration not reached");
    withdrawalsEnabled = true;
  }

  /**
   * @notice Burn T1 tokens to withdraw their funds as the selected output token
   * @dev Because funds are burned, no approval or token transfer is needed
   * @param _amount Amount of tokens to redeem
   */
  function withdrawButtermilk(uint256 _amount) external afterLockup nonReentrant {
    // Burn their tokens
    // buttermilk.burn(msg.sender, _amount);

    // Calculate how much USD their tokens are worth
    uint256 _usdAmount = _amount.mul(buttermilkPrice); // scaled by (1e18 * 1e18)

    // Convert to ETH
    // currentPriceEthUsd cannot be updated after lockup ends so is consistent for all users
    uint256 _ethAmount = _usdAmount.div(currentPriceEthUsd).div(1e10); // scaled to 1e18

    // Send funds to user
    msg.sender.sendValue(_ethAmount);
  }

  uint256 public ethAmount;

  /**
   * @notice Withdraw T2 tokens to the selected output token
   * @param _amount Amount of tokens to redeem
   */
  function withdrawChocolateChip(uint256 _amount) external afterLockup nonReentrant {
    // Calculate how much USD their tokens are worth
    uint256 _usdAmount = _amount.mul(chocolateChipPrice); // scaled by (1e18 * 1e18)

    // Convert to ETH
    // currentPriceEthUsd cannot be updated after lockup ends so is consistent for all users
    uint256 _ethAmount = _usdAmount.div(currentPriceEthUsd).div(1e10); // scaled to 1e18
    ethAmount = _ethAmount;

    // Send funds to user
    msg.sender.sendValue(_ethAmount);
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

    // Silence unused variable compiler warnings
    roundId;
    startedAt;
    answeredInRound;

    // If the round is not complete yet, timestamp is 0
    require(timestamp > 0, "Round not complete");
    currentPriceEthUsd = uint256(price);

    // TEMP FOR DEV/TESTING: AFTER KICKOFF, INCREASE PRICE BY 10%
    if (!depositsEnabled && !withdrawalsEnabled) {
      currentPriceEthUsd = currentPriceEthUsd.mul(110).div(100);
    }
  }

  // ======================================= Other functions =======================================
  /**
   * @notice Fallback function to receive ETH
   */
  receive() external payable {}
}
