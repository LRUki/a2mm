// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "./libraries/TokenAddrs.sol";
import "hardhat/console.sol";

contract UniV3PriceFeed {
  IQuoter public quoter;
  using TokenAddrs for TokenAddrs.Token;

  function init() public {
    quoter = IQuoter(address(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6));
  }

  function getAddres(TokenAddrs.Token token) external pure returns (address) {
    return token.getAddr();
  }

  // do not used on-chain, gas inefficient!
  function getPrice(uint256 amount) external payable returns (uint256) {
    address tokenIn = TokenAddrs.Token.WETH.getAddr();
    address tokenOut = TokenAddrs.Token.UNI.getAddr();
    console.log("TOKENIN",tokenIn);
    console.log("TOKENOUT",tokenOut);
    uint24 fee = 3000;
    uint160 sqrtPriceLimitX96 = 0;
    uint256 x = quoter.quoteExactInputSingle(
        tokenIn,
        tokenOut,
        fee,
        amount,
        sqrtPriceLimitX96
      );
    console.log(x);
    return x;
  }
}
