// SPDX-License-Identifier: MIT
pragma solidity 0.6.6 || 0.8.3;
pragma experimental ABIEncoderV2;

import "./libraries/Structs.sol";
import "./libraries/Arbitrage.sol";
import "./libraries/Route.sol";
import "./interfaces/IWETH9.sol";
import "./DexProvider.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "hardhat/console.sol";

contract Swap {
    address private _sushiFactoryAddress = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address private _uniV2FactoryAddress = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private _wethTokenAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private _uniV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IWETH9 private _WETH;

    DexProvider private _dexProvider;
        
    constructor(address dexProviderAddress) public {
	    _dexProvider = DexProvider(dexProviderAddress);
        _WETH = IWETH9(_wethTokenAddress);
    }


    function swap(address tokenIn, address tokenOut, uint256 amountIn) external {
	    // _dexProvider.getSushiReserves();
        address pairAddress = IUniswapV2Factory(_uniV2FactoryAddress).getPair(tokenIn, tokenOut);
		require(pairAddress != address(0), "This pool does not exist");
        executeSwap(pairAddress, tokenIn, tokenOut, amountIn);
    }



    function executeSwap(address pairAddress, address tokenIn, address tokenOut, uint256 amountIn) public {
        (address token0,) = UniswapV2Library.sortTokens(tokenIn, tokenOut);
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "transferFrom failed, make sure user approved");
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pairAddress).getReserves();
        (uint256 reserveIn, uint256 reserveOut) = token0 == tokenIn ? (reserve0, reserve1) : (reserve1, reserve0);
        uint256 amountOut = UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut); 
        IERC20(tokenIn).transfer(pairAddress,amountIn);
        (uint256 amount0Out, uint256 amount1Out) = token0 == tokenIn ? (uint256(0), amountOut) : (amountOut, uint256(0));
    	IUniswapV2Pair(pairAddress).swap(amount0Out, amount1Out, address(this), new bytes(0));
	}

    //assumes pairAddress exsits and token0, token1 is sorted
    function getReserves(address factoryAddress, address token0, address token1) public view returns (uint resIn, uint resOut) {
  		(resIn, resOut,) = IUniswapV2Pair(IUniswapV2Factory(_uniV2FactoryAddress).getPair(token0, token1)).getReserves();
	}

        // console.log(IERC20(tokenIn).balanceOf(address(this)),"BEFORE");
        // console.log(IERC20(tokenIn).balanceOf(address(this)),"AFTER");
        // IERC20(tokenIn).approve(address(this),amountIn)
        // IUniswapV2Router02 router = IUniswapV2Router02(_uniV2Router);
        // require(TOKEN.transferFrom(msg.sender, address(this), amountOfX), "transferFrom failed.");
        // require(TOKEN.approve(address(this), amountOfX), 'approve failed.');
		
    
    event Received(address, uint);
    receive() external payable {
        emit Received(msg.sender, msg.value);
        // _WETH.deposit{value:msg.value}();
    }
    
    // @notice - for now, only the first two AMMs in the list will actually be considered for anything
    // @param amountOfX - how much the user is willing to trade
    // @return amountsToSendToAmms - the pair of values indicating how much of X and Y should be sent to each AMM (ordered in the same way as the AMMs were passed in)
    // @return flashLoanRequiredAmount - how big of a flash loan we would need to take out to successfully complete the transation. This is done for the arbitrage step.
//     function swapXforY(Structs.Amm[] memory amms, uint256 amountOfX) public pure returns (Structs.AmountsToSendToAmm[] memory amountsToSendToAmms, uint256 flashLoanRequiredAmount) {
//         bool shouldArbitrage;

//         uint256 totalYGainedFromRouting;
//         Structs.XSellYGain[] memory routingsAndGains;
//         (routingsAndGains, totalYGainedFromRouting, shouldArbitrage) = Route.route(amms, amountOfX);
//         amountsToSendToAmms = new Structs.AmountsToSendToAmm[](amms.length);
//         for (uint256 i = 0; i < amms.length; i++) {
//             amountsToSendToAmms[i] = Structs.AmountsToSendToAmm(routingsAndGains[i].x, 0);
//         }
//         if (shouldArbitrage) {
//            Structs.AmountsToSendToAmm[] memory arbitrages;
//            (shouldArbitrage, arbitrages, flashLoanRequiredAmount) = Arbitrage.arbitrage(amms, totalYGainedFromRouting);
//            if (shouldArbitrage) {
//                for (uint256 i = 0; i < amms.length; i++) {
//                    //If we are adding an extra step after arbitrage, we might want to update the AMMs here once again.
//                    amountsToSendToAmms[i].x += arbitrages[i].x;
//                    amountsToSendToAmms[i].y += arbitrages[i].y;
//                }
//            }
//         }
//         flashLoanRequiredAmount = 0;
//     }
}
