// SPDX-License-Identifier: MIT
//solhint-disable-next-line
pragma solidity 0.6.6||0.8.3;
pragma experimental ABIEncoderV2;

import "./Structs.sol";
import "./SharedFunctions.sol";

library Route {
    //functions below are only for testing purposes
    //we need to expose a wrapper functions as there is an issue passing in Structs from javascript
    function routeWrapper(uint256[2][] memory ammsArray, uint256 amountOfX)
        public
        view
        returns (
            Structs.XSellYGain[] memory,
            uint256,
            bool
        )
    {
        Structs.Amm[] memory amms = new Structs.Amm[](ammsArray.length);
        for (uint256 i = 0; i < ammsArray.length; ++i) {
            amms[i] = Structs.Amm(ammsArray[i][0], ammsArray[i][1]);
        }
        return route(amms, amountOfX);
    }

    // @param amms - All AMM liquidity pools (x, y)
    // @param amountOfX - how much of X we are willing to trade for Y
    // @return xSellYGain - amount of X we should sell at each AMM, ordered in the same way as the order of AMMs were passed in
    // @return totalY - how much of Y we get overall
    // @return shouldArbitrage - 'true' if we didn't spend enough of X to level all AMMs; otherwise 'false'
    function route(Structs.Amm[] memory amms, uint256 amountOfX)
        public
        view
        returns (
            Structs.XSellYGain[] memory xSellYGain,
            uint256 totalY,
            bool shouldArbitrage
        )
    {
        require(amms.length >= 1, "Need at least 1 AMM in 'amms'");

        xSellYGain = new Structs.XSellYGain[](amms.length);

        if (amms.length == 1) {
            totalY = SharedFunctions.quantityOfYForX(amms[0], amountOfX);
            xSellYGain[0].x = amountOfX;
            xSellYGain[0].y = totalY;
            return (xSellYGain, totalY, false);
        }

        RouteHelper memory routeHelper = RouteHelper(
            // Sort the AMMs - best to worst in exchange rate.
            SharedFunctions._sortAmmArrayIndicesByExchangeRate(amms),
            Structs.Amm(amms[0].x, amms[0].y),
            Structs.Amm(0, 0),
            0,
            new Structs.Amm[](amms.length),
            1,
            false
        );
        routeHelper.worstAmm = amms[
            routeHelper.sortedIndices[routeHelper.sortedIndices.length - 1]
        ];

        totalY = 0;

        routeHelper.leveledAmms[0] = amms[routeHelper.sortedIndices[0]];

        shouldArbitrage = false;
        // Send X to the best until we either run out of X to spend, or we level out this AMM with the next best AMM, whichever comes first.
        for (uint256 j = amms.length - 1; j > 0; --j) {
            uint256 i = j - 1;
            uint256 nextBestAmmIndex = routeHelper.sortedIndices[i];
            Structs.Amm memory nextBestAmm = amms[nextBestAmmIndex];
            routeHelper.deltaX = SharedFunctions.howMuchXToSpendToLevelAmms(
                routeHelper.aggregatedPool,
                nextBestAmm
            );
            // If it turns out that the AMM we are trying to level with has the same price, then no need to level it
            if (routeHelper.deltaX == 0) {
                routeHelper.aggregatedPool.x += nextBestAmm.x;
                routeHelper.aggregatedPool.y += nextBestAmm.y;
                routeHelper.leveledAmms[
                    routeHelper.elemsAddedToLeveledAmmIndices++
                ] = amms[routeHelper.sortedIndices[i]];
                continue;
            }

            // If we ran out of X to spend, then there might be an arbitrage opportunity - We can check by assuming that we had more X
            // and checking if we would have needed to swap more at the worse AMMs before swapping there.
            if (routeHelper.deltaX >= amountOfX) {
                routeHelper.deltaX = amountOfX;
                amountOfX = 0;
                shouldArbitrage = true;
                uint256 deltaXWorst;
                deltaXWorst = SharedFunctions.howMuchXToSpendToLevelAmms(
                    routeHelper.aggregatedPool,
                    routeHelper.worstAmm
                );
                if (deltaXWorst == 0) {
                    shouldArbitrage = false;
                }
                routeHelper.hasXRunOut = true;
            }
            totalY += SharedFunctions.quantityOfYForX(
                routeHelper.aggregatedPool,
                routeHelper.deltaX
            );

            //Otherwise, we just split our money across the leveled AMMs until the price reaches the next best AMM
            uint256[] memory splits = SharedFunctions
                .howToSplitRoutingOnLeveledAmms(
                    routeHelper.leveledAmms,
                    routeHelper.deltaX
                );
            for (
                uint256 k = 0;
                k < routeHelper.elemsAddedToLeveledAmmIndices;
                ++k
            ) {
                uint256 yGain = SharedFunctions.quantityOfYForX(
                    routeHelper.leveledAmms[k],
                    splits[k]
                );
                xSellYGain[routeHelper.sortedIndices[k]].x += splits[k];
                xSellYGain[routeHelper.sortedIndices[k]].y += yGain;
                amms[routeHelper.sortedIndices[k]].x += splits[k];
                amms[routeHelper.sortedIndices[k]].y -= yGain;
            }

            if (routeHelper.hasXRunOut) {
                break;
            }

            amountOfX -= routeHelper.deltaX;
            routeHelper.leveledAmms[
                routeHelper.elemsAddedToLeveledAmmIndices++
            ] = amms[routeHelper.sortedIndices[i]];
        }
    }

    // @notice - comes from Appendix B, formula 18; basically does a weighted average split across AMMs.
    // @param amm1 - the first of two AMMs we are looking to route between
    // @param amm2 - the second of two AMMs we are looking to route between
    // @return - the amounts of X to send to AMM1 and AMM2 respectively
    function _fractionToSplitRoutingOnEqualPrice(
        Structs.Amm memory amm1,
        Structs.Amm memory amm2,
        uint256 deltaX
    ) private view returns (uint256, uint256) {
        uint256 amm1Part = (deltaX * amm1.x) / (amm1.x + amm2.x);
        uint256 amm2Part = (deltaX * amm2.x) / (amm1.x + amm2.x);
        uint256 leftover = deltaX - amm1Part - amm2Part;
        // Due to how integer division works, we might have some of deltaX unspent. This error will grow
        // as we do this process multiple times, so we will try to correct for it slightly by adding the leftover
        // to the pool with more liquidity:
        if (amm1.x >= amm2.x) {
            amm1Part += leftover;
        } else {
            amm2Part += leftover;
        }
        return (amm1Part, amm2Part);
    }

    struct RouteHelper {
        uint256[] sortedIndices;
        Structs.Amm aggregatedPool;
        Structs.Amm worstAmm;
        uint256 deltaX;
        Structs.Amm[] leveledAmms;
        uint256 elemsAddedToLeveledAmmIndices;
        bool hasXRunOut;
    }
}
