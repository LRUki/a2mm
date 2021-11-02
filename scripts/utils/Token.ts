export enum Token {
  WETH,
  UNI,
  DAI,
  USDT,
  AXS,
}

export const tokenToDecimal = {
  [Token.WETH]: 18,
  [Token.UNI]: 18,
  [Token.DAI]: 18,
  [Token.USDT]: 6,
  [Token.AXS]: 18,
};
