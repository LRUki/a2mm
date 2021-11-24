import { ethers } from "hardhat";
import { expect } from "chai";
import { Token, tokenToAddress } from "../scripts/utils/Token";
import {
  getBalanceOfERC20,
  convertEthToWETH,
  sendERC20,
} from "../scripts/utils/ERC20";
import { BigNumber } from "@ethersproject/bignumber";
import { Factory, factoryToAddress } from "../scripts/utils/Factory";
describe("==================================== DexProvider ====================================", function () {
  before(async function () {
    this.DexProvider = await ethers.getContractFactory("DexProvider");
  });
  beforeEach(async function () {
    this.dexProvider = await this.DexProvider.deploy();
    await this.dexProvider.deployed();
  });

  it("ReserveFeed fetches coorrect reserves", async function () {
    let [reserveIn, reserveOut] = await this.dexProvider.getReserves(
      factoryToAddress[Factory.SUSHI],
      tokenToAddress[Token.WETH],
      tokenToAddress[Token.USDT]
    );
    expect(reserveIn.toString()).to.equal("29364268457386578591426");
    expect(reserveOut.toString()).to.equal("119932108135609");
    [reserveIn, reserveOut] = await this.dexProvider.getReserves(
      factoryToAddress[Factory.SUSHI],
      tokenToAddress[Token.USDT],
      tokenToAddress[Token.WETH]
    );
    expect(reserveIn.toString()).to.equal("119932108135609");
    expect(reserveOut.toString()).to.equal("29364268457386578591426");
  });

  it("executes swap", async function () {
    const [signer] = await ethers.getSigners();
    const ethAmout = "0.1";
    const tokenIn = tokenToAddress[Token.WETH];
    const tokenOut = tokenToAddress[Token.UNI];

    await convertEthToWETH(signer, ethAmout);
    await sendERC20(signer, this.dexProvider.address, tokenIn, ethAmout);
    const [reserve0Before, reserve1Before]: BigNumber[] =
      await this.dexProvider.getReserves(
        factoryToAddress[Factory.SUSHI],
        tokenIn,
        tokenOut
      );
    const tx = await this.dexProvider.executeSwap(
      factoryToAddress[Factory.SUSHI],
      tokenIn,
      tokenOut,
      ethers.utils.parseEther(ethAmout).toString()
    );
    const txStatus = await tx.wait();
    const executeSwapEvent = txStatus.events.filter(
      (e: { event: string; args: string[] }) => e.event == "ExecuteSwapEvent"
    );
    expect(executeSwapEvent).to.have.lengthOf(1);
    const { amountIn, amountOut } = executeSwapEvent[0].args;

    const [reserve0After, reserve1After]: BigNumber[] =
      await this.dexProvider.getReserves(
        factoryToAddress[Factory.SUSHI],
        tokenIn,
        tokenOut
      );

    //we recieved reserve1
    expect(reserve1Before.sub(reserve1After).eq(amountOut)).to.be.true;
    expect(reserve0After.sub(reserve0Before).eq(amountIn)).to.be.true;

    //check if the contract recieved the token
    const amountRecieved = await getBalanceOfERC20(
      this.dexProvider.address,
      tokenOut
    );
    expect(amountRecieved.eq(amountOut)).to.be.true;
  });
});
