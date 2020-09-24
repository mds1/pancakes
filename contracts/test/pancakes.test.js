const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const { balance, BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');
const addresses = require('../addresses.json');

const { toWei } = web3.utils;
const defaultDaiAmount = toWei('50');
const defaultEthAmount = toWei('0.5');
const oneE8 = new BN('100000000'); // 1e8
const [alice, bob] = accounts;
const exchange = addresses.exchange;

describe('Buttermilk and Chocolate Chip Tokens', function () {
  let pancakeManager;
  let buttermilk;
  let chocolateChip;
  let dai;

  const PancakeManager = contract.fromArtifact('PancakeManager');
  const PancakeToken = contract.fromArtifact('PancakeToken');
  const IERC20 = contract.fromArtifact('IERC20');

  async function transferAndApproveDai(user, amount) {
    // Transfer DAI from exchange to the user
    await dai.transfer(user, amount, { from: exchange });
    // Approve PancakeManager to spend the user's DAI
    await dai.approve(pancakeManager.address, constants.MAX_UINT256, { from: user });
  }

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

    // Get instance of DAI contract
    dai = await IERC20.at(addresses.dai);
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
    it('Lets users join Buttermilk tier with DAI', async function () {
      await transferAndApproveDai(alice, defaultDaiAmount);
      const receipt = await pancakeManager.depositButtermilkDai(defaultDaiAmount, { from: alice });
      const balance = await buttermilk.balanceOf(alice);
      const exchangeRate = await pancakeManager.lastPriceDaiUsd();
      const expectedTokenAmount = new BN(defaultDaiAmount).mul(exchangeRate).div(oneE8);
      expect(balance).to.be.bignumber.equal(expectedTokenAmount);
    });

    it('Lets users join Buttermilk tier with ETH', async function () {
      const receipt = await pancakeManager.depositButtermilkEth({
        from: alice,
        value: defaultEthAmount,
      });
      const balance = await buttermilk.balanceOf(alice);
      const exchangeRate = await pancakeManager.lastPriceEthUsd();
      const expectedTokenAmount = new BN(defaultEthAmount).mul(exchangeRate).div(oneE8);
      expect(balance).to.be.bignumber.equal(expectedTokenAmount);
    });

    it('Lets users join ChocolateChip Tier with DAI', async function () {
      await transferAndApproveDai(alice, defaultDaiAmount);
      const receipt = await pancakeManager.depositChocolateChipDai(defaultDaiAmount, {
        from: alice,
      });
      const balance = await chocolateChip.balanceOf(alice);
      const exchangeRate = await pancakeManager.lastPriceDaiUsd();
      const expectedTokenAmount = new BN(defaultDaiAmount).mul(exchangeRate).div(oneE8);
      expect(balance).to.be.bignumber.equal(expectedTokenAmount);
    });

    it('Lets users join ChocolateChip Tier with ETH', async function () {
      const receipt = await pancakeManager.depositChocolateChipEth({
        from: alice,
        value: defaultEthAmount,
      });
      const balance = await chocolateChip.balanceOf(alice);
      const exchangeRate = await pancakeManager.lastPriceEthUsd();
      const expectedTokenAmount = new BN(defaultEthAmount).mul(exchangeRate).div(oneE8);
      expect(balance).to.be.bignumber.equal(expectedTokenAmount);
    });
  });

  describe('Kickoff', function () {
    it('Initializes the pool', async function () {
      // Have users join both tiers. Only use DAI for now to ensure we don't have to worry about
      // exchange rates and making sure both sides have an equal amount of tokens
      await transferAndApproveDai(alice, defaultDaiAmount);
      await pancakeManager.depositButtermilkDai(defaultDaiAmount, { from: alice });
      await transferAndApproveDai(bob, defaultDaiAmount);
      await pancakeManager.depositChocolateChipDai(defaultDaiAmount, { from: bob });

      // Since we only use DAI here, pool should currently have all DAI and no ETH. After kickoff,
      // it should have all ETH and no DAI
      const initialDaiBalance = await dai.balanceOf(pancakeManager.address);
      const initialEthBalance = await balance.current(pancakeManager.address);
      expect(initialDaiBalance).to.be.bignumber.equal(new BN(defaultDaiAmount).mul(new BN('2')));
      expect(initialEthBalance).to.be.bignumber.equal('0');

      await pancakeManager.kickoff({ from: alice });

      const finalDaiBalance = await dai.balanceOf(pancakeManager.address);
      const finalEthBalance = await balance.current(pancakeManager.address);
      expect(finalDaiBalance).to.be.bignumber.equal('0');
      expect(finalEthBalance).to.be.bignumber.above('0');
    });
  });
});
