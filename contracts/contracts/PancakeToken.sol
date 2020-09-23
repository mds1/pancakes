// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @notice ERC20 token for a given tier, defined during PancakeManger contruction
 */
contract PancakeToken is ERC20 {
  address public immutable pancakeManager;

  constructor(
    string memory _name,
    string memory _symbol,
    address _pancakeManager
  ) public ERC20(_name, _symbol) {
    pancakeManager = _pancakeManager;
  }

  function mint(address _to, uint256 _amount) external {
    require(msg.sender == pancakeManager, "PancakeManager: Caller not authorized");
    _mint(_to, _amount);
  }
}
