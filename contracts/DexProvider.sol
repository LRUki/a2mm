// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity 0.6.6 || 0.8.3;

// import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";

contract DexProvider {
        event Swap(uint256 amountIn, uint256 amountOut);

	
	function getReserves(address factoryAddress, address tokenA, address tokenB) external view returns (uint reserveA, uint reserveB) {
		address pairAddress = IUniswapV2Factory(factoryAddress).getPair(tokenA, tokenB);
		require(pairAddress != address(0), "This pool does not exist");
 		(address token0,) = UniswapV2Library.sortTokens(tokenA, tokenB);
 	        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairAddress).getReserves();
 	        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
 	}

	//swaps tokenIn -> tokenOut
	//assumes the sender already approved to spend thier tokenIn on behalf
	//at the end of the execution, this address will be holding the tokenOut
    	function executeSwap(address factoryAddress, address tokenIn, address tokenOut, uint256 amountIn) public { 
		address pairAddress = IUniswapV2Factory(factoryAddress).getPair(tokenIn, tokenOut);
		require(pairAddress != address(0), "This pool does not exist");
       		(address token0,) = UniswapV2Library.sortTokens(tokenIn, tokenOut);
        	require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "transferFrom failed, make sure user approved");
	        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pairAddress).getReserves();
        	(uint256 reserveIn, uint256 reserveOut) = token0 == tokenIn ? (reserve0, reserve1) : (reserve1, reserve0);
        	uint256 amountOut = UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut); 
        	IERC20(tokenIn).transfer(pairAddress, amountIn);
        	(uint256 amount0Out, uint256 amount1Out) = token0 == tokenIn ? (uint256(0), amountOut) : (amountOut, uint256(0));
    		IUniswapV2Pair(pairAddress).swap(amount0Out, amount1Out, address(this), new bytes(0));
        	emit Swap(amountIn, amountOut);
	}
	
}