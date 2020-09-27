const ethers = require('ethers');
const PancakeManagerData = require('../build/contracts/PancakeManager.json');

(async function () {
  // Use ganache account 9 as admin
  const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
  const adminWallet = new ethers.Wallet(
    '0xb0057716d5917badaf911b193b12b910811c1497b5bada8d7711f758981c3773',
    provider
  );

  // Connect to PancakeManager (address is deterministic so we can hardcode it here)
  const pancakeManagerAddress = '0x27D44c7337ce4D67b7cd573e9c36bDEED2b2162a';
  const pancakeManager = new ethers.Contract(
    pancakeManagerAddress,
    PancakeManagerData.abi,
    adminWallet
  );

  // Update the price a few times
  for (let i = 0; i < 25; i += 1) {
    const updateTx = await pancakeManager.update();
    await updateTx.wait();
  }
  console.log('Price updates successful');
})();
