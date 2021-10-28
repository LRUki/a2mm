// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "./libraries/TokenAddrs.sol";

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
    address tokenOut = TokenAddrs.Token.AXS.getAddr();
    // address tokenIn = 0x0a180A76e4466bF68A7F86fB029BEd3cCcFaAac5;
    // address tokenOut = 0xBB0E17EF65F82Ab018d8EDd776e8DD940327B28b;
    uint24 fee = 3000;
    uint160 sqrtPriceLimitX96 = 0;
    return
      quoter.quoteExactInputSingle(
        tokenIn,
        tokenOut,
        fee,
        amount,
        sqrtPriceLimitX96
      );
  }
}
