// SPDX-License-Identifier: MIT
pragma solidity  0.6.6 || 0.8.3;

import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "./interfaces/IReserveFeed.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract ReserveFeed is IReserveFeed {
	IUniswapV2Factory private _uniV2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

	IUniswapV2Factory private _sushiFactory = IUniswapV2Factory(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);

	function getUniV2Reserves(address tokenIn, address tokenOut) external override view returns (uint, uint)
 	{
        	return _getReserves(_uniV2Factory, tokenIn, tokenOut);
    	}

	function getSushiReserves(address tokenIn, address tokenOut) external override view returns (uint, uint)
 	{
		 return _getReserves(_sushiFactory, tokenIn, tokenOut);
    	}

	function _getReserves(IUniswapV2Factory factory, address tokenIn, address tokenOut) private view returns (uint,uint) {
		IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(tokenIn, tokenOut));
  		(uint res0, uint res1,) = pair.getReserves();
       		return (res0, res1);
	}
}