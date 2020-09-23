const { accounts, contract, web3, BN } = require('@openzeppelin/test-environment');
const { balance, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const { toWei } = web3.utils;
const defaultDaiAmount = toWei('100');
const defaultEthAmount = toWei('1');

const [alice] = accounts;

describe('Buttermilk and Chocolate Chip Tokens', function () {
  let pancakeManager;
  let buttermilk;
  let chocolateChip;

  const PancakeManager = contract.fromArtifact('PancakeManager');
  const PancakeToken = contract.fromArtifact('PancakeToken');

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
    buttermilk = await PancakeToken.at(buttermilkAddress);
    chocolateChip = await PancakeToken.at(chocolateChipAddress);
  });

  describe('Initialization', function () {
    it('Correctly initializes the tokens', async function () {
      expect(await buttermilk.name()).to.equal('Buttermilk Pancake');
      expect(await buttermilk.symbol()).to.equal('BUTTR');
      expect(await buttermilk.decimals()).to.be.bignumber.equal('18');

      expect(await chocolateChip.name()).to.equal('Chocolate Chip Pancake');
      expect(await chocolateChip.symbol()).to.equal('CHOCO');
      expect(await chocolateChip.decimals()).to.be.bignumber.equal('18');
    });
  });

  describe('Deposits', function () {
    it('Lets users join T1 with DAI', async function () {
      // console.log((await pancakeManager.lastPrice()).toString());
      const receipt = await pancakeManager.depositButtermilkDai(defaultDaiAmount, { from: alice });
      // console.log((await pancakeManager.lastPrice()).toString());
    });

    it('Lets users join T1 with ETH', async function () {
      console.log((await pancakeManager.lastPrice()).toString());
      const receipt = await pancakeManager.depositButtermilkEth({
        from: alice,
        value: defaultEthAmount,
      });
      console.log((await pancakeManager.lastPrice()).toString());

      console.log((await buttermilk.balanceOf(alice)).toString());
    });

    it('Lets users join T2 with DAI', async function () {});

    it('Lets users join T3 with ETH', async function () {});
  });
});
