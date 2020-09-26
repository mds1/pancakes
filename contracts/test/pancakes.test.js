const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const { balance, BN, constants, time } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');
const addresses = require('../addresses.json');

const { toWei } = web3.utils;
const defaultEthAmount = toWei('0.5');
const oneE8 = new BN('100000000'); // 1e8
const oneE18 = new BN('1000000000000000000'); // 1e18
const [alice, bob] = accounts;
const exchange = addresses.exchange;

describe('Buttermilk and Chocolate Chip Tokens', function () {
  let pancakeManager;
  let buttermilk;
  let chocolateChip;

  const PancakeManager = contract.fromArtifact('PancakeManager');
  const PancakeToken = contract.fromArtifact('PancakeToken');
  const IERC20 = contract.fromArtifact('IERC20');

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
    it('Lets users join Buttermilk tier with ETH', async function () {
      const receipt = await pancakeManager.depositButtermilk({
        from: alice,
        value: defaultEthAmount,
      });
      const balance = await buttermilk.balanceOf(alice);
      const exchangeRate = await pancakeManager.currentPriceEthUsd();
      const expectedTokenAmount = new BN(defaultEthAmount).mul(exchangeRate).div(oneE8);
      expect(balance).to.be.bignumber.equal(expectedTokenAmount);
    });

    it('Lets users join ChocolateChip Tier with ETH', async function () {
      const receipt = await pancakeManager.depositChocolateChip({
        from: alice,
        value: defaultEthAmount,
      });
      const balance = await chocolateChip.balanceOf(alice);
      const exchangeRate = await pancakeManager.currentPriceEthUsd();
      const expectedTokenAmount = new BN(defaultEthAmount).mul(exchangeRate).div(oneE8);
      expect(balance).to.be.bignumber.equal(expectedTokenAmount);
    });
  });

  describe('Kickoff', function () {
    it('Initializes the pool', async function () {
      // Have users join both tiers
      await pancakeManager.depositButtermilk({
        from: alice,
        value: defaultEthAmount,
      });
      await pancakeManager.depositChocolateChip({
        from: bob,
        value: defaultEthAmount,
      });

      expect(await pancakeManager.depositsEnabled()).to.be.true;
      const receipt = await pancakeManager.kickoff();
      expect(await pancakeManager.depositsEnabled()).to.be.false;
      expect(await pancakeManager.startTime()).to.be.bignumber.above('0');
    });
  });

  describe('Main functionality', () => {
    it('Updates value that tokens are redeemable for', async () => {
      expect(await pancakeManager.buttermilkPrice()).to.be.bignumber.equal(oneE18);
      expect(await pancakeManager.chocolateChipPrice()).to.be.bignumber.equal(oneE18);

      // Initialize pool
      await pancakeManager.depositButtermilk({
        from: alice,
        value: defaultEthAmount,
      });
      await pancakeManager.depositChocolateChip({
        from: bob,
        value: defaultEthAmount,
      });
      await pancakeManager.kickoff();
      await pancakeManager.update();

      // We expect Buttermilk Tier to get the full 0.1% being targeted. We calculate expected final
      // amount used (1 + 0.1/100) = 10010/10000
      const expectedButtermilkPrice = oneE18.mul(new BN(10010)).div(new BN(10000));
      const finalButtermilkPrice = await pancakeManager.buttermilkPrice();
      expect(finalButtermilkPrice).to.be.bignumber.equal(expectedButtermilkPrice);

      // Now ChocolateChip should get the remainder. The expected amount of their bump is +10% from
      // the price increase and +9.9% from the unused portion from T1 holders, giving 19.9% total,
      // or (1 + 19.9/100) = 1199/1000
      const expectedChocolateChipPrice = oneE18.mul(new BN(1199)).div(new BN(1000));
      const finalChocolateChipPrice = await pancakeManager.chocolateChipPrice();
      expect(finalChocolateChipPrice).to.be.bignumber.equal(expectedChocolateChipPrice);
    });
  });

  describe('Withdraws', () => {
    it('Lets all token holders redeem their tokens for ETH', async () => {
      // Initialize, update, and finalize pool
      await pancakeManager.depositButtermilk({
        from: alice,
        value: defaultEthAmount,
      });
      await pancakeManager.depositChocolateChip({
        from: bob,
        value: defaultEthAmount,
      });
      await pancakeManager.kickoff();
      await pancakeManager.update();
      await pancakeManager.update();
      await pancakeManager.update();
      await pancakeManager.update();
      await pancakeManager.update();

      // Skip time to enable withdrawals
      const startTime = await pancakeManager.startTime();
      const lockupDuration = await pancakeManager.lockupDuration();
      const endTime = startTime.add(lockupDuration);
      await time.increaseTo(endTime);
      await pancakeManager.enableWithdrawals();

      // Withdraw Alice's funds
      const amountToWithdrawAlice = await buttermilk.balanceOf(alice);
      const initialEthBalanceAlice = await balance.current(alice);
      await pancakeManager.withdrawButtermilk(amountToWithdrawAlice, { from: alice });
      const finalEthBalanceAlice = await balance.current(alice);
      expect(finalEthBalanceAlice).to.be.bignumber.above(initialEthBalanceAlice);

      // Withdraw Bob's funds
      const amountToWithdrawBob = await chocolateChip.balanceOf(bob);
      const initialEthBalanceBob = await balance.current(bob);
      await pancakeManager.withdrawChocolateChip(amountToWithdrawBob, { from: bob });
      const finalEthBalanceBob = await balance.current(bob);
      expect(finalEthBalanceBob).to.be.bignumber.above(initialEthBalanceBob);
    });
  });
});
