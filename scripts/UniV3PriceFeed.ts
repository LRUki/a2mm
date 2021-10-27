// this file shows how to interact with smart contract programatically
import { ethers } from "hardhat";

async function main() {
  const address = "0xD8a5a9b31c3C0232E196d518E89Fd8bF83AcAd43";
  const Contract = await ethers.getContractFactory("UniV3PriceFeed", {
    libraries: {
      TokenAddrs: "0xD8a5a9b31c3C0232E196d518E89Fd8bF83AcAd43",
    },
  });
  const contract = await Contract.attach(address);
  let value = await contract.getAddres(0);
  console.log("Address is", value.toString());
  value = await contract.getAddres(1);
  console.log("Address is", value.toString());
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
