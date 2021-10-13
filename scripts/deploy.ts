// deploys the smart contract to the cahin
// refert to hardhat.config.ts
import { ethers } from "hardhat";

async function deploy() {
  const Box = await ethers.getContractFactory("Box");
  const box = await Box.deploy();
  await box.deployed();
  console.log("Box deployed to:", box.address);
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
