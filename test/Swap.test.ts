import { ethers } from "hardhat";
import { expect } from "chai";
import { Token, tokenToAddress } from "../scripts/utils/Token";
import {
  getBalanceOfERC20,
  topUpWETHAndApproveContractToUse,
} from "../scripts/utils/ERC20";

import {
  calculateRatio,
  toStringMap,
  whatPrecision,
  quantityOfYForX,
} from "../scripts/utils/math";
import forkAndDeploy from "../scripts/utils/forkAndDeploy";

import deployContract from "../scripts/utils/deploy";
import { BigNumber } from "@ethersproject/bignumber";
import { Factory, factoryToAddress } from "../scripts/utils/Factory";

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
    const tokenIn = Token.WETH;
    const tokenOut = Token.UNI;

    //here we need to first convert native ETH to ERC20 WETH and approve the contract to use
    await topUpWETHAndApproveContractToUse(signer, ethAmout, this.swap.address);
    const tx = await this.swap.swap(
      tokenToAddress[tokenIn],
      tokenToAddress[tokenOut],
      ethAmout
    );
    const txStatus = await tx.wait();
    const swapEvent = txStatus.events.filter(
      (e: { event: string; args: string[] }) => e.event == "SwapEvent"
    );
    expect(swapEvent).to.have.lengthOf(1);
    const { amountOut } = swapEvent[0].args;
    const amountRecieved = await getBalanceOfERC20(
      signer.address,
      tokenToAddress[tokenOut]
    );
    expect(amountRecieved.eq(amountOut)).to.be.true;
  });

  it("When only one AMM is supplied, everything is sent to that AMM", async function () {
    let amountOfXToSend = ethers.utils.parseEther("0.4");
    const amm = await this.swap.calculateRouteAndArbitrageWrapper(
      [
        toStringMap([
          ethers.utils.parseEther("2"),
          ethers.utils.parseEther("4"),
        ]),
      ],
      `${amountOfXToSend}`
    );
    expect(amm[2]).to.equal(0);
    expect(amm[0][0]).to.equal(BigInt(amountOfXToSend.toString()));
    expect(amm[1][0].x).to.equal(0);
    expect(amm[1][0].y).to.equal(0);
  });

  it("No arbitrage opportunity - no flash loan required", async function () {
    let amountOfXToSend = ethers.utils.parseEther("0.0031");
    let ammsArr = [
      toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("3")]),
      toStringMap([
        ethers.utils.parseEther("0.2"),
        ethers.utils.parseEther("0.3"),
      ]),
      toStringMap([ethers.utils.parseEther("4"), ethers.utils.parseEther("6")]),
      toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("3")]),
    ];
    const amm = await this.swap.calculateRouteAndArbitrageWrapper(
      ammsArr,
      `${amountOfXToSend}`
    );

    expect(amm[2].toString()).to.equal("0");
  });

  it("Swapping lots of X means no flash loan required:", async function () {
    let amountOfXToSend = ethers.utils.parseEther("100");
    const amm = await this.swap.calculateRouteAndArbitrageWrapper(
      [
        toStringMap([
          ethers.utils.parseEther("3"),
          ethers.utils.parseEther("2"),
        ]),
        toStringMap([
          ethers.utils.parseEther("2"),
          ethers.utils.parseEther("5"),
        ]),
        toStringMap([
          ethers.utils.parseEther("0.5"),
          ethers.utils.parseEther("0.2"),
        ]),
      ],
      `${amountOfXToSend}`
    );
    expect(amm[2].toString()).to.equal("0");
  });

  it("Swapping with no AMMs causes error", async function () {
    let amountOfXToSend = ethers.utils.parseEther("0.4");
    var throwsError = false;
    try {
      await this.swap.calculateRouteAndArbitrageWrapper(
        [],
        `${amountOfXToSend}`
      );
    } catch (error) {
      throwsError = true;
    }
    expect(throwsError).to.equal(true);
  });

  it("Ratios Y/X about equal after swapping done", async function () {
    let amountOfXToSend = ethers.utils.parseEther("0.0031");
    let ammsArr = [
      toStringMap([ethers.utils.parseEther("3"), ethers.utils.parseEther("2")]),
      toStringMap([ethers.utils.parseEther("2"), ethers.utils.parseEther("4")]),
      toStringMap([ethers.utils.parseEther("5"), ethers.utils.parseEther("2")]),
      toStringMap([
        ethers.utils.parseEther("0.5"),
        ethers.utils.parseEther("0.2"),
      ]),
    ];

    const amm = await this.swap.calculateRouteAndArbitrageWrapper(
      ammsArr,
      `${amountOfXToSend}`
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
    let amountOfXToSend = ethers.utils.parseEther("0.00002");
    const amm = await this.swap.calculateRouteAndArbitrageWrapper(
      [
        toStringMap([
          ethers.utils.parseEther("3"),
          ethers.utils.parseEther("2"),
        ]),
        toStringMap([
          ethers.utils.parseEther("2"),
          ethers.utils.parseEther("4"),
        ]),
        toStringMap([
          ethers.utils.parseEther("5"),
          ethers.utils.parseEther("200"),
        ]),
        toStringMap([
          ethers.utils.parseEther("50"),
          ethers.utils.parseEther("10"),
        ]),
      ],
      `${amountOfXToSend}`
    );
    expect(amm[2].toString()).to.not.equal("0");
  });
});

