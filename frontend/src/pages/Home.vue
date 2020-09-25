<template>
  <q-page padding class="text-center">
    <div>
      Choose your investment
      <div class="row justify-center q-mt-lg">
        <!-- Cancel Transaction -->
        <q-card class="card-border col-xs-4 col-sm-3 col-md-2 q-py-md q-mr-md">
          <connect-wallet redirect-to="buttermilk">
            <q-card-section>
              <div class="text-h5">Buttermilk</div>
              <div class="text-caption">Low-risk, low-return</div>
              <!-- <img src="~assets/fa-trash.png" style="height: 3rem;" /> -->
            </q-card-section>
            <q-card-section> Targets a plain and steady rate of return on your USD </q-card-section>
          </connect-wallet>
        </q-card>

        <!-- Speed up transaction -->
        <q-card class="card-border col-xs-4 col-sm-3 col-md-2 q-py-md q-ml-md">
          <connect-wallet redirect-to="chocolateChip">
            <q-card-section>
              <div class="text-h5">Chocolate Chip</div>
              <div class="text-caption">High-risk, high-return</div>
              <!-- <img src="~assets/fa-speedometer.png" style="height: 3rem;" /> -->
            </q-card-section>
            <q-card-section>
              A sweet investment that amplifies ETH gains and losses
            </q-card-section>
          </connect-wallet>
        </q-card>
      </div>

      <router-link class="cursor-pointer hyperlink q-mt-lg" tag="div" :to="{ name: 'returns' }">
        See historical returns
      </router-link>
    </div>
  </q-page>
</template>

<script lang="ts">
import { defineComponent } from '@vue/composition-api';
import ConnectWallet from 'components/ConnectWallet.vue';

export default defineComponent({
  name: 'PageHome',
  components: { ConnectWallet },

  setup() {
    return {};
  },
});
</script>
