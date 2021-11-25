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
    Structs.AmountsToSendToAmm[3] private _amountsToSendToAmm;
    event SwapEvent(uint256 amountIn, uint256 amountOut);

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external {
        require(
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn),
            "user needs to approve"
        );
        (
            address[] memory factoriesSupportingTokenPair,
            Structs.Amm[] memory amms
        ) = _factoriesWhichSupportPair(tokenIn, tokenOut);

        require(factoriesSupportingTokenPair.length > 0, "no amms avilable");

        (
            uint256[] memory routingAmountsToSendToAmms,
            Structs.AmountsToSendToAmm[] memory arbitrageAmountsToSendToAmms,
            uint256 amountOfYtoFlashLoan,
            uint256 whereToLoanIndex
        ) = calculateRouteAndArbitarge(amms, amountIn);

        uint256 ySum = 0;
        for (uint256 i = 0; i < factoriesSupportingTokenPair.length; ++i) {
            ySum += arbitrageAmountsToSendToAmms[i].y;
        }

        //handle integer division error
        uint256 amountOut = 0;
        if (ySum > 0) {
            //TODO: how to get the amountOut from flashSwap?
            console.log("Arbitarge (requires flashswap anyway) ");
            address whereToLoan = factoriesSupportingTokenPair[
                whereToLoanIndex
            ];
            flashSwap(
                tokenIn,
                tokenOut,
                ySum,
                whereToLoan,
                factoriesSupportingTokenPair,
                routingAmountsToSendToAmms,
                arbitrageAmountsToSendToAmms
            );
        } else {
            console.log("only Routing");
            for (uint256 i = 0; i < factoriesSupportingTokenPair.length; ++i) {
                uint256 xToSend = arbitrageAmountsToSendToAmms[i].x +
                    routingAmountsToSendToAmms[i];
                if (xToSend > 0) {
                    amountOut += executeSwap(
                        factoriesSupportingTokenPair[i],
                        tokenIn,
                        tokenOut,
                        xToSend
                    );
                }
            }
        }

        console.log(amountOut, IERC20(tokenOut).balanceOf(address(this)));
        require(
            IERC20(tokenOut).transfer(msg.sender, amountOut),
            "token failed to be sent back"
        );
        emit SwapEvent(amountIn, amountOut);
    }

    // @param tokenIn - the token which the user will provide/is wanting to sell
    // @param tokenOut - the token which the user will be given/is wanting to buy
    // @param amountIn - how much of tokenIn the user is wanting to exchange for totalOut amount of tokenOut
    // @return totalOut - the amount of token the user will get in return for amountIn of tokenIn
    function simulateSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 totalOut) {
        (, Structs.Amm[] memory amms0) = _factoriesWhichSupportPair(
            tokenIn,
            tokenOut
        );
        Structs.Amm[] memory amms1 = new Structs.Amm[](amms0.length);
        for (uint256 i = 0; i < amms0.length; i++) {
            (amms1[i].x, amms1[i].y) = (amms0[i].x, amms0[i].y);
        }

        totalOut = 0;
        (
            uint256[] memory routes,
            Structs.AmountsToSendToAmm[] memory arbitrages,
            uint256 flashLoanRequired,
            uint256 whereToLoanIndex
        ) = calculateRouteAndArbitarge(amms0, amountIn);
        for (uint256 i = 0; i < amms0.length; i++) {
            totalOut += SharedFunctions.quantityOfYForX(
                amms1[i],
                routes[i] + arbitrages[i].x
            );
        }
        return totalOut - flashLoanRequired;
    }

    // @param arbitragingFor - the token which the user will provide/is wanting to arbitrage for
    // @param intermediateToken - the token which the user is wanting to user during the arbitrage step \
    // (arbitragingFor -> intermediateToken -> arbitragingFor)
    // @return arbitrageGain - how much of token 'arbitragingFor' the user will gain for executing this arbitrage
    // @return tokenInRequired - how much of 'arbitragingFor' the user would be required to own to complete the \
    // arbitrage without a flash loan, using our arbitraging algorithm
    function simulateArbitrage(
        address arbitragingFor,
        address intermediateToken
    ) external view returns (uint256 arbitrageGain, uint256 tokenInRequired) {
        (, Structs.Amm[] memory amms0) = _factoriesWhichSupportPair(
            arbitragingFor,
            intermediateToken
        );
        Structs.Amm[] memory amms1 = new Structs.Amm[](amms0.length);
        for (uint256 i = 0; i < amms0.length; i++) {
            (amms1[i].x, amms1[i].y) = (amms0[i].x, amms0[i].y);
        }

        Structs.AmountsToSendToAmm[] memory arbitrages;
        (arbitrages, tokenInRequired, ) = Arbitrage.arbitrageForY(amms0, 0);
        arbitrageGain = 0;
        for (uint256 i = 0; i < amms0.length; i++) {
            arbitrageGain += SharedFunctions.quantityOfYForX(
                amms1[i],
                arbitrages[i].x
            );
        }
    }

    // @notice - for now, only the first two AMMs in the list will actually be considered for anything
    // @param amountOfX - how much the user is willing to trade
    // @return amountsToSendToAmms - the pair of values indicating how much of X and Y should be sent to each AMM \
    // (ordered in the same way as the AMMs were passed in)
    // @return flashLoanRequiredAmount - how big of a flash loan we would need to take out to successfully \
    // complete the transation. This is done for the arbitrage step.
    function calculateRouteAndArbitarge(
        Structs.Amm[] memory amms,
        uint256 amountOfX
    )
        public
        pure
        returns (
            uint256[] memory routingAmountsToSendToAmms,
            Structs.AmountsToSendToAmm[] memory arbitrageAmountsToSendToAmms,
            uint256 amountOfYtoFlashLoan,
            uint256 whereToLoanIndex
        )
    {
        whereToLoanIndex = Arbitrage.MAX_INT;
        bool shouldArbitrage;

        uint256 totalYGainedFromRouting;
        (
            routingAmountsToSendToAmms,
            totalYGainedFromRouting,
            shouldArbitrage,
            amms
        ) = Route.route(amms, amountOfX);

        amountOfYtoFlashLoan = 0;
        arbitrageAmountsToSendToAmms = new Structs.AmountsToSendToAmm[](1);
        arbitrageAmountsToSendToAmms[0] = Structs.AmountsToSendToAmm(0, 0);
        if (shouldArbitrage && amms.length > 1) {
            Structs.AmountsToSendToAmm[] memory arbitrages;
            (
                arbitrageAmountsToSendToAmms,
                amountOfYtoFlashLoan,
                whereToLoanIndex
            ) = Arbitrage.arbitrageForY(amms, totalYGainedFromRouting);
        }
    }

    function calculateRouteAndArbitargeWrapper(
        uint256[2][] memory ammsArray,
        uint256 amountOfX
    )
        public
        pure
        returns (
            uint256[] memory,
            Structs.AmountsToSendToAmm[] memory,
            uint256,
            uint256
        )
    {
        Structs.Amm[] memory amms = new Structs.Amm[](ammsArray.length);
        for (uint256 i = 0; i < ammsArray.length; ++i) {
            amms[i] = Structs.Amm(ammsArray[i][0], ammsArray[i][1]);
        }
        return calculateRouteAndArbitarge(amms, amountOfX);
    }

    //allow contract to recieve eth
    //not sure if we need it but might as well
    //solhint-disable-next-line
    receive() external payable {}
}
