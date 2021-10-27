// deploys the smart contract to the cahin
// refert to hardhat.config.ts
import { ethers, upgrades } from "hardhat";

const CONTRACT_NAME = "UniV3PriceFeed";

async function deploy() {
  const Contract = await ethers.getContractFactory(CONTRACT_NAME, {
    libraries: {
      TokenAddrs: "0x2B0d36FACD61B71CC05ab8F3D2355ec3631C0dd5",
    },
  });
  console.log(`Deploying ${CONTRACT_NAME}`);
  const contract = await Contract.deploy();

  await contract.deployed();
  console.log(`${CONTRACT_NAME} deployed to`, contract.address);
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
