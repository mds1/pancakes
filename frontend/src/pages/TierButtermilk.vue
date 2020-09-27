<template>
  <q-page padding class="text-center">
    <!-- Account balance -->
    <div class="pancake-form">
      <div class="text-grey">${{ ethPrice.toFixed(2) }}/ETH</div>
      <h5 class="q-my-sm">Buttermilk Account</h5>
      <div class="text-caption q-mb-lg">
        Deposits and withdrawals use ETH, but profits and losses are denominated in USD
      </div>
      <div class="row justify-center items-center">
        <div class="col-auto q-mr-lg">
          <div class="text-left">Balance</div>
          <div class="text-left">
            {{ Number(tokenBalance).toFixed(2) }}
            BUTTR
          </div>
        </div>
        <div class="col-auto">
          <div class="text-left">Redeemable For</div>
          <div class="text-left">${{ Number(usdBalance).toFixed(2) }}</div>
        </div>
      </div>
    </div>
    <!-- Deposit -->
    <h5 class="q-mb-sm q-mt-xl">Deposit ETH</h5>
    <div v-if="!areDepositsActive">Deposits are no longer accepted for this pool</div>
    <q-form v-else class="pancake-form" @submit="onDeposit">
      <div class="row justify-center items-center">
        <q-input
          v-model.number="depositAmount"
          class="col-7 q-mr-sm"
          dense
          label="Amount"
          outlined
        />
        <q-btn
          class="col-auto q-mt-md"
          color="primary"
          label="Deposit"
          style="margin: auto 0"
          type="submit"
        />
      </div>
    </q-form>
    <!-- Withdraw -->
    <h5 class="q-mb-sm q-mt-xl">Withdraw ETH</h5>
    <div v-if="!areWithdrawsActive">
      <div>Withdrawals will be available on {{ endDate.toLocaleDateString() }}.</div>
      <div class="text-caption">
        If you need access to your funds sooner, you can sell your tokens on
        <a href="https://app.uniswap.org/#/swap" target="_blank" class="hyperlink">Uniswap</a>.
      </div>
    </div>
    <q-form v-else class="pancake-form" @submit="onWithdraw">
      <div class="row justify-center items-center">
        <q-btn
          class="q-mt-md"
          color="primary"
          label="Withdraw"
          style="margin: auto 0"
          type="submit"
        />
      </div>
    </q-form>
  </q-page>
</template>

<script>
import { defineComponent, ref, onMounted } from '@vue/composition-api';
import { ethers } from 'ethers';
import useWalletStore from 'src/store/wallet';
import useAlerts from 'src/utils/alerts';
import addresses from '../addresses.json';
import pancakeManagerAbi from '../../../contracts/build/contracts/PancakeManager.json';
import tokenAbi from '../../../contracts/build/contracts/PancakeToken.json';

function usePancakeManager() {
  const { userAddress, signer } = useWalletStore();
  const { notifyUser, showError } = useAlerts();
  const pancakeManager = new ethers.Contract(
    addresses.pancakeManager,
    pancakeManagerAbi.abi,
    signer.value
  );

  const depositAmount = ref(0);
  const areDepositsActive = ref(true);
  const areWithdrawsActive = ref(false);
  const endDate = ref(new Date());

  const tokenBalance = ref('0');
  const usdBalance = ref('0');
  const ethPrice = ref(0);

  async function updateBalance() {
    const buttermilkAddress = await pancakeManager.buttermilk();
    const buttermilk = new ethers.Contract(buttermilkAddress, tokenAbi.abi, signer.value);
    const balance = await buttermilk.balanceOf(userAddress.value);
    const buttermilkPrice = await pancakeManager.buttermilkPrice();
    tokenBalance.value = ethers.utils.formatEther(balance);
    usdBalance.value = ethers.utils.formatUnits(balance.mul(buttermilkPrice), 36);
  }

  onMounted(async () => {
    await updateBalance();
    areDepositsActive.value = await pancakeManager.depositsEnabled();
    areWithdrawsActive.value = await pancakeManager.withdrawalsEnabled();
    const startTime = await pancakeManager.startTime();
    const lockupDuration = await pancakeManager.lockupDuration();
    const endTime = startTime.add(lockupDuration).mul(1000); // in milliseconds
    endDate.value = new Date(endTime.toNumber());
    ethPrice.value = (await pancakeManager.currentPriceEthUsd()).toNumber() / 1e8;
  });

  async function onDeposit() {
    try {
      // Send deposit transaction and udpate balance
      const ethAmount = ethers.utils.parseEther(String(depositAmount.value));
      const tx = await pancakeManager.depositButtermilk({ value: ethAmount });
      const receipt = await tx.wait();
      await updateBalance();
      notifyUser('positive', 'Deposit successful!');
    } catch (e) {
      showError(e);
    }
  }

  async function onWithdraw() {
    try {
      // Withdraw all tokens
      const buttermilkAddress = await pancakeManager.buttermilk();
      const buttermilk = new ethers.Contract(buttermilkAddress, tokenAbi.abi, signer.value);
      const balance = await buttermilk.balanceOf(userAddress.value);
      console.log('balance: ', balance);
      const tx = await pancakeManager.withdrawButtermilk(balance);
      const receipt = await tx.wait();
      await updateBalance();
      notifyUser('positive', 'Withdraw successful!');
    } catch (e) {
      showError(e);
    }
  }

  return {
    depositAmount,
    areDepositsActive,
    areWithdrawsActive,
    onDeposit,
    onWithdraw,
    tokenBalance,
    usdBalance,
    endDate,
    ethPrice,
  };
}

export default defineComponent({
  name: 'PageButtermilkTier',
  setup(props, context) {
    const { userAddress } = useWalletStore();
    onMounted(async () => {
      if (!userAddress.value) {
        await context.root.$router.replace({ name: 'home' });
      }
    });
    return { ...usePancakeManager() };
  },
});
</script>
