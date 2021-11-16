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
import deployContract from "../scripts/utils/deploy";
describe("==================================== Swap ====================================", function () {
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

    this.Swap = await ethers.getContractFactory("SwapContract", {
      libraries: { Arbitrage: this.arbitrage.address, Route: this.route.address },
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
    const ethAmout = "5";
    const tokenIn = tokenToAddress[Token.WETH];
    const tokenOut = tokenToAddress[Token.DAI];

    //here we need to first convert native ETH to ERC20 WETH
    await topUpWETHAndApproveContractToUse(signer, ethAmout, this.swap.address);
    const tx = await this.swap.swap(
      tokenIn,
      tokenOut,
      ethers.utils.parseEther(ethAmout).toString()
    );
    const txStatus = await tx.wait();
    const swapEvent = txStatus.events.filter(
      (e: { event: string; args: string[] }) => e.event == "Swap"
    );
    expect(swapEvent).to.have.lengthOf(1);
    const { amountOut } = swapEvent[0].args;
    const amountRecieved = await getBalanceOfERC20(signer.address, tokenOut);
    expect(amountRecieved.eq(amountOut)).to.be.true;
  });
});
