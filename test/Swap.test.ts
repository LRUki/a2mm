// import { ethers } from "hardhat";
// import { expect } from "chai";
// import deployContract from "../scripts/utils/deploy";
// import { Token, tokenToAddress, tokenToDecimal } from "../scripts/utils/Token";

// describe("==================================== Swap ====================================", function () {
//   before(async function () {
//     const dexProviderAddress = await deployContract("DexProvider");
//     this.Swap = await ethers.getContractFactory("Swap");
//   });
//   beforeEach(async function () {
//     const dexProviderAddress = await deployContract("DexProvider");
//     this.swap = await this.Swap.deploy(dexProviderAddress);
//     await this.swap.deployed();
//   });

//   it("Swaps at uni", async function () {
//     const res = this.swap.swap(
//       tokenToAddress[Token.WETH],
//       tokenToAddress[Token.DAI],
//       1 * tokenToDecimal[Token.WETH]
//     );
//   });
// });
