// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.6.12;

import "@nomiclabs/buidler/console.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@chainlink/contracts/src/v0.6/AggregatorV3Interface.sol";
import "./Buttermilk.sol";
import "./ChocolateChip.sol";

/**
 * @notice Main contract
 */
contract PancakeManager {
  // Token contract instances
  Buttermilk public buttermilk;
  ChocolateChip public chocolateChip;

  // Chainlink price feed contract instances
  AggregatorV3Interface internal immutable priceFeedEthUsd;
  AggregatorV3Interface internal immutable priceFeedDaiUsd;

  // Events
  event ButtermilkDeployed(address contractAddress);
  event ChocolateChipDeployed(address contractAddress);

  constructor() public {
    // Deploy tokens
    buttermilk = new Buttermilk();
    chocolateChip = new ChocolateChip();

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
  function depositDaiButtermilk(uint256 _amount) external {}

  /**
   * @notice Deposit funds into Tier 1 with ETH
   */
  function depositEthButtermilk() external payable {}

  /**
   * @notice Deposit funds into Tier 2 with DAI
   * @param _amount Amount of DAI to deposit
   */
  function depositDaiChocolateChip(uint256 _amount) external {}

  /**
   * @notice Deposit funds into Tier 2 with ETH
   */
  function depositEthChocolateChip() external payable {}

  /**
   * @notice Gets ETH/USD price
   */
  function getEthUsdPrice() internal view returns (uint256) {
    (
      uint80 roundId,
      int256 price,
      uint256 startedAt,
      uint256 timestamp,
      uint80 answeredInRound
    ) = priceFeed.latestRoundData();

    // Silence unused variable compiler warnings
    roundId;
    startedAt;
    answeredInRound;

    // If the round is not complete yet, timestamp is 0
    require(timestamp > 0, "Round not complete");
    return price;
  }
}
