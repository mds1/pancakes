// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./PancakeToken.sol";

/**
 * @notice Main contract
 */
contract PancakeManager {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Token contract instances
  PancakeToken public buttermilk;
  PancakeToken public chocolateChip;

  // Chainlink price feed contract instances
  AggregatorV3Interface internal immutable priceFeedEthUsd;
  AggregatorV3Interface internal immutable priceFeedDaiUsd;

  // DAI Contract
  IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

  // Last prices returned from Chainlink (only used to facilitate testing)
  uint256 public lastPriceEthUsd;
  uint256 public lastPriceDaiUsd;

  // Events
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

  /**
   * @notice Deposit funds into Tier 1 with DAI
   * @param _amount Amount of DAI to deposit
   */
  function depositButtermilkDai(uint256 _amount) external {
    uint256 _price = getDaiUsdPrice();
    lastPriceDaiUsd = _price;

    DAI.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 _output = _amount.mul(_price).div(1e8);
    buttermilk.mint(msg.sender, _output);
  }

  /**
   * @notice Deposit funds into Tier 1 with ETH
   */
  function depositButtermilkEth() external payable {
    uint256 _price = getEthUsdPrice();
    lastPriceEthUsd = _price;

    uint256 _output = msg.value.mul(_price).div(1e8);
    buttermilk.mint(msg.sender, _output);
  }

  /**
   * @notice Deposit funds into Tier 2 with DAI
   * @param _amount Amount of DAI to deposit
   */
  function depositChocolateChipDai(uint256 _amount) external {
    uint256 _price = getDaiUsdPrice();
    lastPriceDaiUsd = _price;

    DAI.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 _output = _amount.mul(_price).div(1e8);
    chocolateChip.mint(msg.sender, _output);
  }

  /**
   * @notice Deposit funds into Tier 2 with ETH
   */
  function depositChocolateChipEth() external payable {
    uint256 _price = getEthUsdPrice();
    lastPriceEthUsd = _price;

    uint256 _output = msg.value.mul(_price).div(1e8);
    chocolateChip.mint(msg.sender, _output);
  }

  // ====================================== Oracle functions =======================================
  /**
   * @notice Gets ETH/USD price, divide result by 1e8 to get human-readable value
   */
  function getEthUsdPrice() internal view returns (uint256) {
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
    return uint256(price);
  }

  /**
   * @notice Gets DAI/USD price, divide result by 1e8 to get human-readable value
   */
  function getDaiUsdPrice() internal view returns (uint256) {
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
    return uint256(price);
  }
}
