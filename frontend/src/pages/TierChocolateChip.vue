<template>
  <q-page padding class="text-center">
    <!-- Account balance -->
    <div class="pancake-form">
      <h5 class="q-mb-sm">Chocolate Chip Account</h5>
      <div class="row justify-center items-center">
        <div class="col-3 text-left">Balance</div>
        <div class="col-3">${{ '0'.toLocaleString() }}</div>
      </div>
      <div class="row justify-center items-center">
        <div class="col-3 text-left">Redeemable For</div>
        <div class="col-3">${{ '0'.toLocaleString() }}</div>
      </div>
    </div>
    <!-- Deposit -->
    <h5 class="q-mb-sm q-mt-xl">Deposit</h5>
    <div v-if="!areDepositsActive">Deposits are no longer accepted for this pool</div>
    <q-form v-else class="pancake-form" @submit="onDeposit">
      <div class="row justify-center items-center">
        <q-input class="col-7 q-mr-sm" v-model.number="depositAmount" outlined label="Amount" />
        <q-select
          class="col-4"
          :options="tokenOptions"
          outlined
          v-model="depositTokenSymbol"
          label="Token"
        />
      </div>
      <q-btn type="submit" label="Deposit" color="primary" class="q-mt-md" />
    </q-form>
    <!-- Withdraw -->
    <h5 class="q-mb-sm q-mt-xl">Withdraw</h5>
    <div v-if="!areWithdrawsActive">
      <div>Withdrawals are not yet available for this pool</div>
      <div class="text-caption">
        If you need access to your funds sooner, you can sell your tokens on
        <a href="https://app.uniswap.org/#/swap" target="_blank" class="hyperlink">Uniswap</a>
      </div>
    </div>
    <q-form v-else class="pancake-form">
      <div class="row justify-center items-center">
        <q-input class="col-7 q-mr-sm" v-model.number="withdrawAmount" outlined label="Amount" />
        <q-select
          class="col-4"
          :options="tokenOptions"
          outlined
          v-model="withdrawTokenSymbol"
          label="Token"
        />
      </div>
      <q-btn type="submit" label="Deposit" color="primary" class="q-mt-md" />
    </q-form>
  </q-page>
</template>

<script>
import { defineComponent, ref } from '@vue/composition-api';

const abi = [
  'function depositChocolateChipDai(uint256 _amount)',
  'function depositChocolateChipEth()payable',
];

function usePancakeManager() {
  const depositAmount = ref(0);
  const depositTokenSymbol = ref('ETH');
  const withdrawAmount = ref(0);
  const withdrawTokenSymbol = ref('ETH');
  const areDepositsActive = ref(true);
  const areWithdrawsActive = ref(false);
  const tokenOptions = ['ETH', 'DAI'];

  function onDeposit() {
    if (depositTokenSymbol.value === 'ETH') {
      // ETH deposit
      alert(`${depositAmount.value} ${depositTokenSymbol.value}`);
    } else if (depositTokenSymbol.value === 'DAI') {
      // DAI deposit
      alert(`${depositAmount.value} ${depositTokenSymbol.value}`);
    } else {
      throw new Error('Invalid token selection');
    }
  }

  return {
    depositAmount,
    depositTokenSymbol,
    withdrawAmount,
    withdrawTokenSymbol,
    areDepositsActive,
    areWithdrawsActive,
    tokenOptions,
    onDeposit,
  };
}

export default defineComponent({
  name: 'PageChocolateChipTier',
  setup() {
    return { ...usePancakeManager() };
  },
});
</script>
