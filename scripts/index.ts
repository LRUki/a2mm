// this file shows how to interact with smart contract programatically
import { ethers } from "hardhat";
async function main() {
  // Retrieve accounts from the local node
  const accounts = await ethers.provider.listAccounts();
  // Set up an ethers contract, representing our deployed Box instance
  console.log(accounts);
  const address = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
  const Box = await ethers.getContractFactory("Box");
  const box = await Box.attach(address);
  // Call the retrieve() function of the deployed Box contract
  let value = await box.retrieve();
  console.log("Box value is", value.toString());
  // Send a transaction to store() a new value in the Box
  await box.store(23);
  value = await box.retrieve();
  console.log("Box value is", value.toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
