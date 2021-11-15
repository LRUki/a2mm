// SPDX-License-Identifier: MIT
// solhint-disable-next-line
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

contract Swap is DexProvider {
    address payable constant private _SUSHI_FACTORY_ADDRESS = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address payable constant private _UNIV2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    
    event SwapEvent(uint256 amountIn, uint256 amountOut);
    // address private _wethTokenAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // address private _uniV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    // IWETH9 private _WETH = IWETH9(_wethTokenAddress);


    function swap(address tokenIn, address tokenOut, uint256 amountIn) external {
        Structs.AmountsToSendToAmm[] memory route = _mockAmountsToSendToAmms(amountIn);
        require(route[0].x + route[1].x == amountIn, "wrong route");
        uint256 amountOut = 0;
        for (uint256 i = 0; i < route.length; ++i) {
	        amountOut += executeSwap(i == 0 ? _SUSHI_FACTORY_ADDRESS : _UNIV2_FACTORY_ADDRESS, tokenIn, tokenOut, route[i].x);
        }
        require(IERC20(tokenOut).transfer(msg.sender, amountOut), "token failed to be sent back");
        emit SwapEvent(amountIn, amountOut);
    }


    //returns mock routing for univ2 and sushi
    function _mockAmountsToSendToAmms(uint256 amountIn) private pure returns (Structs.AmountsToSendToAmm[] memory amountsToSendToAmms) {
        uint256 amountToSendToUniV2 = amountIn / 2;
        uint256 amountToSendToSushi = amountIn - amountToSendToUniV2;
        amountsToSendToAmms = new Structs.AmountsToSendToAmm[](2);
        amountsToSendToAmms[0] = Structs.AmountsToSendToAmm(amountToSendToUniV2, 0);
        amountsToSendToAmms[1] = Structs.AmountsToSendToAmm(amountToSendToSushi, 0);
    }


    // @notice - for now, only the first two AMMs in the list will actually be considered for anything
    // @param amountOfX - how much the user is willing to trade
    // @return amountsToSendToAmms - the pair of values indicating how much of X and Y should be sent to each AMM (ordered in the same way as the AMMs were passed in)
    // @return flashLoanRequiredAmount - how big of a flash loan we would need to take out to successfully complete the transation. This is done for the arbitrage step.
    function swapXforY(Structs.Amm[] memory amms, uint256 amountOfX) public pure returns (Structs.AmountsToSendToAmm[] memory amountsToSendToAmms, uint256 flashLoanRequiredAmount) {
        bool shouldArbitrage;

        uint256 totalYGainedFromRouting;
        Structs.XSellYGain[] memory routingsAndGains;
        (routingsAndGains, totalYGainedFromRouting, shouldArbitrage) = Route.route(amms, amountOfX);
        amountsToSendToAmms = new Structs.AmountsToSendToAmm[](amms.length);
        for (uint256 i = 0; i < amms.length; i++) {
            amountsToSendToAmms[i] = Structs.AmountsToSendToAmm(routingsAndGains[i].x, 0);
        }

        flashLoanRequiredAmount = 0;
        if (shouldArbitrage && amms.length > 1) {
            Structs.AmountsToSendToAmm[] memory arbitrages;
            (arbitrages, flashLoanRequiredAmount) = Arbitrage.arbitrage(amms, totalYGainedFromRouting);
            for (uint256 i = 0; i < amms.length; i++) {
                amountsToSendToAmms[i].x += arbitrages[i].x;
                amountsToSendToAmms[i].y += arbitrages[i].y;
            }
        }
    }


    //allow contract to recieve eth
    //not sure if we need it but might as well
    receive() external payable {
        console.log(msg.sender);
        // _WETH.deposit{value:msg.value}();
    }
}