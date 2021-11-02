// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "./libraries/TokenAddrs.sol";
import "hardhat/console.sol";

contract UniV3PriceFeed {
  IQuoter public quoter = IQuoter(address(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6));
  using TokenAddrs for TokenAddrs.Token;
  // do not used on-chain, gas inefficient!
  function getPrice(TokenAddrs.Token tokenIn, TokenAddrs.Token tokenOut, uint256 amount) external payable returns (uint256) {
    uint24 fee = 3000;
    uint256 x = quoter.quoteExactInputSingle(
        tokenIn.getAddr(),
        tokenOut.getAddr(),
        fee,
        amount,
        0
      );
    console.log("VALUE=",x);
    return x;
  }
}
