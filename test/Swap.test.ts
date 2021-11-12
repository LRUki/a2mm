import { ethers } from "hardhat";
import { expect, assert } from "chai";
import { Token, tokenToAddress } from "../scripts/utils/Token";
import { Factory, factoryToAddress } from "../scripts/utils/Factory";
import {
  convertEthToWETH,
  getBalanceOfERC20,
  approveOurContractToUseWETH,
} from "../scripts/utils/ERC20";
describe("==================================== Swap ====================================", function () {
  before(async function () {
    //     const dexProviderAddress = await deployContract("DexProvider");
    this.DexProvider = await ethers.getContractFactory("DexProvider");
    this.Swap = await ethers.getContractFactory("Swap");
  });

  beforeEach(async function () {
    this.dexProvider = await this.DexProvider.deploy();
    this.swap = await this.Swap.deploy(this.dexProvider.address);
    await this.swap.deployed();
  });

  it("contract recieves funds", async function () {
    const [signer] = await ethers.getSigners();
    const signerAddress = await signer.getAddress();

    const tx = {
      from: signerAddress,
      to: this.swap.address,
      value: ethers.utils.parseEther("1"),
    };
    await signer.sendTransaction(tx);
    const contractBalance = await signer.provider?.getBalance(
      this.swap.address
    );
    expect(contractBalance).to.equal(ethers.utils.parseEther("1"));
  });

  it("ERC is converted", async function () {
    const ETH_AMOUNT = "10";

    const [signer] = await ethers.getSigners();
    //buy WETH using native ETH
    await convertEthToWETH(signer, this.swap.address, ETH_AMOUNT);
    //allow the swap contract to spend the WETH
    await approveOurContractToUseWETH(signer, this.swap.address, "10");

    const amountOfWETH = await getBalanceOfERC20(
      signer,
      tokenToAddress[Token.WETH]
    );
    assert(
      amountOfWETH.toString() == ethers.utils.parseEther(ETH_AMOUNT).toString(),
      "signer didn't recieve WETH!"
    );
    let res = await this.swap.getReserves(
      factoryToAddress[Factory.UNIV2],
      tokenToAddress[Token.WETH],
      tokenToAddress[Token.DAI]
    );
    console.log(res.toString());
    await this.swap.swap(
      tokenToAddress[Token.WETH],
      tokenToAddress[Token.DAI],
      ethers.utils.parseEther("10").toString()
    );
    res = await this.swap.getReserves(
      factoryToAddress[Factory.UNIV2],
      tokenToAddress[Token.WETH],
      tokenToAddress[Token.DAI]
    );
    console.log(res.toString());
  });

  // it("Swaps at uni", async function () {
  //     let [resIn, resOut] = await this.dexProvider.getUniV2Reserves(
  //       tokenToAddress[Token.WETH],
  //       tokenToAddress[Token.USDT]
  //     );
  //     console.log("BEFORE SWAP", resIn.toString(), resOut.toString());
  // let balance = this.swap.getBalance(tokenToAddress[Token.WETH]);
  // console.log(balance.toString(), "BEFORE");
  // await this.swap.swap(
  //   tokenToAddress[Token.WETH],
  //   tokenToAddress[Token.USDT],
  //   390 * tokenToDecimal[Token.WETH]
  // );
  // balance = this.swap.getBalance(tokenToAddress[Token.WETH]);
  // console.log(balance.toString(), "AGTER");
  //     [resIn, resOut] = await this.dexProvider.getUniV2Reserves(
  //       tokenToAddress[Token.WETH],
  //       tokenToAddress[Token.USDT]
  //     );
  //     console.log("AFTER SWAP", resIn.toString(), resOut.toString());
  // });
});
