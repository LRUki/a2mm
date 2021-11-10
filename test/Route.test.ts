import { ethers } from "hardhat";
import { expect } from "chai";
import deployContract from "../scripts/utils/deploy";
describe("==================================== Route ====================================", function () {
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
    const tenToTheNine = Math.pow(10, 9);
    const amm = await this.route.route(
      [
        [2000 * tenToTheNine, 4000 * tenToTheNine],
        // [1600 * tenToTheNine, 2000 * tenToTheNine],
        // [1000 * tenToTheNine, 2000 * tenToTheNine],
      ],
      3 * tenToTheNine
    );
    console.log(amm.toString(), "ROUTE");
  });
});
