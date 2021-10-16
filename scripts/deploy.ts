// deploys the smart contract to the cahin
// refert to hardhat.config.ts
import { ethers, upgrades } from "hardhat";
async function deploy() {
  const Box = await ethers.getContractFactory("Box");
  console.log("Deploying Box...");
  const box = await await upgrades.deployProxy(Box, [1000], {
    initializer: "store",
  });
  await box.deployed();
  console.log("Box deployed to:", box.address);
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
