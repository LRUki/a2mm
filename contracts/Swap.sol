// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity 0.6.6 || 0.8.3;
pragma experimental ABIEncoderV2;

import "./libraries/Structs.sol";
import "./libraries/Arbitrage.sol";
import "./libraries/Route.sol";
import "./libraries/SharedFunctions.sol";
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
    address payable[2] private _factoryAddresses = [_SUSHI_FACTORY_ADDRESS, _UNIV2_FACTORY_ADDRESS];

    event SwapEvent(uint256 amountIn, uint256 amountOut);

    function swap(address tokenIn, address tokenOut, uint256 amountIn) external {
        Structs.AmountsToSendToAmm[] memory route = _mockAmountsToSendToAmms(amountIn);
        require(route[0].x + route[1].x == amountIn, "wrong route");
        uint256 amountOut = 0;
        for (uint256 i = 0; i < route.length; ++i) {
            amountOut += executeSwap(_factoryAddresses[i], tokenIn, tokenOut, route[i].x);
        }
        require(IERC20(tokenOut).transfer(msg.sender, amountOut), "token failed to be sent back");
        emit SwapEvent(amountIn, amountOut);
    }


    // @param tokenIn - the token which the user will provide/is wanting to sell
    // @param tokenOut - the token which the user will be given/is wanting to buy
    // @param amountIn - how much of tokenIn the user is wanting to exchange for totalOut amount of tokenOut
    // @return totalOut - the amount of token the user will get in return for amountIn of tokenIn
    function simulateSwap(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256 totalOut) {
        Structs.Amm[] memory amms0 = new Structs.Amm[](_factoryAddresses.length);
        Structs.Amm[] memory amms1 = new Structs.Amm[](_factoryAddresses.length);
        for (uint256 i = 0; i < _factoryAddresses.length; i++) {
            (amms0[i].x, amms0[i].y) = getReserves(_factoryAddresses[i], tokenIn, tokenOut);
            (amms1[i].x, amms1[i].y) = getReserves(_factoryAddresses[i], tokenIn, tokenOut);
        }

        totalOut = 0;
        (Structs.AmountsToSendToAmm[] memory route, uint256 flashLoanRequired) = swapXforY(amms0, amountIn);
        for (uint256 i = 0; i < amms0.length; i++) {
            totalOut += SharedFunctions.quantityOfYForX(amms1[i], route[i].x);
        }
        return totalOut - flashLoanRequired;
    }


    // @param arbitragingFor - the token which the user will provide/is wanting to arbitrage for
    // @param intermediateToken - the token which the user is wanting to user during the arbitrage step \
    // (arbitragingFor -> intermediateToken -> arbitragingFor)
    // @return arbitrageGain - how much of token 'arbitragingFor' the user will gain for executing this arbitrage
    // @return tokenInRequired - how much of 'arbitragingFor' the user would be required to own to complete the \
    // arbitrage without a flash loan, using our arbitraging algorithm
    function simulateArbitrage(address arbitragingFor, address intermediateToken) external view returns (uint256 arbitrageGain, uint256 tokenInRequired) {
        Structs.Amm[] memory amms0 = new Structs.Amm[](_factoryAddresses.length);
        Structs.Amm[] memory amms1 = new Structs.Amm[](_factoryAddresses.length);
        for (uint256 i = 0; i < _factoryAddresses.length; i++) {
            (amms0[i].x, amms0[i].y) = getReserves(_factoryAddresses[i], intermediateToken, arbitragingFor);
            (amms1[i].x, amms1[i].y) = getReserves(_factoryAddresses[i], intermediateToken, arbitragingFor);
        }

        Structs.AmountsToSendToAmm[] memory arbitrages;
        (arbitrages, tokenInRequired) = Arbitrage.arbitrageForY(amms0, 0);
        arbitrageGain = 0;
        for (uint256 i = 0; i < amms0.length; i++) {
            arbitrageGain += SharedFunctions.quantityOfYForX(amms1[i], arbitrages[i].x);
        }
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
        uint256[] memory routings;
        (routings, totalYGainedFromRouting, shouldArbitrage, amms) = Route.route(amms, amountOfX);
        amountsToSendToAmms = new Structs.AmountsToSendToAmm[](amms.length);
        for (uint256 i = 0; i < amms.length; i++) {
            amountsToSendToAmms[i] = Structs.AmountsToSendToAmm(routings[i], 0);
        }

        flashLoanRequiredAmount = 0;
        if (shouldArbitrage && amms.length > 1) {
            Structs.AmountsToSendToAmm[] memory arbitrages;
            (arbitrages, flashLoanRequiredAmount) = Arbitrage.arbitrageForY(amms, totalYGainedFromRouting);
            for (uint256 i = 0; i < amms.length; i++) {
                amountsToSendToAmms[i].x += arbitrages[i].x;
                amountsToSendToAmms[i].y += arbitrages[i].y;
            }
        }
    }


    function swapXforYWrapper(uint256[2][] memory ammsArray, uint256 amountOfX) public pure returns (Structs.AmountsToSendToAmm[] memory, uint256) {
        Structs.Amm[] memory amms = new Structs.Amm[](ammsArray.length);
        for (uint256 i = 0; i < ammsArray.length; ++i) {
            amms[i] = Structs.Amm(ammsArray[i][0], ammsArray[i][1]);
        }
        return swapXforY(amms, amountOfX);
    }


    //allow contract to recieve eth
    //not sure if we need it but might as well
    receive() external payable {
        console.log(msg.sender);
        // _WETH.deposit{value:msg.value}();
    }
}
