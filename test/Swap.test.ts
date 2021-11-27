import { ethers } from "hardhat";
import { expect, assert } from "chai";
import { Token, tokenToAddress } from "../scripts/utils/Token";
import {
  getBalanceOfERC20,
  topUpWETHAndApproveContractToUse,
} from "../scripts/utils/ERC20";

import {
  calculateRatio,
  TEN_TO_18,
  TEN_TO_9,
  toStringMap,
  whatPrecision,
  quantityOfYForX,
} from "../scripts/utils/math";
import forkAndDeploy from "../scripts/utils/forkAndDeploy";

import deployContract from "../scripts/utils/deploy";
import { BigNumber } from "@ethersproject/bignumber";
import { Factory, factoryToAddress } from "../scripts/utils/Factory";
import { Console } from "console";

describe("==================================== Swap Helpers ====================================", function () {
  before(async function () {
    const sharedFunctionsAddress = await deployContract("SharedFunctions");

    this.Arbitrage = await ethers.getContractFactory("Arbitrage", {
      libraries: { SharedFunctions: sharedFunctionsAddress },
    });
    this.arbitrage = await this.Arbitrage.deploy();
    await this.arbitrage.deployed();

    this.Route = await ethers.getContractFactory("Route", {
      libraries: { SharedFunctions: sharedFunctionsAddress },
    });
    this.route = await this.Route.deploy();
    await this.route.deployed();

    this.Swap = await ethers.getContractFactory("Swap", {
      libraries: {
        Arbitrage: this.arbitrage.address,
        Route: this.route.address,
        SharedFunctions: sharedFunctionsAddress,
      },
    });
  });

  beforeEach(async function () {
    this.swap = await this.Swap.deploy();
    await this.swap.deployed();
  });

  it("contract recieves funds", async function () {
    const [signer] = await ethers.getSigners();
    const ethAmount = "1";
    const signerAddress = await signer.getAddress();
    await signer.sendTransaction({
      from: signerAddress,
      to: this.swap.address,
      value: ethers.utils.parseEther(ethAmount),
    });
    const contractBalance = await signer.provider?.getBalance(
      this.swap.address
    );
    expect(contractBalance).to.equal(ethers.utils.parseEther(ethAmount));
  });

  it("swaps on differnt route", async function () {
    const [signer] = await ethers.getSigners();
    const ethAmout = ethers.utils.parseEther("1");
    const tokenIn = tokenToAddress[Token.WETH];
    const tokenOut = tokenToAddress[Token.UNI];

    //here we need to first convert native ETH to ERC20 WETH and approve the contract to use
    await topUpWETHAndApproveContractToUse(signer, ethAmout, this.swap.address);
    const tx = await this.swap.swap(tokenIn, tokenOut, ethAmout.toString());
    const txStatus = await tx.wait();
    const swapEvent = txStatus.events.filter(
      (e: { event: string; args: string[] }) => e.event == "SwapEvent"
    );
    expect(swapEvent).to.have.lengthOf(1);
    const { amountOut } = swapEvent[0].args;
    const amountRecieved = await getBalanceOfERC20(signer.address, tokenOut);
    console.log(amountRecieved.toString(), amountOut.toString(), "AHHHH");
    // expect(amountRecieved.eq(amountOut)).to.be.true;
  });

  it("When only one AMM is supplied, everything is sent to that AMM", async function () {
    let amountOfXToSend = 0.4 * TEN_TO_18;
    const amm = await this.swap.calculateRouteAndArbitargeWrapper(
      [toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18])],
      `${amountOfXToSend}`
    );
    expect(amm[2]).to.equal(0);
    expect(amm[0][0]).to.equal(BigInt(amountOfXToSend));
    expect(amm[1][0].x).to.equal(0);
    expect(amm[1][0].y).to.equal(0);
  });

  it("No arbitrage opportunity - no flash loan required", async function () {
    let ammsArr = [
      toStringMap([2 * TEN_TO_18, 3 * TEN_TO_18]),
      toStringMap([0.2 * TEN_TO_18, 0.3 * TEN_TO_18]),
      toStringMap([4 * TEN_TO_18, 6 * TEN_TO_18]),
      toStringMap([2 * TEN_TO_18, 3 * TEN_TO_18]),
    ];
    const amm = await this.swap.calculateRouteAndArbitargeWrapper(
      ammsArr,
      `${0.0031 * TEN_TO_18}`
    );

    expect(amm[2].toString()).to.equal("0");
  });

  it("Swapping lots of X means no flash loan required:", async function () {
    const amm = await this.swap.calculateRouteAndArbitargeWrapper(
      [
        toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
        toStringMap([2 * TEN_TO_18, 5 * TEN_TO_18]),
        toStringMap([0.5 * TEN_TO_18, 0.2 * TEN_TO_18]),
      ],
      `${100 * TEN_TO_18}`
    );
    expect(amm[2].toString()).to.equal("0");
  });

  it("Swapping with no AMMs causes error", async function () {
    var throwsError = false;
    try {
      await this.swap.calculateRouteAndArbitargeWrapper(
        [],
        `${0.4 * TEN_TO_18}`
      );
    } catch (error) {
      throwsError = true;
    }
    expect(throwsError).to.equal(true);
  });

  it("Ratios Y/X about equal after swapping done", async function () {
    let ammsArr = [
      toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
      toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
      toStringMap([5 * TEN_TO_18, 2 * TEN_TO_18]),
      toStringMap([0.5 * TEN_TO_18, 0.2 * TEN_TO_18]),
    ];

    const amm = await this.swap.calculateRouteAndArbitargeWrapper(
      ammsArr,
      `${0.0031 * TEN_TO_18}`
    );

    let firstRatio = await calculateRatio(
      Number(ammsArr[0][0]),
      Number(ammsArr[0][1]),
      Number(BigInt(amm[0][0]) + BigInt(amm[1][0].x)),
      Number(amm[1][0].y)
    );
    for (let i = 1; i < ammsArr.length; i++) {
      let ratio = await calculateRatio(
        Number(ammsArr[i][0]),
        Number(ammsArr[i][1]),
        Number(BigInt(amm[0][i]) + BigInt(amm[1][i].x)),
        Number(amm[1][i].y)
      );
      expect(Math.abs(ratio - firstRatio)).to.lessThan(
        Math.pow(10, whatPrecision(firstRatio, 2))
      );
    }
  });

  it("Flash loan is required when we hold insufficient Y after routing", async function () {
    const amm = await this.swap.calculateRouteAndArbitargeWrapper(
      [
        toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
        toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
        toStringMap([5 * TEN_TO_18, 200 * TEN_TO_18]),
        toStringMap([50 * TEN_TO_18, 10 * TEN_TO_18]),
      ],
      `${2 * TEN_TO_9}`
    );
    expect(amm[2].toString()).to.not.equal("0");
  });
});

