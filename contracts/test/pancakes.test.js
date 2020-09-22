const { expect } = require('chai');

describe('Buttermilk and Chocolate Chip Tokens', function () {
  let pancakeManager;
  let buttermilk;
  let chocolateChip;

  beforeEach(async () => {
    // Deploy the pancake manager
    const PancakeManager = await ethers.getContractFactory('PancakeManager');
    pancakeManager = await PancakeManager.deploy();
    const tx = await pancakeManager.deployed();
    const receipt = await tx.deployTransaction.wait();

    // Parse logs to get token addresses
    const logs = receipt.logs.map((log) => pancakeManager.interface.parseLog(log));
    const buttermilkAddress = logs.filter((log) => log.name === 'ButtermilkDeployed')[0].args
      .contractAddress;
    const chocolateChipAddress = logs.filter((log) => log.name === 'ChocolateChipDeployed')[0].args
      .contractAddress;

    // Get instances of the token contracts
    buttermilk = await ethers.getContractAt('Buttermilk', buttermilkAddress);
    chocolateChip = await ethers.getContractAt('Buttermilk', chocolateChipAddress);
  });

  it('Should correctly initialize the tokens', async function () {
    expect(await buttermilk.name()).to.equal('Buttermilk Pancake');
    expect(await buttermilk.symbol()).to.equal('BUTTR');
    expect(await buttermilk.decimals()).to.equal(18);

    expect(await chocolateChip.name()).to.equal('Chocolate Chip Pancake');
    expect(await chocolateChip.symbol()).to.equal('CHOCO');
    expect(await chocolateChip.decimals()).to.equal(18);
  });
});
