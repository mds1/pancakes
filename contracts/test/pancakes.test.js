const { accounts, contract, web3, BN } = require('@openzeppelin/test-environment');
const { balance, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

describe('Buttermilk and Chocolate Chip Tokens', function () {
  let pancakeManager;
  let buttermilk;
  let chocolateChip;

  const PancakeManager = contract.fromArtifact('PancakeManager');
  const Buttermilk = contract.fromArtifact('Buttermilk');
  const ChocolateChip = contract.fromArtifact('ChocolateChip');

  beforeEach(async () => {
    // Deploy the pancake manager
    pancakeManager = await PancakeManager.new();
    const receipt = await web3.eth.getTransactionReceipt(pancakeManager.transactionHash);
    const logs = await PancakeManager.decodeLogs(receipt.logs);

    // Parse logs to get token addresses
    const buttermilkAddress = logs.filter((log) => log.event === 'ButtermilkDeployed')[0].args
      .contractAddress;
    const chocolateChipAddress = logs.filter((log) => log.event === 'ChocolateChipDeployed')[0].args
      .contractAddress;

    // Get instances of the token contracts
    buttermilk = await Buttermilk.at(buttermilkAddress);
    chocolateChip = await ChocolateChip.at(chocolateChipAddress);
  });

  it('Should correctly initialize the tokens', async function () {
    expect(await buttermilk.name()).to.equal('Buttermilk Pancake');
    expect(await buttermilk.symbol()).to.equal('BUTTR');
    expect(await buttermilk.decimals()).to.be.bignumber.equal('18');

    expect(await chocolateChip.name()).to.equal('Chocolate Chip Pancake');
    expect(await chocolateChip.symbol()).to.equal('CHOCO');
    expect(await chocolateChip.decimals()).to.be.bignumber.equal('18');
  });
});
