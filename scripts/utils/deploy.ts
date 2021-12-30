// deploys the smart contract to the cahin
// refert to hardhat.config.ts
import { BaseContract } from "@ethersproject/contracts";
import { ethers } from "hardhat";
import { Libraries } from "hardhat/types";

export default async (
  contractName: string,
  libraries: Libraries = {},
  args: Array<any> = []
): Promise<BaseContract["address"]> => {
  const Contract = await ethers.getContractFactory(contractName, {
    libraries,
  });
  // console.log(`Deploying ${contractName}`);
  const contract = await Contract.deploy(args);

  await contract.deployed();
  // console.log(`${contractName} deployed to`, contract.address);

  return contract.address;
};
