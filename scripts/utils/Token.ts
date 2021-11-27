export enum Token {
  WETH = "WETH",
  UNI = "UNI",
  DAI = "DAI",
  USDT = "USDT",
  AXS = "AXS",
  TOKE = "TOKE",
}

export const tokenToDecimal = {
  [Token.WETH]: 18,
  [Token.UNI]: 18,
  [Token.DAI]: 18,
  [Token.USDT]: 6,
  [Token.AXS]: 18,
  [Token.TOKE]: 18,
};

export const tokenToAddress = {
  [Token.WETH]: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
  [Token.UNI]: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
  [Token.DAI]: "0x6b175474e89094c44da98b954eedeac495271d0f",
  [Token.USDT]: "0xdac17f958d2ee523a2206206994597c13d831ec7",
  [Token.AXS]: "0xbb0e17ef65f82ab018d8edd776e8dd940327b28b",
  [Token.TOKE]: "0x2e9d63788249371f1DFC918a52f8d799F4a38C94",
};
