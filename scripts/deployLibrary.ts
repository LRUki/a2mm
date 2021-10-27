// deploys the smart contract to the cahin
// refert to hardhat.config.ts
import { ethers, upgrades } from "hardhat";

const LIBRARY_NAME = "TokenAddrs";

async function deploy() {
  const Contract = await ethers.getContractFactory(LIBRARY_NAME);
  console.log(`Deploying ${LIBRARY_NAME}`);
  const contract = await Contract.deploy();

  await contract.deployed();
  console.log(`${LIBRARY_NAME} deployed to`, contract.address);
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
