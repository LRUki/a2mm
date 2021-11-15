import { ethers } from "hardhat";
import deployContract from "../scripts/utils/deploy";

describe("==================================== Arbitrage ====================================", function () {
  before(async function () {
    const sharedFunctionAddress = await deployContract("SharedFunctions");
    this.Arbitrage = await ethers.getContractFactory("Arbitrage", {
      libraries: { SharedFunctions: sharedFunctionAddress },
    });
  });
  beforeEach(async function () {
    this.arbitrage = await this.Arbitrage.deploy();
    await this.arbitrage.deployed();
  });
});
