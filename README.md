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

To run the localchain

```
npx hardhat node
```

We can interact with the smart contract through the Hardhat console or running a ts file.
look at ./scripts/index.ts for example

```
npx hardhat console --network localhost

or

npx hardhat run --network localhost ./scripts/index.ts
```
