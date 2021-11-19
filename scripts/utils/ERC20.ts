import { ethers } from "hardhat";
import { assert } from "chai";
import { Token, tokenToAddress } from "./Token";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

export const topUpWETHAndApproveContractToUse = async (
  signer: SignerWithAddress,
  ethAmount: string,
  contractAddressToApprove: string
) => {
  //buy WETH using native ETH
  await convertEthToWETH(signer, ethAmount);
  //allow the swap contract to spend the WETH
  await approveOurContractToUseWETH(
    signer,
    contractAddressToApprove,
    ethAmount
  );

  const amountOfWETHSignerRecieved = await getBalanceOfERC20(
    signer.address,
    tokenToAddress[Token.WETH]
  );
  assert(
    amountOfWETHSignerRecieved.toString() ==
      ethers.utils.parseEther(ethAmount).toString(),
    "signer didn't recieve WETH!"
  );
};

//swap signer's ETH to WETH
export const convertEthToWETH = async (
  signer: SignerWithAddress,
  amountOfEth: string
): Promise<void> => {
  const abi = ["function deposit() payable"];
  const tokenContract = new ethers.Contract(
    tokenToAddress[Token.WETH],
    abi,
    signer
  );
  await tokenContract.deposit({ value: ethers.utils.parseEther(amountOfEth) });
};

//approve the contract to use signer's WETH
const approveOurContractToUseWETH = async (
  signer: SignerWithAddress,
  contractAddressToApprove: string,
  amountOfEth: string
): Promise<void> => {
  const abi = [
    "function approve(address guy, uint wad) external returns (bool)",
  ];
  const tokenContract = new ethers.Contract(
    tokenToAddress[Token.WETH],
    abi,
    signer
  );
  await tokenContract.approve(
    contractAddressToApprove,
    ethers.utils.parseEther(amountOfEth)
  );
};

//send erc20 to eth
export const sendERC20 = async (
  signer: SignerWithAddress,
  addressToSend: string,
  ERC20TokenAddress: string,
  amountOfERC20: string
): Promise<void> => {
  const abi = [
    "function transfer(address to, uint value) external returns (bool)",
  ];
  const tokenContract = new ethers.Contract(ERC20TokenAddress, abi, signer);
  await tokenContract.transfer(
    addressToSend,
    ethers.utils.parseEther(amountOfERC20)
  );
};

//returns the balance of ERC20 token that address holds
export const getBalanceOfERC20 = async (
  address: string,
  ERC20TokenAddress: string
) => {
  const [signer] = await ethers.getSigners();
  const abi = [
    "function balanceOf(address owner) external view returns (uint)",
  ];
  const tokenContract = new ethers.Contract(
    ERC20TokenAddress,
    abi,
    signer.provider
  );
  return tokenContract.balanceOf(address);
};
