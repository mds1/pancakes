// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./PancakeToken.sol";

/**
 * @notice Main contract
 */
contract PancakeManager {
  using SafeMath for uint256;
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
  uint256 public lastPriceEthUsd; // used to compute price deltas at each update
  uint256 public lastPriceDaiUsd; // only required for testing

  // If true, no further deposits are allowed
  bool public hasStarted = false;

  // Target return rate for Tier 1 (Buttermilk) users, where 300 = 3%
  uint256 public targetRate = 300;

  // Value of each token in USD, value of 1e18 means 1 token is worth 1 USD
  uint256 public buttermilkER = 1e18;
  uint256 public chocolateChipER = 1e18;

  // Number of tokens in each tier is constant and equal
  uint256 public numberOfTokens;

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
  }

  // ============================================ Join =============================================
  /**
   * @notice Deposit funds into Tier 1 with DAI
   * @param _amount Amount of DAI to deposit
   */
  function depositButtermilkDai(uint256 _amount) external {
    _setDaiUsdPrice();
    DAI.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 _output = _amount.mul(lastPriceDaiUsd).div(1e8);
    buttermilk.mint(msg.sender, _output);
  }

  /**
   * @notice Deposit funds into Tier 1 with ETH
   */
  function depositButtermilkEth() external payable {
    _setEthUsdPrice();
    uint256 _output = msg.value.mul(lastPriceEthUsd).div(1e8);
    buttermilk.mint(msg.sender, _output);
  }

  /**
   * @notice Deposit funds into Tier 2 with DAI
   * @param _amount Amount of DAI to deposit
   */
  function depositChocolateChipDai(uint256 _amount) external {
    _setDaiUsdPrice();
    DAI.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 _output = _amount.mul(lastPriceDaiUsd).div(1e8);
    chocolateChip.mint(msg.sender, _output);
  }

  /**
   * @notice Deposit funds into Tier 2 with ETH
   */
  function depositChocolateChipEth() external payable {
    _setEthUsdPrice();
    uint256 _output = msg.value.mul(lastPriceEthUsd).div(1e8);
    chocolateChip.mint(msg.sender, _output);
  }

  // =========================================== Kickoff ===========================================

  /**
   @notice Officially starts the pool. All funds are converted to ETH and no one else can join
   */
  function kickoff() external {
    require(!hasStarted, "PancakeManager: Already started");
    require(
      buttermilk.totalSupply() == chocolateChip.totalSupply(),
      "PancakeManager: Invalid start condition"
    );

    // Convert all DAI to ETH and mark as initialized
    _swapDaiForEth();

    // Set properties
    _setEthUsdPrice();
    numberOfTokens = buttermilk.totalSupply();
    hasStarted = true;
  }

  // ====================================== Update Balances ========================================

  /**
   * @notice Updates USD value that each token is redeemable for
   * @dev Nomenclature is as follows, with all values in USD
   *   - x1  = total value of tokens in tier 1
   *   - x2  = total value of tokens in tier 2
   *   - y1  = total profit earned by tier 1
   *   - Y   = total, combined profit earned by the system
   *   - dk1 = change in token value of tier 1 tokens
   *   - dk2 = change in token value of tier 2 tokens
   */
  function update() external {
    // Save off the old price, and then update the current price
    uint256 _prevPriceEthUsd = lastPriceEthUsd;
    _setEthUsdPrice();

    // Calculate change in token value for tier 1
    // uint256 dk1 = 
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
    lastPriceEthUsd = uint256(price);
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
    lastPriceDaiUsd = uint256(price);
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

  /**
   * @notice Fallback function to receive ETH after swapping with Uniswap
   */
  receive() external payable {}
}
