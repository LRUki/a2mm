import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "@ethersproject/bignumber";
import { toStringMap, quantityOfYForX } from "../scripts/utils/math";
import assert from "assert";

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

  it("quantityOfYForX gives correct output", async function () {
    const quantityOfYForXSmartContract = async (
      x: bigint,
      y: bigint,
      dx: bigint
    ) =>
      this.sharedFunctions.functions[
        "quantityOfYForX(uint256,uint256,uint256)"
      ](x, y, dx);
    const res = await quantityOfYForXSmartContract(
      BigInt(ethers.utils.parseEther("100").toString()),
      BigInt(ethers.utils.parseEther("200").toString()),
      BigInt(200)
    );
    const exp = quantityOfYForX(
      BigInt(ethers.utils.parseEther("100").toString()),
      BigInt(ethers.utils.parseEther("200").toString()),
      BigInt(200)
    );
    expect(res.toString()).to.equal(exp.toString());
  });

  it("quantityOfYForX throws error if dx<=0 ", async function () {
    var throwsError = false;
    const quantityOfYForXSmartContract = async (
      x: bigint,
      y: bigint,
      dx: bigint
    ) =>
      this.sharedFunctions.functions[
        "quantityOfYForX(uint256,uint256,uint256)"
      ](x, y, dx);
    try {
      await quantityOfYForXSmartContract(
        BigInt(ethers.utils.parseEther("100").toString()),
        BigInt(ethers.utils.parseEther("200").toString()),
        BigInt(-200)
      );
    } catch (error) {
      throwsError = true;
    }
    expect(throwsError).to.equal(true);
  });

  it("quantityOfYForX throws error if y<=0 ", async function () {
    var throwsError = false;
    const quantityOfYForXSmartContract = async (
      x: bigint,
      y: bigint,
      dx: bigint
    ) =>
      this.sharedFunctions.functions[
        "quantityOfYForX(uint256,uint256,uint256)"
      ](x, y, dx);
    try {
      const res = await quantityOfYForXSmartContract(
        BigInt(ethers.utils.parseEther("100").toString()),
        BigInt(ethers.utils.parseEther("-200").toString()),
        BigInt(200)
      );
    } catch (error) {
      throwsError = true;
    }
    expect(throwsError).to.equal(true);
  });

  it("sortAmmArrayIndicesByExchangeRate gives correct output", async function () {
    let testExamples = [
      {
        ammsArray: [
          toStringMap([ethers.utils.parseEther("1"), ethers.utils.parseEther("2")]),
          toStringMap([ethers.utils.parseEther("1"), ethers.utils.parseEther("4")]),
          toStringMap([ethers.utils.parseEther("0.2"), ethers.utils.parseEther("0.2")]),
        ],
        result: [2, 0, 1],
      },
      {
        ammsArray: [
          toStringMap([ethers.utils.parseEther("1"), ethers.utils.parseEther("2")]),
          toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("4")]),
          toStringMap([ethers.utils.parseEther("0.2"), ethers.utils.parseEther("0.4")]),
        ],
        result: [0, 1, 2],
      },
    ];
    for (const element of testExamples) {
      const res =
        await this.sharedFunctions.sortAmmArrayIndicesByExchangeRateWrapper(
          element.ammsArray
        );
      expect(res.toString()).to.equal(element.result.toString());
    }
  });

  it("howMuchXToSpendToLevelAmms gives correct output", async function () {
    const res = await this.sharedFunctions.howMuchXToSpendToLevelAmmsWrapper(
      toStringMap([ethers.utils.parseEther("100"), ethers.utils.parseEther("200")]),
      toStringMap([ethers.utils.parseEther("100"), ethers.utils.parseEther("180")])
    );

    const exp = howMuchToSpendToLevelAmms(
      Number(ethers.utils.parseEther("100")),
      Number(ethers.utils.parseEther("200")),
      Number(ethers.utils.parseEther("100")),
      Number(ethers.utils.parseEther("180"))
    );

    expect(Math.round((res - exp) / 100000).toString()).to.equal(
      (0).toString()
    );
  });

  it("howMuchXToSpendToLevelAmms throws error if t12 <=0 || t22 <= 0", async function () {
    var throwsError = false;
    try {
      const res = await this.sharedFunctions.howMuchXToSpendToLevelAmmsWrapper(
        toStringMap([ethers.utils.parseEther("-100"), ethers.utils.parseEther("200")]),
        toStringMap([ethers.utils.parseEther("100"), ethers.utils.parseEther("180")])
      );
    } catch (error) {
      throwsError = true;
    }
    expect(throwsError).to.equal(true);
  });

  it("leveledAmms get split correctly", async function () {
    const res =
      await this.sharedFunctions.howToSplitRoutingOnLeveledAmmsWrapper(
        [
          toStringMap([ethers.utils.parseEther("1"), ethers.utils.parseEther("2")]),
          toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("4")]),
          toStringMap([ethers.utils.parseEther("0.1"), ethers.utils.parseEther("0.2")]),
        ],
        `${ethers.utils.parseEther("0.000031")}`
      );
    const [p1, p2, p3]: number[] = res.map((v: BigNumber) => v.toNumber());
    expect(p2 / p1).to.equal(2);
    expect(p1 / p3).to.equal(10);
  });
});

const howMuchToSpendToLevelAmms = (
  t11: number,
  t12: number,
  t21: number,
  t22: number
): number => {
  assert(t12 > 0 && t22 > 0);
  let left =
    Math.sqrt(t11 * t22) *
    Math.sqrt((t11 * t22 * 2257) / 1_000_000_000 + t12 * t21);
  let right = t11 * t22;
  if (right >= left) {
    //We can't level these any more than they are
    return 0;
  }
  return (1002 * (left - right)) / (1000 * t22);
};
