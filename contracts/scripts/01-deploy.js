const ethers = require('ethers');
const PancakeManagerData = require('../build/contracts/PancakeManager.json');

(async function () {
  // Use ganache account 9 as admin
  const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
  const adminWallet = new ethers.Wallet(
    '0xb0057716d5917badaf911b193b12b910811c1497b5bada8d7711f758981c3773',
    provider
  );

  // Deploy contract
  const PancakeManager = new ethers.ContractFactory(
    PancakeManagerData.abi,
    PancakeManagerData.bytecode,
    adminWallet
  );
  const contract = await PancakeManager.deploy();
  await contract.deployTransaction.wait();
  console.log('PancakeManager Address: ', contract.address);
})();
