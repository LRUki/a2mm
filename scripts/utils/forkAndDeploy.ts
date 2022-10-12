import { network, ethers } from "hardhat";
import deployContract from "./deploy";
import { Libraries } from "hardhat/types";
import { Contract } from "@ethersproject/contracts";
import { factoryToAddress } from "./factory";
//forks at given blocknumber, deploy the swap contract
//and returns the contract instance
export default async (blockNumber: number): Promise<Contract> => {
  // Fork archive
  await network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl:
            "https://speedy-nodes-nyc.moralis.io/0786eddbee701c23817a1112/eth/mainnet/archive",
          blockNumber: blockNumber,
        },
      },
    ],
  });

  const SharedFunctionslibraryAddress: string = await deployContract(
    "SharedFunctions"
  );
  const Arbitrage: string = await deployContract("Arbitrage", {
    ["SharedFunctions"]: SharedFunctionslibraryAddress,
  });
  const RoutelibraryAddress: string = await deployContract("Route", {
    ["SharedFunctions"]: SharedFunctionslibraryAddress,
  });

  const libraries: Libraries = {
    ["Arbitrage"]: Arbitrage,
    ["Route"]: RoutelibraryAddress,
    ["SharedFunctions"]: SharedFunctionslibraryAddress,
  };
  const address = await deployContract(
    "Swap",
    libraries,
    Object.values(factoryToAddress)
  );
  return await ethers.getContractAt("Swap", address);
};
