import { ethers } from "hardhat";
import { expect } from "chai";
import deployContract from "../scripts/utils/deploy";
import {
  toStringMap,
  whatPrecision,
  calculateRatio,
} from "../scripts/utils/math";

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
        toStringMap([ethers.utils.parseEther("3"), ethers.utils.parseEther("2")]),
        toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("4")]),
        toStringMap([ethers.utils.parseEther("500"), ethers.utils.parseEther("200")]),
        toStringMap([ethers.utils.parseEther("50"), ethers.utils.parseEther("10")]),
      ],
      `${0}`
    );
    expect(amm[1].toString()).to.not.equal("0");
  });

  it("Arbitrage fails when only one AMM supplied", async function () {
    let amountOfXToSend = ethers.utils.parseEther("0.0031");
    var throwsError = false;
    try {
      await this.arbitrage.arbitrageWrapper(
        toStringMap([ethers.utils.parseEther("3"), ethers.utils.parseEther("2")]),
        `${amountOfXToSend}`
      );
    } catch (error) {
      throwsError = true;
    }
    expect(throwsError).to.equal(true);
  });

  it("Arbitrage runs when exactly two AMMs supplied (edge case)", async function () {
    let amountOfXToSend = ethers.utils.parseEther("0.0031");
    var throwsError = false;
    try {
      await this.arbitrage.arbitrageWrapper(
        [
          toStringMap([ethers.utils.parseEther("3"), ethers.utils.parseEther("2")]),
          toStringMap([ethers.utils.parseEther("5"), ethers.utils.parseEther("2")]),
        ],
        `${amountOfXToSend}`
      );
    } catch (error) {
      throwsError = true;
    }
    expect(throwsError).to.equal(false);
  });

  it("No arbitrage opportunity - nothing sent anywhere, and no flash loan", async function () {
    let amountOfXToSend = ethers.utils.parseEther("0.0031");
    let ammsArr = [
      toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("3")]),
      toStringMap([ethers.utils.parseEther("0.2"), ethers.utils.parseEther("0.3")]),
      toStringMap([ethers.utils.parseEther("4"), ethers.utils.parseEther("6")]),
      toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("3")]),
    ];
    const amm = await this.arbitrage.arbitrageWrapper(
      ammsArr,
      `${amountOfXToSend}`
    );

    for (let i = 0; i < ammsArr.length; i++) {
      expect(amm[0][i].x.toString()).to.equal("0");
      expect(amm[0][i].y.toString()).to.equal("0");
    }
    expect(amm[1].toString()).to.equal("0");
  });

  it("Holding lots of Y means no flash loan required:", async function () {
    let amountOfXToSend = ethers.utils.parseEther("100");
    const amm = await this.arbitrage.arbitrageWrapper(
      [
        toStringMap([ethers.utils.parseEther("3"), ethers.utils.parseEther("2")]),
        toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("4")]),
        toStringMap([ethers.utils.parseEther("0.5"), ethers.utils.parseEther("0.2")]),
      ],
      `${amountOfXToSend}`
    );
    expect(amm[1].toString()).to.equal("0");
  });

  it("Ratios Y/X about equal after arbitrage done", async function () {
    let amountOfXToSend = ethers.utils.parseEther("0.31");
    let ammsArr = [
      toStringMap([ethers.utils.parseEther("3"), ethers.utils.parseEther("2")]),
      toStringMap([ethers.utils.parseEther("0.5"), ethers.utils.parseEther("0.2")]),
      toStringMap([ethers.utils.parseEther("5"), ethers.utils.parseEther("2")]),
      toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("4")]),
    ];

    const amm = await this.arbitrage.arbitrageWrapper(
      ammsArr,
      `${amountOfXToSend}`
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
    let amountOfYHeld = BigInt(ethers.utils.parseEther("0.000000031").toString());
    let ammsArr = [
      toStringMap([ethers.utils.parseEther("3"), ethers.utils.parseEther("2")]),
      toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("4")]),
      toStringMap([ethers.utils.parseEther("5"), ethers.utils.parseEther("2")]),
      toStringMap([ethers.utils.parseEther("0.5"), ethers.utils.parseEther("0.2")]),
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
