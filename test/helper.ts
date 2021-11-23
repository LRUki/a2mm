// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { network, ethers } from "hardhat";
import deployContract from "../scripts/utils/deploy";
import { Libraries } from "hardhat/types";

export const FEG_ADDRESS = "0x389999216860ab8e0175387a0c90e5c52522c945";
export const SUSHISWAP_ROUTER02_ADDRESS = "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F";
export const UNISWAP_ROUTER02_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
export const USDC_ADDRESS = "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d ";
export const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

export async function forkArchive(blockNumber: Number) {

  // Fork archive
  await network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl: "https://speedy-nodes-nyc.moralis.io/0786eddbee701c23817a1112/eth/mainnet/archive",
          blockNumber: blockNumber,
        },
      },
    ],
  });

  const SharedFunctionslibraryAddress: string = await deployContract("SharedFunctions");
  const Arbitrage: string = await deployContract("Arbitrage", {
      ["SharedFunctions"]: SharedFunctionslibraryAddress, 
  });
  const RoutelibraryAddress: string = await deployContract("Route", {
    ["SharedFunctions"]: SharedFunctionslibraryAddress, 
  });

  const libraries: Libraries = { ["Arbitrage"]: Arbitrage, 
                                ["Route"]: RoutelibraryAddress, 
                                ["SharedFunctions"]: SharedFunctionslibraryAddress, 
                              };

  // Deploy contracts
  const accounts = await ethers.getSigners();
  const deployer = accounts[0];
  const Swap = await ethers.getContractFactory("Swap", {libraries});
  const swap = await Swap.deploy();
  console.log("Swap deployed to:", swap.address);
  console.log("Deployer:", deployer.address)
}

// main()
//   .then(() => process.exit(0))
//   .catch(error => {
//     console.error(error);
//     process.exit(1);
//   });