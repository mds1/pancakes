<template>
  <q-page padding class="text-center">
    <!-- Account balance -->
    <div class="pancake-form">
      <h5 class="q-mb-sm">Buttermilk Account</h5>
      <div class="text-caption q-mb-lg">
        Deposits and withdrawals use ETH, but profits and losses are denominated in USD
      </div>
      <div class="row justify-center items-center">
        <div class="col-3 text-left">Balance</div>
        <div class="col-3 text-left">
          {{ Number(tokenBalance).toFixed(2) }}
          BUTTR
        </div>
      </div>
      <div class="row justify-center items-center">
        <div class="col-3 text-left">Redeemable For</div>
        <div class="col-3 text-left">${{ Number(usdBalance).toFixed(2) }}</div>
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
      <div>Withdrawals are not yet available for this pool.</div>
      <div class="text-caption">
        If you need access to your funds sooner, you can sell your tokens on
        <a href="https://app.uniswap.org/#/swap" target="_blank" class="hyperlink">Uniswap</a>.
      </div>
    </div>
    <q-form v-else class="pancake-form">
      <div class="row justify-center items-center">
        <q-input
          v-model.number="withdrawAmount"
          class="col-7 q-mr-sm"
          dense
          label="Amount"
          outlined
        />
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
  const withdrawAmount = ref(0);
  const areDepositsActive = ref(true);
  const areWithdrawsActive = ref(false);

  const tokenBalance = ref('0');
  const usdBalance = ref('0');

  async function updateBalance() {
    const buttermilkAddress = await pancakeManager.buttermilk();
    const buttermilk = new ethers.Contract(buttermilkAddress, tokenAbi.abi, signer.value);
    const balance = await buttermilk.balanceOf(userAddress.value);
    const buttermilkPrice = await pancakeManager.buttermilkPrice();
    tokenBalance.value = ethers.utils.formatEther(balance);
    usdBalance.value = ethers.utils.formatUnits(balance.mul(buttermilkPrice), 36);
  }

  onMounted(async () => await updateBalance());

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

  return {
    depositAmount,
    withdrawAmount,
    areDepositsActive,
    areWithdrawsActive,
    onDeposit,
    tokenBalance,
    usdBalance,
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
