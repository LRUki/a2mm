// SPDX-License-Identifier: MIT
//solhint-disable-next-line
pragma solidity 0.6.6 || 0.8.3;
//Solidity 0.8 already comes with ABIEncoderV2 out of the box; however, 0.6.6 doesn't.
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
    ) public {
        swapWithSlippage(tokenIn, tokenOut, amountIn, uint256(0));
    }

    function swapWithSlippage(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minimumAcceptedAmount
    ) public {
        require(
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn),
            "user needs to approve"
        );

        // Copy the list of AMMs as internal calls are done by reference, and hence can edit the amms0 array
        SwapHelper memory swapHelper;
        {
            Structs.Amm[] memory amms0;
            (
                swapHelper.factoriesSupportingTokenPair,
                amms0
            ) = _factoriesWhichSupportPair(tokenIn, tokenOut);
            swapHelper.amms1 = new Structs.Amm[](amms0.length);
            for (uint256 i = 0; i < amms0.length; i++) {
                (swapHelper.amms1[i].x, swapHelper.amms1[i].y) = (
                    amms0[i].x,
                    amms0[i].y
                );
            }

            require(
                swapHelper.factoriesSupportingTokenPair.length > 0,
                "no AMMs avilable"
            );

            (
                swapHelper.amountsToSendToAmms,

            ) = calculateRouteAndArbitrageCombined(amms0, amountIn);
        }

        (
            swapHelper.amountOut,
            swapHelper.ySum,
            swapHelper.noOfXToYSwaps
        ) = _calculateTotalYOut(
            swapHelper.amms1,
            swapHelper.amountsToSendToAmms
        );
        require(
            swapHelper.amountOut > minimumAcceptedAmount,
            "Slippage tolerance exceeded"
        );

        if (swapHelper.ySum > 0) {
            swapHelper.xToYSwaps = new uint256[](swapHelper.noOfXToYSwaps);
            swapHelper.xToYSwapsFactories = new address[](
                swapHelper.noOfXToYSwaps
            );
            uint256 j = 0;
            for (uint256 i = 0; i < swapHelper.amms1.length; i++) {
                if (swapHelper.amountsToSendToAmms[i].x != 0) {
                    require(
                        swapHelper.amountsToSendToAmms[i].y == 0,
                        "Can't swap both X and Y"
                    );
                    swapHelper.xToYSwaps[j] = swapHelper
                        .amountsToSendToAmms[i]
                        .x;
                    swapHelper.xToYSwapsFactories[j++] = swapHelper
                        .factoriesSupportingTokenPair[i];
                }
            }
            flashSwap(
                tokenIn,
                tokenOut,
                amountIn,
                swapHelper.noOfXToYSwaps,
                swapHelper.factoriesSupportingTokenPair,
                swapHelper.amountsToSendToAmms,
                swapHelper.amms1,
                swapHelper.xToYSwaps,
                swapHelper.xToYSwapsFactories
            );
        } else {
            for (
                uint256 i = 0;
                i < swapHelper.factoriesSupportingTokenPair.length;
                ++i
            ) {
                if (swapHelper.amountsToSendToAmms[i].x > 0) {
                    executeSwap(
                        swapHelper.factoriesSupportingTokenPair[i],
                        tokenIn,
                        tokenOut,
                        swapHelper.amountsToSendToAmms[i].x
                    );
                }
            }
        }

        require(
            IERC20(tokenOut).balanceOf(address(this)) == swapHelper.amountOut,
            "Predicted amountOut != actual"
        );
        require(
            IERC20(tokenOut).transfer(msg.sender, swapHelper.amountOut),
            "token failed to be sent back"
        );
        emit SwapEvent(amountIn, swapHelper.amountOut);
    }

    // @param amms - the state of the AMMs we are considering the transactions on
    // @param routes - the amounts of X we are to trade for Y (usually obtained from calling the route() function)
    // @param arbitrages - the amounts of X and Y we are using for arbitrage (usually obtained from calling the arbitrageForY() function)
    // @return totalOut - assuming that arbitrage did not need a flash loan, this will be the amount of Y the user would get for making these trades
    // @return ySum - The total amount of Y exchanged for X over the AMMs
    function _calculateTotalYOut(
        Structs.Amm[] memory amms,
        uint256[] memory routes,
        Structs.AmountsToSendToAmm[] memory arbitrages
    )
        private
        pure
        returns (
            uint256 totalOut,
            uint256 ySum,
            uint256 noOfXToYSwaps
        )
    {
        totalOut = 0;
        ySum = 0;
        noOfXToYSwaps = 0;
        for (uint256 i = 0; i < amms.length; i++) {
            ySum += arbitrages[i].y;
            if (routes[i] + arbitrages[i].x != 0) {
                noOfXToYSwaps++;
                totalOut += SharedFunctions.quantityOfYForX(
                    amms[i],
                    routes[i] + arbitrages[i].x
                );
            }
        }

        require(totalOut >= ySum, "subtraction overflow");
        totalOut -= ySum;
    }

    // @param amms - the state of the AMMs we are considering the transactions on
    // @param amountsToSendToAmms - the amounts of X and Y we are using
    // @return totalOut - assuming that arbitrage did not need a flash loan, this will be the amount of Y the user would get for making these trades
    // @return ySum - The total amount of Y exchanged for X over the AMMs
    function _calculateTotalYOut(
        Structs.Amm[] memory amms,
        Structs.AmountsToSendToAmm[] memory amountsToSendToAmms
    )
        private
        pure
        returns (
            uint256 totalOut,
            uint256 ySum,
            uint256 noOfXToYSwaps
        )
    {
        totalOut = 0;
        ySum = 0;
        noOfXToYSwaps = 0;
        for (uint256 i = 0; i < amms.length; i++) {
            ySum += amountsToSendToAmms[i].y;
            if (amountsToSendToAmms[i].x != 0) {
                noOfXToYSwaps++;
                totalOut += SharedFunctions.quantityOfYForX(
                    amms[i],
                    amountsToSendToAmms[i].x
                );
            }
        }

        require(totalOut >= ySum, "subtraction overflow");
        totalOut -= ySum;
    }

    // @param tokenIn - the token which the user will provide/is wanting to sell
    // @param tokenOut - the token which the user will be given/is wanting to buy
    // @param amountIn - how much of tokenIn the user is wanting to exchange for totalOut amount of tokenOut
    // @return totalOut - the amount of token the user will get in return for amountIn of tokenIn
    function simulateSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 totalGain) {
        (, Structs.Amm[] memory amms0) = _factoriesWhichSupportPair(
            tokenIn,
            tokenOut
        );

        // Copy the list of AMMs as internal calls are done by reference, and hence can edit the amms0 array
        Structs.Amm[] memory amms1 = new Structs.Amm[](amms0.length);
        for (uint256 i = 0; i < amms0.length; i++) {
            (amms1[i].x, amms1[i].y) = (amms0[i].x, amms0[i].y);
        }

        (
            uint256[] memory routes,
            Structs.AmountsToSendToAmm[] memory arbitrages,

        ) = calculateRouteAndArbitrage(amms0, amountIn);

        (totalGain, , ) = _calculateTotalYOut(amms1, routes, arbitrages);
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
            intermediateToken,
            arbitragingFor
        );
        Structs.Amm[] memory amms1 = new Structs.Amm[](amms0.length);
        for (uint256 i = 0; i < amms0.length; i++) {
            (amms1[i].x, amms1[i].y) = (amms0[i].x, amms0[i].y);
        }

        Structs.AmountsToSendToAmm[] memory arbitrages;
        (arbitrages, tokenInRequired) = Arbitrage.arbitrageForY(amms0, 0);
        arbitrageGain = 0;
        for (uint256 i = 0; i < amms0.length; i++) {
            arbitrageGain += SharedFunctions.quantityOfYForX(
                amms1[i],
                arbitrages[i].x
            );
        }
    }

    // @param amountOfX - how much the user is willing to trade
    // @return amountsToSendToAmms - the pair of values indicating how much of X and Y should be sent to each AMM \
    // (ordered in the same way as the AMMs were passed in)
    // @return amountOfYtoFlashLoan - how big of a flash loan we would need to take out to successfully \
    // complete the transation. This is done for the arbitrage step.
    function calculateRouteAndArbitrageCombined(
        Structs.Amm[] memory amms,
        uint256 amountOfX
    )
        public
        pure
        returns (
            Structs.AmountsToSendToAmm[] memory amountsToSendToAmms,
            uint256 amountOfYtoFlashLoan
        )
    {
        uint256[] memory routingAmountsToSendToAmms;
        (
            routingAmountsToSendToAmms,
            amountsToSendToAmms,
            amountOfYtoFlashLoan
        ) = calculateRouteAndArbitrage(amms, amountOfX);

        for (uint256 i = 0; i < amms.length; i++) {
            amountsToSendToAmms[i].x += routingAmountsToSendToAmms[i];
        }
    }

    // @param amountOfX - how much the user is willing to trade
    // @return routingAmountsToSendToAmms - the amounts of X we have decided needs to be sent to each AMM for \
    // optimal routing
    // @return arbitrageAmountsToSendToAmms - the pair of values indicating how much of X and Y should be sent \
    // to each AMM (ordered in the same way as the AMMs were passed in) according to arbitrage
    // @return amountOfYtoFlashLoan - how big of a flash loan we would need to take out to successfully \
    // complete the transation. This is done for the arbitrage step.
    function calculateRouteAndArbitrage(
        Structs.Amm[] memory amms,
        uint256 amountOfX
    )
        public
        pure
        returns (
            uint256[] memory routingAmountsToSendToAmms,
            Structs.AmountsToSendToAmm[] memory arbitrageAmountsToSendToAmms,
            uint256 amountOfYtoFlashLoan
        )
    {
        bool shouldArbitrage;

        uint256 totalYGainedFromRouting;
        (
            routingAmountsToSendToAmms,
            totalYGainedFromRouting,
            shouldArbitrage,
            amms
        ) = Route.route(amms, amountOfX);

        amountOfYtoFlashLoan = 0;
        arbitrageAmountsToSendToAmms = new Structs.AmountsToSendToAmm[](
            amms.length
        );
        if (shouldArbitrage && amms.length > 1) {
            (arbitrageAmountsToSendToAmms, amountOfYtoFlashLoan) = Arbitrage
                .arbitrageForY(amms, totalYGainedFromRouting);
        }
    }

    function calculateRouteAndArbitrageWrapper(
        uint256[2][] memory ammsArray,
        uint256 amountOfX
    )
        public
        pure
        returns (
            uint256[] memory,
            Structs.AmountsToSendToAmm[] memory,
            uint256
        )
    {
        Structs.Amm[] memory amms = new Structs.Amm[](ammsArray.length);
        for (uint256 i = 0; i < ammsArray.length; ++i) {
            amms[i] = Structs.Amm(ammsArray[i][0], ammsArray[i][1]);
        }
        return calculateRouteAndArbitrage(amms, amountOfX);
    }

    //allow contract to recieve eth
    //not sure if we need it but might as well
    //solhint-disable-next-line
    receive() external payable {}

    struct SwapHelper {
        Structs.Amm[] amms1;
        uint256 amountOut;
        uint256 ySum;
        address[] factoriesSupportingTokenPair;
        Structs.AmountsToSendToAmm[] amountsToSendToAmms;
        uint256 noOfXToYSwaps;
        uint256[] xToYSwaps;
        address[] xToYSwapsFactories;
    }
}
