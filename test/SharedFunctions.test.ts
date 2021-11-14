import { ethers } from "hardhat";
import { expect } from "chai";
describe("==================================== SharedFunctions ====================================", function () {
  before(async function () {
    this.SharedFunctions = await ethers.getContractFactory("SharedFunctions");
  });
  beforeEach(async function () {
    this.sharedFunctions = await this.SharedFunctions.deploy();
    await this.sharedFunctions.deployed();
  });

  it("sqrt gives correct output", async function () {
    let num = 3000000;
    let res = await this.sharedFunctions.sqrt(num);
    expect(res.toString()).to.equal(Math.floor(Math.sqrt(num)).toString());
    num = 0;
    res = await this.sharedFunctions.sqrt(num);
    expect(res.toString()).to.equal(Math.floor(Math.sqrt(num)).toString());
  });
});
