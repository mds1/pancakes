<template>
  <q-page padding class="text-center">
    <h3 class="q-mb-md">Growth of $1,000</h3>
    <div class="text-caption">
      Returns shown are from a random {{ duration }}-day sample of historical ETH price data.
      <div @click="updatePlot" class="hyperlink">Click to randomize</div>
    </div>
    <div>
      <div
        class="row justify-between text-left text q-pt-lg"
        style="list-style: none; max-width: 500px; margin: 0 auto"
      >
        <div class="col-7">Final value, Buttermilk tokens</div>
        <div class="col-5">
          ${{
            finalValueT1.toLocaleString(undefined, {
              minimumFractionDigits: 2,
              maximumFractionDigits: 2,
            })
          }}
          ({{
            yieldT1.toLocaleString(undefined, {
              minimumFractionDigits: 0,
              maximumFractionDigits: 0,
            })
          }}% return)
        </div>
        <div class="col-7">Final value, Chocolate Chip tokens</div>
        <div class="col-5">
          ${{
            finalValueT2.toLocaleString(undefined, {
              minimumFractionDigits: 2,
              maximumFractionDigits: 2,
            })
          }}
          ({{
            yieldT2.toLocaleString(undefined, {
              minimumFractionDigits: 0,
              maximumFractionDigits: 0,
            })
          }}% return)
        </div>
        <div class="col-7">Final value, ETH</div>
        <div class="col-5">
          ${{
            finalValueEth.toLocaleString(undefined, {
              minimumFractionDigits: 2,
              maximumFractionDigits: 2,
            })
          }}
          ({{
            yieldEth.toLocaleString(undefined, {
              minimumFractionDigits: 0,
              maximumFractionDigits: 0,
            })
          }}% return)
        </div>
      </div>
    </div>
    <div id="returns" />
  </q-page>
</template>

<script>
import { defineComponent, onMounted, ref } from '@vue/composition-api';
import Plotly from 'plotly.js-dist';
import priceData from '../eth-usd-coingecko.json';

function usePlots() {
  const duration = 180; // days
  const finalValueEth = ref(0);
  const finalValueT1 = ref(0);
  const finalValueT2 = ref(0);

  const yieldEth = ref(0);
  const yieldT1 = ref(0);
  const yieldT2 = ref(0);

  function updatePlot() {
    // Chose random slot of `duration` days
    const minIndex = 0;
    const maxIndex = priceData.length - duration;
    const startIndex = Math.floor(Math.random() * (maxIndex - minIndex) + minIndex); // min is inclusive, max is exclusive
    const endIndex = startIndex + duration;

    // Get timestamps and ETH price data
    const dataSet = priceData.slice(startIndex, endIndex);
    const timestamps = dataSet.map((item) => new Date(item.snapped_at));
    const prices = dataSet.map((item) => item.price);

    // Get percent return after each timestep
    const returns = [];
    dataSet.forEach((val, index) => {
      if (index === 0) return;
      returns.push((prices[index] - prices[index - 1]) / prices[index - 1]);
    });

    // Get returns for each tier
    const startPrice = 1000;
    const growthOfEth = [startPrice];
    const growthOfT1 = [startPrice];
    const growthOfT2 = [startPrice];
    const numberOfTokens = 1; // doesn't make a difference here
    const targetT1ReturnRate = 0.001; // 0.1% per day is ~44% APY because ETH returns are wild
    for (let i = 0; i < returns.length; i += 1) {
      // returns has length of 1 less than prices, so returnsEth[index] gives the previous price
      const returnRate = Number(returns[i]);

      // Get pre-existing total value before these returns
      const previousTokenPriceEth = growthOfEth[i];
      const previousTokenPriceT1 = growthOfT1[i];
      const previousTokenPriceT2 = growthOfT2[i];
      const previousTotalValueT1 = previousTokenPriceT1 * numberOfTokens;
      const previousTotalValueT2 = previousTokenPriceT2 * numberOfTokens;

      // Total profit/loss earned by the system after these returns
      const totalProfitT1 = previousTotalValueT1 * returnRate;
      const totalProfitT2 = previousTotalValueT2 * returnRate;
      const totalProfit = totalProfitT1 + totalProfitT2;

      // Get delta value for nominal case. This is equivalent to:
      //   addToEth = previousTokenPriceEth * returnRate
      const addToEth = totalProfit / (numberOfTokens + numberOfTokens); // number of tokens in each tier
      growthOfEth.push(previousTokenPriceEth + addToEth);

      // Desired proft that we want to give T1 token holders, if returns were large enough
      const desiredT1Profit = previousTotalValueT1 * targetT1ReturnRate;

      // Comute Tier 1 and 2 delta values
      let addToT1;
      let addToT2;
      if (previousTotalValueT2 + totalProfit - desiredT1Profit >= 0) {
        // Case 1: There are sufficient funds in T2 to give T1 holders the full return, so we give
        // this to T1 holders and T2 holders get the remainder
        addToT1 = desiredT1Profit / numberOfTokens;
        addToT2 = (totalProfit - desiredT1Profit) / numberOfTokens;
      } else {
        // Case 2: There are not sufficient profits, so T1 holders are given all potential profits
        // and T2 holders take a loss
        addToT1 = (previousTotalValueT2 + totalProfit) / numberOfTokens;
        addToT2 = -previousTotalValueT2 / numberOfTokens;
      }

      growthOfT1.push(previousTokenPriceT1 + addToT1);
      growthOfT2.push(previousTokenPriceT2 + addToT2);
    }

    const traces = [];
    traces.push({
      x: timestamps,
      y: growthOfEth,
      type: 'scatter',
      name: 'ETH',
    });
    traces.push({
      x: timestamps,
      y: growthOfT1,
      type: 'scatter',
      name: 'Buttermilk',
    });
    traces.push({
      x: timestamps,
      y: growthOfT2,
      type: 'scatter',
      name: 'ChocolateChip',
    });

    // Set plot layout
    const layout = {
      xaxis: {
        title: 'Date',
      },
      yaxis: {
        title: 'Value',
        tickprefix: '$',
        hoverformat: '.2f',
      },
    };

    // Update plot
    const data = [...traces];
    Plotly.newPlot('returns', data, layout); // eslint-disable-line

    // Save off data displayed on page
    finalValueEth.value = growthOfEth[growthOfEth.length - 1];
    finalValueT1.value = growthOfT1[growthOfT1.length - 1];
    finalValueT2.value = growthOfT2[growthOfT2.length - 1];

    yieldEth.value = (100 * (finalValueEth.value - startPrice)) / startPrice;
    yieldT1.value = (100 * (finalValueT1.value - startPrice)) / startPrice;
    yieldT2.value = (100 * (finalValueT2.value - startPrice)) / startPrice;
  }

  onMounted(() => updatePlot());

  return {
    updatePlot,
    finalValueEth,
    finalValueT1,
    finalValueT2,
    yieldEth,
    yieldT1,
    yieldT2,
    duration,
  };
}

export default defineComponent({
  name: 'PageReturns',
  setup() {
    return { ...usePlots() };
  },
});
</script>
