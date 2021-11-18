import { ethers } from "hardhat";
import { expect } from "chai";
import deployContract from "../scripts/utils/deploy";
import {TEN_TO_18, toStringMap, whatPrecision, calculateRatio} from "./HelperFunctions";

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

  it("Flash loan is required when we hold no Y", async function () {
    const amm = await this.arbitrage.arbitrageWrapper(
      [
        toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
        toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
        toStringMap([500 * TEN_TO_18, 200 * TEN_TO_18]),
        toStringMap([50 * TEN_TO_18, 10 * TEN_TO_18]),
      ],
      `${0}`
    );
    expect(amm[1].toString()).to.not.equal("0");
  });

  it("Arbitrage fails when only one AMM supplied", async function () {
    var throwsError = false;
    try {
      await this.arbitrage.arbitrageWrapper(
        [toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18])],
        `${0.0031 * TEN_TO_18}`
      );
    }
    catch(error){
      throwsError = true;
    }
    expect(throwsError).to.equal(true)
  });

  it("Arbitrage runs when exactly two AMMs supplied (edge case)", async function () {
    await this.arbitrage.arbitrageWrapper(
      [
        toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
        toStringMap([5 * TEN_TO_18, 2 * TEN_TO_18]),
      ],
      `${0.0031 * TEN_TO_18}`
    );
  });

  it("No arbitrage opportunity - nothing sent anywhere, and no flash loan", async function () {
    let ammsArr = [
      toStringMap([2 * TEN_TO_18, 3 * TEN_TO_18]),
      toStringMap([0.2 * TEN_TO_18, 0.3 * TEN_TO_18]),
      toStringMap([4 * TEN_TO_18, 6 * TEN_TO_18]),
      toStringMap([2 * TEN_TO_18, 3 * TEN_TO_18]),
    ];
    const amm = await this.arbitrage.arbitrageWrapper(
      ammsArr,
      `${0.0031 * TEN_TO_18}`
    );

    for (let i = 0; i < ammsArr.length; i++) {
      expect(amm[0][i].x.toString()).to.equal("0");
      expect(amm[0][i].y.toString()).to.equal("0");
    }
    expect(amm[1].toString()).to.equal("0");
  });

  it("Holding lots of Y means no flash loan required:", async function () {
    const amm = await this.arbitrage.arbitrageWrapper(
      [
        toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
        toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
        toStringMap([0.5 * TEN_TO_18, 0.2 * TEN_TO_18]),
      ],
      `${100 * TEN_TO_18}`
    );
    expect(amm[1].toString()).to.equal("0");
  });

  it("Ratios Y/X about equal after arbitrage done", async function () {
    let ammsArr = [
      toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
      toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
      toStringMap([5 * TEN_TO_18, 2 * TEN_TO_18]),
      toStringMap([0.5 * TEN_TO_18, 0.2 * TEN_TO_18]),
    ];

    const amm = await this.arbitrage.arbitrageWrapper(
      ammsArr,
      `${0.31 * TEN_TO_18}`
    );

    let firstRatio = await calculateRatio(
      Number(ammsArr[0][0]),
      Number(ammsArr[0][1]),
      Number(amm[0][0].x),
      Number(amm[0][0].y)
    );
    for (let i = 1; i < ammsArr.length; i++) {
      expect(
        Math.abs(
          (await calculateRatio(
            Number(ammsArr[i][0]),
            Number(ammsArr[i][1]),
            Number(amm[0][i].x),
            Number(amm[0][i].y)
          )) - firstRatio
        )
      ).to.lessThan(Math.pow(10, whatPrecision(firstRatio, 2)));
    }
  });

  it("amounts of Y sent to AMMs = amount of Y held + Flash loan", async function () {
    let amountOfYHeld = BigInt(0.000000031 * TEN_TO_18);
    let ammsArr = [
      toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
      toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
      toStringMap([5 * TEN_TO_18, 2 * TEN_TO_18]),
      toStringMap([0.5 * TEN_TO_18, 0.2 * TEN_TO_18]),
    ];
    const amm = await this.arbitrage.arbitrageWrapper(
      ammsArr,
      `${amountOfYHeld}`
    );

    let ySum = BigInt(0);
    for (let i = 0; i < ammsArr.length; i++) {
      ySum += BigInt(amm[0][i].y.toString());
    }

    expect(BigInt(amm[1]) + amountOfYHeld).to.equal(ySum);
  });
});

export default whatPrecision;