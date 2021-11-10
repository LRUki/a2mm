import { ethers } from "hardhat";
import { expect } from "chai";
import deployContract from "../scripts/utils/deploy";
describe("Route", function () {
  before(async function () {
    const sharedFunctionAddress = await deployContract("SharedFunctions");
    this.Route = await ethers.getContractFactory("Route", {
      libraries: { SharedFunctions: sharedFunctionAddress },
    });
  });
  beforeEach(async function () {
    this.route = await this.Route.deploy();
    await this.route.deployed();
  });

  it("Route runs", async function () {
    const amm = await this.route.route([[2000, 50000], [2000, 50000], [2000, 50000]], 3000);
    console.log(amm.toString(), "ROUTE");
  });
});
