import { ethers } from "hardhat";
import { expect } from "chai";
import { Token, tokenToAddress, tokenToDecimal } from "./Token";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

export const convertEthToWETH = async (
  signer: SignerWithAddress,
  amountOfEth: string
) => {
  const abi = ["function deposit() payable"];
  const tokenContract = new ethers.Contract(
    tokenToAddress[Token.WETH],
    abi,
    signer
  );
  await tokenContract.deposit({ value: ethers.utils.parseEther(amountOfEth) });
};

export const getBalanceOfERC20 = async (
  signer: SignerWithAddress,
  erc20TokenAddress: string
) => {
  const abi = [
    "function balanceOf(address owner) external view returns (uint)",
  ];
  const tokenContract = new ethers.Contract(
    erc20TokenAddress,
    abi,
    signer.provider
  );
  return tokenContract.balanceOf(signer.address);
};
