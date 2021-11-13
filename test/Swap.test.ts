import { ethers } from "hardhat";
import { expect, assert } from "chai";
import { Token, tokenToAddress } from "../scripts/utils/Token";
import { Factory, factoryToAddress } from "../scripts/utils/Factory";
import {
  getBalanceOfERC20,
  topUpWETHAndApproveContractToUse,
} from "../scripts/utils/ERC20";
import { ContractFactory } from "@ethersproject/contracts";
import { BigNumber } from "@ethersproject/bignumber";
describe("==================================== Swap ====================================", function () {
  before(async function () {
    this.Swap = await ethers.getContractFactory("Swap");
  });

  beforeEach(async function () {
    this.swap = await this.Swap.deploy();
    await this.swap.deployed();
  });

  it("ERC is converted", async function () {
    const ETH_AMOUNT = "10";
    const [signer] = await ethers.getSigners();

    //here we need to first convert native ETH to ERC20 WETH
    await topUpWETHAndApproveContractToUse(
      signer,
      ETH_AMOUNT,
      this.swap.address
    );
    const [reserve0Before, reserve1Before]: BigNumber[] =
      await this.swap.getReserves(
        factoryToAddress[Factory.SUSHI],
        tokenToAddress[Token.WETH],
        tokenToAddress[Token.DAI]
      );

    let b = await getBalanceOfERC20(signer, tokenToAddress[Token.DAI]);
    console.log(b.toString(), "BEFORE DAI");
    const tx = await this.swap.swap(
      tokenToAddress[Token.WETH],
      tokenToAddress[Token.DAI],
      ethers.utils.parseEther(ETH_AMOUNT).toString()
    );
    const txStatus = await tx.wait();
    const swapEvent = txStatus.events.filter(
      (e: { event: string; args: string[] }) => e.event == "Swap"
    );
    expect(swapEvent).to.have.lengthOf(1);
    const { amountIn, amountOut } = swapEvent[0].args;

    const [reserve0After, reserve1After]: BigNumber[] =
      await this.swap.getReserves(
        factoryToAddress[Factory.SUSHI],
        tokenToAddress[Token.WETH],
        tokenToAddress[Token.DAI]
      );

    //check reserve changed accordingly
    expect(reserve1Before.sub(reserve1After).eq(amountOut)).to.be.true;
    expect(reserve0After.sub(reserve0Before).eq(amountIn)).to.be.true;

    //check if signer recieved the token
    const amountRecieved = await getBalanceOfERC20(
      signer,
      tokenToAddress[Token.DAI]
    );
    console.log(amountRecieved.toString(), amountOut.toString());
    expect(amountRecieved.eq(amountOut)).to.be.true;
  });

  it("contract recieves funds", async function () {
    const [signer] = await ethers.getSigners();
    const signerAddress = await signer.getAddress();
    await signer.sendTransaction({
      from: signerAddress,
      to: this.swap.address,
      value: ethers.utils.parseEther("1"),
    });
    const contractBalance = await signer.provider?.getBalance(
      this.swap.address
    );
    expect(contractBalance).to.equal(ethers.utils.parseEther("1"));
  });
});
