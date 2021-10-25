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

To deploy the contract to localhost and ropsten

```
npm run deploy --network=localhost
npm run deploy --network=ropsten
```

To run the tests

```
npx hardhat test
```

To upgrade the contract at [address] to localhost and ropsten

```
npm run upgrade --network=localhost --address=[address]
npm run upgrade --network=ropsten --address=[address]
```

Make sure you are running the blockchain locally first when deploying the contract locally.

```
npx hardhat node
```

We can use the Hardhat console to interact with our deployed Box contract on our localhost network.

```
npx hardhat console --network localhost
```