describe("==================================== Swap ====================================", async () => {
  type SwapTestCaseParam = [number, Token[], BigNumber, BigNumber];
  type FactoryStat = {
    factory: Factory;
    reserveIn: BigNumber;
    reserveOut: BigNumber;
    amountIn: BigNumber;
    amountOut: BigInt;
  };

  const swapTestCases: SwapTestCaseParam[] = [];
  swapTestCases.push([
    Number(13680600),
    [Token.WETH, Token.SHIBA],
    ethers.utils.parseEther("5"),
    ethers.utils.parseEther("0.1"),
  ] as SwapTestCaseParam);

  swapTestCases.push([
    Number(13680700),
    [Token.WETH, Token.SHIBA],
    ethers.utils.parseEther("5"),
    ethers.utils.parseEther("0.1"),
  ] as SwapTestCaseParam);

  for (let i = 0; i < 10; i++) {
    swapTestCases.push([
      Number(13679900 + 100 * i),
      [Token.WETH, Token.UNI],
      ethers.utils.parseEther("5"),
      ethers.utils.parseEther("0.1"),
    ] as SwapTestCaseParam);
  }

  swapTestCases.push([
    Number(13688900),
    [Token.WETH, Token.UNI],
    ethers.utils.parseEther("0.1"),
    ethers.utils.parseEther("0.1"),
  ] as SwapTestCaseParam);

  for (let i = 0; i < 3; i++) {
    swapTestCases.push([
      Number(13679900 + 100 * i),
      [Token.WETH, Token.SHIBA],
      ethers.utils.parseEther("5"),
      ethers.utils.parseEther("0.1"),
    ] as SwapTestCaseParam);
  }

  for (let i = 0; i < 3; i++) {
    swapTestCases.push([
      Number(13679900 + 100 * i),
      [Token.WETH, Token.SHIBA],
      ethers.utils.parseEther("0.0000005"),
      ethers.utils.parseEther("0.1"),
    ] as SwapTestCaseParam);
  }

  for (let i = 0; i < 10; i++) {
    swapTestCases.push([
      Number(13679900 + 100 * i),
      [Token.WETH, Token.UNI],
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.1"),
    ] as SwapTestCaseParam);
  }

  let worseCases = 0;

  swapTestCases.forEach((swapTestCase, i) => {
    const [blockNumber, [tokenIn, tokenOut], amountIn, expectedAmountOut] =
      swapTestCase;
    it(`Test${i}: swapping ${ethers.utils.formatEther(
      amountIn
    )} ${tokenIn} => ${tokenOut} at block ${blockNumber}`, async () => {
      const swapContract = await forkAndDeploy(blockNumber);
      const [signer] = await ethers.getSigners();
      const factoryStats: FactoryStat[] = [];
      for (const factory of [Factory.UNIV2, Factory.SUSHI, Factory.SHIBA]) {
        let [reserveIn, reserveOut]: BigNumber[] = [
          ethers.utils.parseEther("0"),
          ethers.utils.parseEther("0"),
        ];
        let poolExists = true;
        try {
          [reserveIn, reserveOut] = await swapContract.getReserves(
            factoryToAddress[factory],
            tokenToAddress[tokenIn],
            tokenToAddress[tokenOut]
          );
        } catch (error) {
          worseCases++;
          poolExists = false;
        }
        if (poolExists) {
          factoryStats.push({
            factory,
            reserveIn,
            reserveOut,
            amountIn,
            amountOut: quantityOfYForX(
              reserveIn.toBigInt(),
              reserveOut.toBigInt(),
              amountIn.toBigInt()
            ),
          });
        }
      }

      //here we need to first convert native ETH to ERC20 WETH and approve the contract to use
      //assuming that tokenIn is WETH
      await topUpWETHAndApproveContractToUse(
        signer,
        amountIn,
        swapContract.address
      );

      //call the swap
      const tx = await swapContract.swap(
        tokenToAddress[tokenIn],
        tokenToAddress[tokenOut],
        amountIn
      );
      const txStatus = await tx.wait();
      //check event emitted?
      // const swapEvent = txStatus.events.filter(
      //   (e: { event: string; args: string[] }) => e.event == "SwapEvent"
      // );
      const userRecievedAmount: BigNumber = await getBalanceOfERC20(
        signer.address,
        tokenToAddress[tokenOut]
      );

      let isBetter = true;
      factoryStats.forEach((factoryStat) => {
        const { factory, reserveIn, reserveOut, amountOut } = factoryStat;
        if (userRecievedAmount.toString() < amountOut.toString()) {
          isBetter = false;
        }
      });

      if (!isBetter) {
        worseCases++;
      }
      //TODO compare the userRecievedAmount against FactoryStat
    });
  });

  it("Percentage should be smaller than 30%", async function () {
    let percentage = worseCases / swapTestCases.length * 100;
    expect(percentage).to.lessThan(30);
  });
});
