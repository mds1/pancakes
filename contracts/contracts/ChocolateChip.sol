// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @notice ERC20 token for Tier 2
 */
contract ChocolateChip is ERC20("Chocolate Chip Pancake", "CHOCO") {
  address public immutable pancakeManager;

  constructor(address _pancakeManager) public {
    pancakeManager = _pancakeManager;
  }

  function mint(address _to, uint256 _amount) external {
    require(msg.sender == pancakeManager, "PancakeManager: Caller not authorized");
  }
}
