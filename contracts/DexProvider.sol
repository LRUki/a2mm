// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity 0.6.6 || 0.8.3;

// import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
// import "./interfaces/IReserveFeed.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
contract DexProvider {
	address private _uniV2FactoryAddress = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
	address private _sushiFactoryAddress = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;

	function getUniV2Reserves(address tokenIn, address tokenOut) external view returns (uint, uint)
 	{
        	return getReserves(_uniV2FactoryAddress, tokenIn, tokenOut);
    	}

	function getSushiReserves(address tokenIn, address tokenOut) external view returns (uint, uint)
 	{
		 return getReserves(_sushiFactoryAddress, tokenIn, tokenOut);
    	}

	function getReserves(address factoryAddress, address tokenIn, address tokenOut) public view returns (uint resIn,uint resOut) {
		address pairAddress = IUniswapV2Factory(factoryAddress).getPair(tokenIn, tokenOut);
		require(pairAddress != address(0), "This pool does not exist");
		IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
  		(resIn, resOut,) = pair.getReserves();
	}

	function executeSwap(address factoryAddress, address tokenIn, address tokenOut, uint256 amountOfX) public {
		address pairAddress = IUniswapV2Factory(factoryAddress).getPair(tokenIn, tokenOut);
		require(pairAddress != address(0), "This pool does not exist");
    		IUniswapV2Pair(pairAddress).swap(
     		 amountOfX, 
     		 0, 
     		 address(this), 
     		 bytes("not empty")
    		);
	}
}