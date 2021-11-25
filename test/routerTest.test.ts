// import { expect } from "chai";
// import { BigNumber, Contract, ContractTransaction, Signer } from "ethers";
// import { ethers } from "hardhat";
// import { ERC20 } from "../scripts/utils/ERC20";
// import { FEG_ADDRESS, forkArchive, SUSHISWAP_ROUTER02_ADDRESS, UNISWAP_ROUTER02_ADDRESS, USDC_ADDRESS, WETH_ADDRESS } from "./helper";

// describe("Router Test", function () {

//     const allSwapTestCases: [Number, string, string, string[], BigNumber, BigNumber][] = [
//         [11333125, "swapExactETHForTokens", "Uni", [WETH_ADDRESS, USDC_ADDRESS], ethers.utils.parseUnits("0.1", 18), ethers.utils.parseUnits("48.438023", 6)],
//         [11333125, "swapExactETHForTokens", "Sushi", [WETH_ADDRESS, USDC_ADDRESS], ethers.utils.parseUnits("0.1", 18), ethers.utils.parseUnits("49.432928", 6)],
//         [11333125, "swapExactETHForTokens", "Swap", [WETH_ADDRESS, USDC_ADDRESS], ethers.utils.parseUnits("0.1", 18), ethers.utils.parseUnits("1208.355502", 6)],
//         [11333125, "swapExactTokensForTokens", "Uni", [USDC_ADDRESS, WETH_ADDRESS], ethers.utils.parseUnits("100", 6), ethers.utils.parseUnits("0.205213454864748830", 18)],
//         [11333125, "swapExactTokensForTokens", "Sushi", [USDC_ADDRESS, WETH_ADDRESS], ethers.utils.parseUnits("100", 6), ethers.utils.parseUnits("0.201081560771968916", 18)],
//         [11333125, "swapExactTokensForTokens", "Swap", [USDC_ADDRESS, WETH_ADDRESS], ethers.utils.parseUnits("100", 6), ethers.utils.parseUnits("2.572088016878162718", 18)],
//         [11333125, "swapExactTokensForETH", "Uni", [USDC_ADDRESS, WETH_ADDRESS], ethers.utils.parseUnits("100", 6), ethers.utils.parseUnits("0.204242110864748830", 18)],
//         [11333125, "swapExactTokensForETH", "Sushi", [USDC_ADDRESS, WETH_ADDRESS], ethers.utils.parseUnits("100", 6), ethers.utils.parseUnits("0.200102656771968916", 18)],
//         [11333125, "swapExactTokensForETH", "Swap", [USDC_ADDRESS, WETH_ADDRESS], ethers.utils.parseUnits("100", 6), ethers.utils.parseUnits("2.570190840878162718", 18)],
//         [12288536, "swapExactTokensForTokensSupportingFeeOnTransferTokens", "Uni", [FEG_ADDRESS, WETH_ADDRESS], ethers.utils.parseUnits("100", 9), ethers.utils.parseUnits("0.000000000105239890", 18)],
//         [12288536, "swapExactTokensForTokensSupportingFeeOnTransferTokens", "Swap", [FEG_ADDRESS, WETH_ADDRESS], ethers.utils.parseUnits("100", 9), ethers.utils.parseUnits("0.000000000105239890", 18)],
//     ]

//     allSwapTestCases.forEach((swapTestCase, i) => {
//         it(`Test ${i}: ${swapTestCase[1]}, ${swapTestCase[4].toString()} -> ${swapTestCase[5].toString()}`, async () => {
//             const [block, method, exchange, path, inputAmount, expectedOutput] = swapTestCase;
//             await forkArchive(block);

//             const accounts = await ethers.getSigners();
//             const deployer: Signer = accounts[0];
//             const deployerAddress: string = await deployer.getAddress();

