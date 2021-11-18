import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "@ethersproject/bignumber";
import deployContract from "../scripts/utils/deploy";
import {TEN_TO_18, toStringMap, quantityOfYForX} from "./HelperFunctions";

describe("==================================== SharedFunctions ====================================", function () {
  before(async function () {
    this.SharedFunctions = await ethers.getContractFactory("SharedFunctions");
  });
  beforeEach(async function () {
    this.sharedFunctions = await this.SharedFunctions.deploy();
    await this.sharedFunctions.deployed();
  });

  async function quantityOfYForX(x: bigint, y: bigint, dx: bigint) {
    //TODO: Is there a better way to do it?

    await deployContract("SharedFunctions");
    const SharedFunctions = await ethers.getContractFactory("SharedFunctions");
    const sharedFunctions = await SharedFunctions.deploy();

    return await sharedFunctions.functions[
      "quantityOfYForX(uint256,uint256,uint256)"
    ](x, y, dx);
  }

  async function quantityOfXForY(x: bigint, y: bigint, dy: bigint) {
    return await quantityOfYForX(y, x, dy);
  }

  it("sqrt gives correct output", async function () {
    let num = 3000000;
    let res = await this.sharedFunctions.sqrt(num);
    expect(res.toString()).to.equal(Math.floor(Math.sqrt(num)).toString());
    num = 0;
    res = await this.sharedFunctions.sqrt(num);
    expect(res.toString()).to.equal(Math.floor(Math.sqrt(num)).toString());
  });

  it("quantityOfYForX gives correct output", async function () {
    const res = await quantityOfYForX(
      BigInt(100 * TEN_TO_18),
      BigInt(200 * TEN_TO_18),
      BigInt(200),
    );
    const exp = await quantityOfYForX(
      BigInt(100 * TEN_TO_18),
      BigInt(200 * TEN_TO_18),
      BigInt(200)
    );
    expect(Number(res)).to.equal(Number(exp));
  });

  it("quantityOfYForX throws error if dx<=0 ", async function () {
    var throwsError = false;
    try {
      const res = await quantityOfYForX(
        BigInt(100 * TEN_TO_18),
        BigInt(200 * TEN_TO_18),
        BigInt(-200),
      );
    }
    catch(error){
      throwsError = true;
    }
    expect(throwsError).to.equal(true);
  });

  it("quantityOfYForX throws error if y<=0 ", async function () {
    var throwsError = false;
    try {
      const res = await quantityOfYForX(
        BigInt(100 * TEN_TO_18),
        BigInt(-200 * TEN_TO_18),
        BigInt(200),
      );
    }
    catch(error){
      throwsError = true;
    }
    expect(throwsError).to.equal(true);
  });

  it("sortAmmArrayIndicesByExchangeRate gives correct output", async function () {
    let testExamples =
      [
        {
          ammsArray: [
            toStringMap([1 * TEN_TO_18, 2 * TEN_TO_18]),
            toStringMap([1 * TEN_TO_18, 4 * TEN_TO_18]),
            toStringMap([0.2 * TEN_TO_18, 0.2 * TEN_TO_18]),
          ],
          result: [2, 0, 1]
        },
        {
          ammsArray: [
            toStringMap([1 * TEN_TO_18, 2 * TEN_TO_18]),
            toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
            toStringMap([0.2 * TEN_TO_18, 0.4 * TEN_TO_18]),
          ],
          result: [0, 1, 2]
        },
      ]
    for (const element of testExamples) {
      const res = await this.sharedFunctions.sortAmmArrayIndicesByExchangeRateWrapper(element.ammsArray)
      expect(res.toString()).to.equal((element.result).toString());
    }
  });


  it("howMuchXToSpendToLevelAmms gives correct output", async function () {
    const res = await this.sharedFunctions.howMuchXToSpendToLevelAmmsWrapper(
      toStringMap([100 * TEN_TO_18, 200 * TEN_TO_18]),
      toStringMap([100 * TEN_TO_18, 180 * TEN_TO_18])
    );

    const exp = howMuchToSpendToLevelAmms(100 * TEN_TO_18,200 * TEN_TO_18,100 * TEN_TO_18, 180 * TEN_TO_18)

    expect(Math.round((res-exp)/100000).toString()).to.equal((0).toString());
  });

  it("howMuchXToSpendToLevelAmms throws error if t12 <=0 || t22 <= 0", async function () {
    var throwsError = false;
    try {
      const res = await this.sharedFunctions.howMuchXToSpendToLevelAmmsWrapper(
        toStringMap([-100 * TEN_TO_18, 200 * TEN_TO_18]),
        toStringMap([100 * TEN_TO_18, 180 * TEN_TO_18])
      );
    }
    catch(error){
      throwsError = true;
    }
    expect(throwsError).to.equal(true);
  });

  it("leveledAmms get split correctly", async function () {
    const res = await this.sharedFunctions.howToSplitRoutingOnLeveledAmmsWrapper(
      [
        toStringMap([1 * TEN_TO_18, 2 * TEN_TO_18]),
        toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
        toStringMap([0.1 * TEN_TO_18, 0.2 * TEN_TO_18]),
      ],
      `${0.000031 * TEN_TO_18}`
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
  expect(t12 > 0 && t22 > 0)
  let left = Math.sqrt(t11 * t22) * Math.sqrt((t11 * t22 * 2257) / 1_000_000_000 + t12 * t21);
  let right = t11 * t22;
  if (right >= left) {
    //We can't level these any more than they are
    return 0;
  }
  return (1002 * (left - right)) / (1000 * t22);
};
