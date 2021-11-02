import { ethers } from "hardhat";
import deployContract from "./deploy";

const addresses = {
  WETH: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
  DAI: '0x6b175474e89094c44da98b954eedeac495271d0f',
  factory: '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f', 
}

const CONTRACT_NAME = "UniV2PriceFeed";
async function main() {
  //deploy the contract
  const contractAddress: string = await deployContract(
    CONTRACT_NAME,
  );

  const Contract = await ethers.getContractFactory(CONTRACT_NAME);
  const contract = await Contract.attach(contractAddress);
  const pairAddress = await contract.getPair(addresses.factory, addresses.WETH, addresses.DAI)
  const pairAddress2 = await contract.getPair(addresses.factory, addresses.DAI, addresses.WETH)


  let pairReserves1 = await contract.getReservesPair(pairAddress, 1);
  console.log("The price in the pool is: ", pairReserves1.toString());


  let pairReserves2 = await contract.getReservesPair(pairAddress2, 1);
  console.log("The price in the pool is: ", pairReserves1.toString());

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });