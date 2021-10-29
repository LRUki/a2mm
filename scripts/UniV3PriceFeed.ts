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

  let value = await contract.getAddres(0);
  console.log("Address of WETH is", value.toString());
  value = await contract.getPrice(1);
  console.log("1AXS=", value.toString(), value.value.toString());
  value = await contract.getPrice(100);
  console.log("100AXS=", value.value.toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
