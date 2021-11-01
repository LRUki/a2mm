// this file shows how to interact with smart contract programatically
import { ethers } from "hardhat";
import { Libraries } from "hardhat/types";
import deployContract from "./deploy";

const LIBRARY_NAME = "TokenAddrs";
const CONTRACT_NAME = "UniV3PriceFeed";
async function main() {
  //deploy the library
  const libraryAddress: string = await deployContract(LIBRARY_NAME);
  const libraries: Libraries = { [LIBRARY_NAME]: libraryAddress };
  //deploy the contract
  const contractAddress: string = await deployContract(
    CONTRACT_NAME,
    libraries
  );

  const Contract = await ethers.getContractFactory(CONTRACT_NAME, {
    libraries,
  });
  const contract = await Contract.attach(contractAddress);
  console.log("======================================================");
  console.log("ETH:USDT");
  await contract.getPrice(0, 3, `${Math.pow(10, 12)}`);
  console.log("ETH:UNI");
  await contract.getPrice(0, 1, `${Math.pow(10, 18)}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
