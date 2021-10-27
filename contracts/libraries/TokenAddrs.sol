// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

//token addresses on ETH mainchain from https://info.uniswap.org/#/pools

library TokenAddrs {
  enum Token {
    WETH,
    UNI,
    DAI,
    USDT,
    AXS
  }

  function getAddr(Token token) external pure returns (address) {
    if (token == Token.WETH) {
      return address(0x0a180A76e4466bF68A7F86fB029BEd3cCcFaAac5);
    } else if (token == Token.UNI) {
      return address(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    } else if (token == Token.DAI) {
      return address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    } else if (token == Token.USDT) {
      return address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    } else if (token == Token.AXS) {
      return address(0xBB0E17EF65F82Ab018d8EDd776e8DD940327B28b);
    } else {
      revert("Invalid TOKEN");
    }
  }
}
