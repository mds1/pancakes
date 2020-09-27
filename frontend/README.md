# Pancakes Frontend

Frontend for the Pancakes contracts

- [Pancakes Frontend](#pancakes-frontend)
  - [Development Setup](#development-setup)
  - [Demo](#demo)
    - [Customize the configuration](#customize-the-configuration)

## Development Setup

1. Install dependencies with `yarn`
2. Create a file called `.env` with the following parameters
   ```bash
   INFURA_ID=yourInfuraKey # required
   BLOCKNATIVE_API_KEY=yourBlocknativeKey # required
   PORTIS_API_KEY=yourPortisKey # optional, required for using Portis
   FORTMATIC_API_KEY=yourFortmaticKey # optional, required for using Fortmatic
   ```
3. Run the app with `yarn run dev`

## Demo

The easiest way to interact with the app is with the steps below:

1. Complete the steps in the [Development Setup](#development-setup) section
2. Setup MetaMask to use the default ganache-cli seed phrase of `myth like bonus scare over problem client lizard pioneer submit female collect`
3. Connect MetaMask to localhost port 8545 with chain ID 3729
4. Reset MetaMask state in Settings > Advanced > Reset Account to avoid nonce mismatches between MetaMask and the local chain. This must be done for each account you plan on using
5. Switch to the `contracts` directory and run `yarn run ganache` to start a ganache instance

Now we have a ganache instance that is ready to to be used. Because the Pancake operation is
dependent on Chainlink oracles and time-dependent, there are some helper scripts to facilitate
interaction with this app. These scripts are structured as test files to help make it clear when
each script runs successfully.

To continue interacting with the app:

1. Deploy the Pancake contracts with `yarn run 01-deploy` and paste the PancakeManager address in `src/addresses.json`. This will likely already be popuated correctly
2. In your browser, use account 1 to deposit into the Buttermilk tier and use account 2 to deposit into the Chocolate Chip. You must deploy an equal amount into both tiers before continuing
3. Run `yarn run 02-kickoff` to lock the contract and prevent further deposits. This will simulate a few price updates as well

### Customize the configuration

See [Configuring quasar.conf.js](https://quasar.dev/quasar-cli/quasar-conf-js).
