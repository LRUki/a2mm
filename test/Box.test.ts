// test/Box.test.js
// Load dependencies
import { expect } from "chai";
import { ethers } from "hardhat";
// Start test block
describe("Box", function () {
  before(async function () {
    this.Box = await ethers.getContractFactory("Box");
  });

  beforeEach(async function () {
    this.box = await this.Box.deploy();
    await this.box.deployed();
  });

  // Test case
  it("retrieve returns a value previously stored", async function () {
    // Store a value
    await this.box.store(42);

    const s = await this.box.retrieve();
    expect((await this.box.retrieve()).toString()).to.equal("42");
  });
});