describe("==================================== Swap ====================================", async () => {
  before(async function () {
    this.SharedFunctions = await ethers.getContractFactory("SharedFunctions");
  });
  beforeEach(async function () {
    this.sharedFunctions = await this.SharedFunctions.deploy();
    await this.sharedFunctions.deployed();
  });

  var swapTestCases: [number, string[], BigNumber, BigNumber][] = [];

  for (let i = 0; i < 10; i++) {
    let elem: [number, string[], BigNumber, BigNumber] = [
      Number(13679900 + 100 * i),
      [tokenToAddress[Token.WETH], tokenToAddress[Token.UNI]],
      ethers.utils.parseEther("0.05"),
      ethers.utils.parseEther("0.1"),
    ];
    swapTestCases.push(elem);
  }

  swapTestCases.forEach((swapTestCase, i) => {
    const [blockNumber, [tokenIn, tokenOut], inputAmount, expectedOutput] =
      swapTestCase;
    it(`Test${i}: swapping ${inputAmount} of [${tokenIn}, ${tokenOut}] at block ${blockNumber}`, async function () {
      const swapContract = await forkAndDeploy(blockNumber);
      const [signer] = await ethers.getSigners();

      ////////////////UNIV2
      let [reserveInUNIV2, reserveOutUNIV2] = await swapContract.getReserves(
        factoryToAddress[Factory.UNIV2],
        tokenIn,
        tokenOut
      );
      console.log(`reserves of ${tokenIn}, ${tokenOut} at UNIV2 are`, [
        reserveInUNIV2.toString(),
        reserveOutUNIV2.toString(),
      ]);

      ////////////////SHIBA
      let [reserveInSHIBA, reserveOutSHIBA] = await swapContract.getReserves(
        factoryToAddress[Factory.SHIBA],
        tokenIn,
        tokenOut
      );
      console.log(`reserves of ${tokenIn}, ${tokenOut} at SHIBA are`, [
        reserveInSHIBA.toString(),
        reserveOutSHIBA.toString(),
      ]);

      ////////////////SUSHI
      let [reserveInSUSHI, reserveOutSUSHI] = await swapContract.getReserves(
        factoryToAddress[Factory.SUSHI],
        tokenIn,
        tokenOut
      );
      console.log(`reserves of ${tokenIn}, ${tokenOut} at SUSHI are`, [
        reserveInSUSHI.toString(),
        reserveOutSUSHI.toString(),
      ]);

      //test

      //here we need to first convert native ETH to ERC20 WETH and approve the contract to use
      //assuming that tokenIn is WETH
      await topUpWETHAndApproveContractToUse(
        signer,
        inputAmount,
        swapContract.address
      );

      //call the swap
      swapContract.swap(tokenIn, tokenOut, inputAmount);
      console.log("--------Input --------");
      console.log(inputAmount.toString());
      //check the balanceOf the user etc
      // console.log("--------Balance--------")
      // let balance_res = await getBalanceOfERC20(signer.address, tokenOut)
      // console.log(balance_res)
      // console.log("--------QuantityOfYForX--------")
      // const quantityOfYForXSmartContract = async (
      //   x: bigint,
      //   y: bigint,
      //   dx: bigint
      // ) =>
      //   this.sharedFunctions.functions[
      //     "quantityOfYForX(uint256,uint256,uint256)"
      //   ](x, y, dx);

      // const quantityOfYForX_res = await quantityOfYForXSmartContract(
      //   BigInt(reserveInSUSHI),
      //   BigInt(reserveOutSUSHI),
      //   BigInt(100)
      // );
      // console.log(quantityOfYForX_res)
    });
  });
});

function sleep(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time));
}
