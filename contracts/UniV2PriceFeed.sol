pragma solidity 0.6.6 || 0.8.3;

import '@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IERC20.sol';

contract UniV2PriceFeed {

    function getPair(address factoryAddress, address token0, address token1) public view returns (address)
    {
        IUniswapV2Factory factory = IUniswapV2Factory(factoryAddress);
        return factory.getPair(token0, token1);
    }

// calculate price based on pair reserves
   function getReservesPair(address pairAddress, uint amount) public view returns (uint, uint)
   {
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        IERC20 token1 = IERC20(pair.token1());
        (uint Res0, uint Res1,) = pair.getReserves();

        return (Res0, Res1);
   }

}