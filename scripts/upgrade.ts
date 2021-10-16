//upgrades a smart contract deployed at 'ADDRESS'
import { ethers, upgrades } from "hardhat";
//address at which
const ADDRESS = process.env.ADDRESS;
async function upgrade() {
  if (!ADDRESS) {
    throw new Error("please provide the address of the contract");
  }
  const newBox = await ethers.getContractFactory("Box");
  console.log(`"Upgrading contract at ${ADDRESS}`);
  await upgrades.upgradeProxy(ADDRESS, newBox);
  console.log("Box upgraded");
}

upgrade()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