//             let router: Contract
//             if (exchange === "Uni") {
//                 router = await ethers.getContractAt("IUniswapV2Router02", UNISWAP_ROUTER02_ADDRESS);
//             } else if (exchange === "Sushi") {
//                 router = await ethers.getContractAt("IUniswapV2Router02", SUSHISWAP_ROUTER02_ADDRESS);
//             } else if (exchange === "Swap") {
//                 const SwapSwapRouter = await ethers.getContractFactory("SwapSwapRouter");
//                 router = await SwapSwapRouter.deploy();;
//             } else {
//                 expect.fail("Unknown exchange");
//             }

//             const inputToken = new ERC20(path[0]);
//             const outputToken = new ERC20(path[path.length - 1]);

//             // Purchase input token from Uniswap if its not WETH
//             // We multiple the actual input by 2, just in case this is a fee on transfer token
//             if (path[0] !== WETH_ADDRESS) {
//                 await inputToken.swapETHForExactToken(deployer, inputAmount.mul(2).toString(), 0, deployerAddress);
//             }

//             await inputToken.approve(deployer, router.address, inputAmount.toString(), 0);

//             var actualOutput: BigNumber

//             if (method === "swapExactETHForTokens") {
//                 const initialBalance = await outputToken.balanceOf(deployerAddress);
//                 const tx: ContractTransaction = await router.swapExactETHForTokens(
//                     0,
//                     path,
//                     deployer.getAddress(),
//                     Date.now(),
//                     {
//                         value: inputAmount
//                     }
//                 )
//                 const finalBalance = await outputToken.balanceOf(deployerAddress);
//                 actualOutput = finalBalance.sub(initialBalance);
//             } else if (method === "swapExactTokensForETHSupportingFeeOnTransferTokens") {
//                 const initialBalance = await outputToken.balanceOf(deployerAddress);
//                 const tx: ContractTransaction = await router.swapExactTokensForETHSupportingFeeOnTransferTokens(
//                     0,
//                     path,
//                     deployer.getAddress(),
//                     Date.now(),
//                     {
//                         value: inputAmount
//                     }
//                 )
//                 const finalBalance = await outputToken.balanceOf(deployerAddress);
//                 actualOutput = finalBalance.sub(initialBalance);
//             } else if (method === "swapExactTokensForETH") {
//                 const initialBalance = await deployer.getBalance();
//                 const tx: ContractTransaction = await router.swapExactTokensForETH(
//                     inputAmount,
//                     0,
//                     path,
//                     deployer.getAddress(),
//                     Date.now(),
//                 )
//                 const finalBalance = await deployer.getBalance();
//                 actualOutput = finalBalance.sub(initialBalance);
//             } else if (method === "swapExactTokensForETHSupportingFeeOnTransferTokens") {
//                 const initialBalance = await deployer.getBalance();
//                 const tx: ContractTransaction = await router.swapExactTokensForETHSupportingFeeOnTransferTokens(
//                     inputAmount,
//                     0,
//                     path,
//                     deployer.getAddress(),
//                     Date.now(),
//                 )
//                 const finalBalance = await deployer.getBalance();
//                 actualOutput = finalBalance.sub(initialBalance);
//             } else if (method === "swapExactTokensForTokens") {
//                 const initialBalance = await outputToken.balanceOf(deployerAddress);
//                 const tx: ContractTransaction = await router.swapExactTokensForTokens(
//                     inputAmount,
//                     0,
//                     path,
//                     deployer.getAddress(),
//                     Date.now(),
//                 )
//                 const finalBalance = await outputToken.balanceOf(deployerAddress);
//                 actualOutput = finalBalance.sub(initialBalance);
//             } else if (method === "swapExactTokensForTokensSupportingFeeOnTransferTokens") {
//                 const initialBalance = await outputToken.balanceOf(deployerAddress);
//                 const tx: ContractTransaction = await router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
//                     inputAmount,
//                     0,
//                     path,
//                     deployer.getAddress(),
//                     Date.now(),
//                 )
//                 const finalBalance = await outputToken.balanceOf(deployerAddress);
//                 actualOutput = finalBalance.sub(initialBalance);
//             } else {
//                 expect.fail("Unrecognised method")
//             }
//             expect(actualOutput).to.deep.eq(expectedOutput, `Expects ${expectedOutput}, actual ${actualOutput}`);
//         })
//     })
// });
