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
    ) external {
        require(
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn),
            "user needs to approve"
        );

        address[] memory factoriesSupportingTokenPair;
        uint256[] memory routingAmountsToSendToAmms;
        Structs.AmountsToSendToAmm[] memory arbitrageAmountsToSendToAmms;
        uint256 amountOfYtoFlashLoan;
        uint256 whereToLoanIndex;
        //TODO: since calculateRouteAndArbitarge is public, does it still take things by reference? If not, then the below lines of copying the amms can be deleted.
        // Copy the list of AMMs as internal calls are done by reference, and hence can edit the amms0 array
        Structs.Amm[] memory amms1;
        {
            Structs.Amm[] memory amms0;
            (factoriesSupportingTokenPair, amms0) = _factoriesWhichSupportPair(
                tokenIn,
                tokenOut
            );
            amms1 = new Structs.Amm[](amms0.length);
            for (uint256 i = 0; i < amms0.length; i++) {
                (amms1[i].x, amms1[i].y) = (amms0[i].x, amms0[i].y);
            }

            require(
                factoriesSupportingTokenPair.length > 0,
                "no amms avilable"
            );

            (
                routingAmountsToSendToAmms,
                arbitrageAmountsToSendToAmms,
                amountOfYtoFlashLoan,
                whereToLoanIndex
            ) = calculateRouteAndArbitarge(amms0, amountIn);
        }

        bool didArbitrage = false;
        for (uint256 i = 0; i < factoriesSupportingTokenPair.length; ++i) {
            if (arbitrageAmountsToSendToAmms[i].y != 0) {
                didArbitrage = true;
                break;
            }
        }

        //TODO: handle integer division error (there is leftover X in the user's account)
        uint256 amountOut = 0;
        if (didArbitrage) {
            uint256 yRequired = _calculateTotalYOut(
                amms1,
                routingAmountsToSendToAmms,
                arbitrageAmountsToSendToAmms
            );
            amountOut = yRequired - amountOfYtoFlashLoan;
            address whereToLoan = factoriesSupportingTokenPair[
                whereToLoanIndex
            ];
            flashSwap(
                tokenIn,
                tokenOut,
                SharedFunctions.quantityOfYForX(
                    amms1[whereToLoanIndex],
                    routingAmountsToSendToAmms[whereToLoanIndex] +
                        arbitrageAmountsToSendToAmms[whereToLoanIndex].x
                ),
                whereToLoan,
                amountIn,
                factoriesSupportingTokenPair,
                routingAmountsToSendToAmms,
                arbitrageAmountsToSendToAmms
            );
            require(
                IERC20(tokenOut).balanceOf(address(this)) == amountOut,
                "Predicted amountOut != actual"
            );
        } else {
            for (uint256 i = 0; i < factoriesSupportingTokenPair.length; ++i) {
                assert(arbitrageAmountsToSendToAmms[i].x == 0);
                if (routingAmountsToSendToAmms[i] > 0) {
                    amountOut += executeSwap(
                        factoriesSupportingTokenPair[i],
                        tokenIn,
                        tokenOut,
                        routingAmountsToSendToAmms[i]
                    );
                }
            }
        }
        require(
            IERC20(tokenOut).transfer(msg.sender, amountOut),
            "token failed to be sent back"
        );
        emit SwapEvent(amountIn, amountOut);
    }

    // @param amms - the state of the AMMs we are considering the transactions on
    // @param routes - the amounts of X we are to trade for Y (usually obtained from calling the route() function)
    // @param arbitrages - the amounts of X and Y we are using for arbitrage (usually obtained from calling the arbitrageForY() function)
    // @return totalOut - assuming that arbitrage did not need a flash loan, this will be the amount of Y the user would get for making these trades
    function _calculateTotalYOut(
        Structs.Amm[] memory amms,
        uint256[] memory routes,
        Structs.AmountsToSendToAmm[] memory arbitrages
    ) private pure returns (uint256 totalOut) {
        totalOut = 0;
        uint256 ySum = 0;
        for (uint256 i = 0; i < amms.length; i++) {
            ySum += arbitrages[i].y;
            if (routes[i] + arbitrages[i].x != 0) {
                totalOut += SharedFunctions.quantityOfYForX(
                    amms[i],
                    routes[i] + arbitrages[i].x
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
    ) external view returns (uint256) {
        (, Structs.Amm[] memory amms0) = _factoriesWhichSupportPair(
            tokenIn,
            tokenOut
        );

        //TODO: since calculateRouteAndArbitarge is public, does it still take things by reference? If not, then the below lines of copying the amms can be deleted.
        // Copy the list of AMMs as internal calls are done by reference, and hence can edit the amms0 array
        Structs.Amm[] memory amms1 = new Structs.Amm[](amms0.length);
        for (uint256 i = 0; i < amms0.length; i++) {
            (amms1[i].x, amms1[i].y) = (amms0[i].x, amms0[i].y);
        }

        (
            uint256[] memory routes,
            Structs.AmountsToSendToAmm[] memory arbitrages,
            uint256 flashLoanRequired,

        ) = calculateRouteAndArbitarge(amms0, amountIn);

        return
            _calculateTotalYOut(amms1, routes, arbitrages) - flashLoanRequired;
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
