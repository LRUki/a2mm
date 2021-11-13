import { ethers } from "hardhat";
import { expect } from "chai";
import { Token, tokenToAddress } from "../scripts/utils/Token";
import {
  getBalanceOfERC20,
  topUpWETHAndApproveContractToUse,
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

  // it("executes swap", async function () {
  //   const ETH_AMOUNT = "10";
  //   const [signer] = await ethers.getSigners();

  //   //here we need to first convert native ETH to ERC20 WETH
  //   await topUpWETHAndApproveContractToUse(
  //     signer,
  //     ETH_AMOUNT,
  //     this.dexProvider.address
  //   );
  //   const [reserve0Before, reserve1Before]: BigNumber[] =
  //     await this.dexProvider.getReserves(
  //       factoryToAddress[Factory.SUSHI],
  //       tokenToAddress[Token.WETH],
  //       tokenToAddress[Token.DAI]
  //     );
  //   const tx = await this.dexProvider.executeSwap(
  //     factoryToAddress[Factory.SUSHI],
  //     tokenToAddress[Token.WETH],
  //     tokenToAddress[Token.DAI],
  //     ethers.utils.parseEther("10").toString()
  //   );
  //   const txStatus = await tx.wait();
  //   const swapEvent = txStatus.events.filter(
  //     (e: { event: string; args: string[] }) => e.event == "Swap"
  //   );
  //   expect(swapEvent).to.have.lengthOf(1);
  //   const { amountIn, amountOut } = swapEvent[0].args;

  //   const [reserve0After, reserve1After]: BigNumber[] =
  //     await this.dexProvider.getReserves(
  //       factoryToAddress[Factory.SUSHI],
  //       tokenToAddress[Token.WETH],
  //       tokenToAddress[Token.DAI]
  //     );
  //   //we recieved reserve1
  //   expect(reserve1Before.sub(reserve1After).eq(amountOut)).to.be.true;
  //   expect(reserve0After.sub(reserve0Before).eq(amountIn)).to.be.true;

  //   //check if signer recieved the token
  //   const amountRecieved = await getBalanceOfERC20(
  //     signer,
  //     tokenToAddress[Token.DAI]
  //   );
  //   expect(amountRecieved.eq(amountOut)).to.be.true;
  // });
});
