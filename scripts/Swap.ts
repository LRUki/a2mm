// this file shows how to interact with smart contract programatically
import { ethers } from "hardhat";
import { Libraries } from "hardhat/types";
import { abi } from "../artifacts/contracts/Swap.sol/Swap.json";
import deployContract from "./utils/deploy";
import { writeFileSync} from 'fs';



const SHARED_FUNCTIONS = "SharedFunctions"
const ROUTING = "Route";
const ARBITRAGE = "Arbitrage";
const CONTRACT_NAME = "Swap";
async function main() {
  //deploy the deps
  const sharedFunctionsAddress: string = await deployContract(SHARED_FUNCTIONS)
  const routingAddress: string = await deployContract(ROUTING, {
    [SHARED_FUNCTIONS]: sharedFunctionsAddress,
  });
  const arbitrageAddress: string = await deployContract(ARBITRAGE, {
    [SHARED_FUNCTIONS]: sharedFunctionsAddress,
  })

  const libraries: Libraries = {
    [ROUTING]: routingAddress,
    [ARBITRAGE]: arbitrageAddress
  };

  //deploy the contract
  const contractAddress: string = await deployContract(
    CONTRACT_NAME,
    libraries
  );

  const abiString = JSON.stringify({
    contractAddress: contractAddress,
    contractAbi: abi
  });

  writeFileSync("swap-contract.json", abiString);

  // const Contract = await ethers.getContractFactory(CONTRACT_NAME, {
  //   libraries,
  // });
  // const contract = await Contract.attach(contractAddress);
  // console.log("======================================================");
  // console.log("ETH:USDT");
  // let tx = await contract.getPrice(
  //   Token.WETH,
  //   Token.USDT,
  //   `${Math.pow(10, 12)}`
  // );
  // let response = await tx.wait();
  // console.log(
  //   "Event emitted",
  //   response.events[0].event,
  //   response.events[0].args
  // );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
