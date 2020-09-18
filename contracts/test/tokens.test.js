const { expect } = require('chai');

describe('Buttermilk and Chocolate Chip Tokens', function () {
  let buttermilk;
  let chocolateChip;

  beforeEach(async () => {
    // Deploy the two token contracts
    const Buttermilk = await ethers.getContractFactory('Buttermilk');
    const ChocolateChip = await ethers.getContractFactory('ChocolateChip');
    buttermilk = await Buttermilk.deploy();
    chocolateChip = await ChocolateChip.deploy();
    await buttermilk.deployed();
    await chocolateChip.deployed();
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
