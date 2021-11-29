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
    [ARBITRAGE]: arbitrageAddress,
    [SHARED_FUNCTIONS]: sharedFunctionsAddress
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
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });