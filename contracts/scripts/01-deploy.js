const Web3 = require('web3');
const web3 = new Web3('http://localhost:8545');

const { balance, BN, constants, time } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');
const addresses = require('../addresses.json');

const { toWei } = web3.utils;
const defaultEthAmount = toWei('0.5');
const oneE8 = new BN('100000000'); // 1e8
const oneE18 = new BN('1000000000000000000'); // 1e18
const exchange = addresses.exchange;

const PancakeManagerData = require('../build/contracts/PancakeManager.json');
const admin = web3.eth.accounts.privateKeyToAccount(
  '0xb0057716d5917badaf911b193b12b910811c1497b5bada8d7711f758981c3773'
);

let pancakeManager;
let buttermilk;
let chocolateChip;
let deployReceipt;

const PancakeManager = new web3.eth.Contract(PancakeManagerData.abi);
// const PancakeToken = contract.fromArtifact('PancakeToken');
// const IERC20 = contract.fromArtifact('IERC20');

PancakeManager.deploy({ data: PancakeManagerData.bytecode })
  .send({
    from: admin.address,
    gas: 6000000,
  })
  .on('receipt', async function (receipt) {
    deployReceipt = receipt;
  })
  .then(function (newContractInstance) {
    pancakeManager = newContractInstance;
    console.log('PancakeManager Address: ', pancakeManager.options.address);

    // Get token addresses from the events
    const buttermilkAddress = deployReceipt.events['ButtermilkDeployed'].returnValues[0];
    const chocolateChipAddress = deployReceipt.events['ButtermilkDeployed'].returnValues[0];
  });
