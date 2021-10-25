# v1-core

core a2mm smart contract

we need node version above 12.x for hardhat

first start by installing the packages

```
npm install
```

The compile built-in task will automatically look for all contracts in the contracts directory, and compile them using the Solidity compiler using the configuration in hardhat.config.js.
You will notice an artifacts directory was created: it holds the compiled artifacts (bytecode and metadata), which are .json files) this contains the ABI needed for the frontend to interact with the contract
This

```
npx hardhat compile
```

To run the tests

```
npx hardhat test
```

You could run the blockchain with the same state as the mainnet locally by running

```
npx hardhat node
```

To deploy/upgrade the contract locally run the following commands respectively.
[address] is the address of the previously deployed contract

```
npm run deploy --network=localhost
npm run upgrade --network=localhost --address=[address]
```

similarly with ropsten testnet,

```
npm run deploy --network=ropsten
npm run upgrade --network=ropsten --address=[address]
```

We can interact with the smart contract through the Hardhat console or running a ts file.
look at ./scripts/index.ts for example

```
//make sure you change the address of the smart contract if it's redeployed.
npx hardhat console --network localhost

or

npx hardhat run --network localhost ./scripts/index.ts
```
