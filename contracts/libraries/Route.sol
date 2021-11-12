// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "./Structs.sol";
import "./SharedFunctions.sol";
import "hardhat/console.sol";

library Route {

    struct RouteHelper {
        uint256[] sortedIndices;
        Structs.Amm aggregatedPool;
        Structs.Amm worstAmm;
        uint256 deltaX;
        Structs.Amm[] leveledAmms;
        uint256 elemsAddedToLeveledAmmIndices;
        bool hasXRunOut;
    }


    //functions below are only for testing purposes
    //we need to expose a wrapper functions as there is an issue passing in Structs from javascript
    function routeWrapper(uint256[2][] memory ammsArray, uint256 amountOfX) public pure returns (Structs.XSellYGain[] memory, uint256, bool) {
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
    function route(Structs.Amm[] memory amms, uint256 amountOfX) public pure returns (Structs.XSellYGain[] memory xSellYGain, uint256 totalY, bool shouldArbitrage) {
        // assert(amms.length >= 1);

        xSellYGain = new Structs.XSellYGain[](amms.length);

        if (amms.length == 1) {
            totalY = SharedFunctions._quantityOfYForX(amms[0], amountOfX);
            xSellYGain[0].x = amountOfX;
            xSellYGain[0].y = totalY;
            return (xSellYGain, totalY, false);
        }

        RouteHelper memory routeHelper = RouteHelper(
        // Sort the AMMs - best to worst in exchange rate.
            SharedFunctions._sortAmmArrayIndicesByExchangeRate(amms)
        , Structs.Amm(amms[0].x, amms[0].y)
        , Structs.Amm(0, 0)
        , 0
        , new Structs.Amm[](amms.length)
        , 1
        , false);
        routeHelper.worstAmm = amms[routeHelper.sortedIndices[routeHelper.sortedIndices.length - 1]];

        totalY = 0;

        routeHelper.leveledAmms[0] = amms[routeHelper.sortedIndices[0]];

        shouldArbitrage = false;
        // Send X to the best until we either run out of X to spend, or we level out this AMM with the next best AMM, whichever comes first.
        for (uint256 j = amms.length - 1; j > 0; --j) {
            uint256 i = j - 1;
            uint256 nextBestAmmIndex = routeHelper.sortedIndices[i];
            Structs.Amm memory nextBestAmm = amms[nextBestAmmIndex];
            routeHelper.deltaX = _howMuchXToSpendToLevelAmms(routeHelper.aggregatedPool, nextBestAmm);
            // If it turns out that the AMM we are trying to level with has the same price, then no need to level it
            if (routeHelper.deltaX == 0) {
                routeHelper.aggregatedPool.x += nextBestAmm.x;
                routeHelper.aggregatedPool.y += nextBestAmm.y;
                routeHelper.leveledAmms[routeHelper.elemsAddedToLeveledAmmIndices++] = amms[routeHelper.sortedIndices[i]];
                continue;
            }

            // If we ran out of X to spend, then there might be an arbitrage opportunity - We can check by assuming that we had more X
            // and checking if we would have needed to swap more at the worse AMMs before swapping there.
            if (routeHelper.deltaX >= amountOfX) {
                routeHelper.deltaX = amountOfX;
                amountOfX = 0;
                shouldArbitrage = true;
                uint256 deltaXWorst;
                deltaXWorst = _howMuchXToSpendToLevelAmms(routeHelper.aggregatedPool, routeHelper.worstAmm);
                if (deltaXWorst == 0) {
                    shouldArbitrage = false;
                }
                routeHelper.hasXRunOut = true;
            }
            totalY += SharedFunctions._quantityOfYForX(routeHelper.aggregatedPool, routeHelper.deltaX);

            //Otherwise, we just split our money across the leveled AMMs until the price reaches the next best AMM
            uint256[] memory splits = _howToSplitRoutingOnLeveledAmms(routeHelper.leveledAmms, routeHelper.deltaX);
            for (uint256 j = 0; j < routeHelper.elemsAddedToLeveledAmmIndices; ++j) {
                uint256 yGain = SharedFunctions._quantityOfYForX(routeHelper.leveledAmms[j], splits[j]);
                xSellYGain[routeHelper.sortedIndices[j]].x += splits[j];
                xSellYGain[routeHelper.sortedIndices[j]].y += yGain;
                amms[routeHelper.sortedIndices[j]].x += splits[j];
                amms[routeHelper.sortedIndices[j]].y -= yGain;
            }

            if (routeHelper.hasXRunOut) {
                break;
            }

            amountOfX -= routeHelper.deltaX;
            routeHelper.leveledAmms[routeHelper.elemsAddedToLeveledAmmIndices++] = amms[routeHelper.sortedIndices[i]];
        }
    }


    // @notice - we might have overflow issues; also, it's possible that not all of 'deltaX' is spend due to how integer division rounds down
    // @param amms - all of the AMMs we are considering to route between
    // @param deltaX - how much of X we are looking to split among the AMMs
    // @return splits - an array telling us how much of X to send to each of the leveled AMMs
    function _howToSplitRoutingOnLeveledAmms(Structs.Amm[] memory amms, uint256 deltaX) private pure returns (uint256[] memory splits) {
        uint256 numberOfAmms = amms.length;
        splits = new uint256[](numberOfAmms);

        uint256 sumX = 0;
        for (uint256 i = 0; i < numberOfAmms; ++i) {
            sumX += amms[i].x;
        }
        // We just take the weighted average to know how to split our spending:
        for (uint256 i = 0; i < numberOfAmms; ++i) {
            splits[i] = (amms[i].x * deltaX) / sumX;
        }
    }


    // @notice - comes from Appendix B, formula 18; basically does a weighted average split across AMMs.
    // @param amm1 - the first of two AMMs we are looking to route between
    // @param amm2 - the second of two AMMs we are looking to route between
    // @return - the amounts of X to send to AMM1 and AMM2 respectively
    function _fractionToSplitRoutingOnEqualPrice(Structs.Amm memory amm1, Structs.Amm memory amm2, uint256 deltaX) private pure returns (uint256, uint256) {
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


    //(Appendix B, formula 17)
    // @notice - has potential overflow/underflow issues
    // @param betterAmm - the AMM which has a better price for Y; can represent an aggregation of multiple AMMs' liquidity pools.
    // @param worseAmm - the AMM which as a the worse price for Y.
    // @return deltaX - the amount of X we would need to spend on betterAmm until it levels with worseAmm
    function _howMuchXToSpendToLevelAmms(Structs.Amm memory betterAmm, Structs.Amm memory worseAmm) private pure returns (uint256 deltaX) {
        uint256 x1 = betterAmm.x;
        uint256 x2 = worseAmm.x;
        uint256 y1 = betterAmm.y;
        uint256 y2 = worseAmm.y;

        //TODO: this formula is inexact. Making it exact might have a higher gas fee, so might be worth investigating if the higher potential profit covers the potentially higher gas fee
        deltaX = (1002 * (SharedFunctions.sqrt(x1 * y2) * SharedFunctions.sqrt((x1 * y2 * 2257) / 1_000_000_000 + x2 * y1) - x1 * y2)) / (1000 * y2);
    }

    function howToSplitRoutingOnLeveledAmms(uint256[2][] memory ammsArray, uint256 deltaX) public pure returns (uint256[] memory) {
        Structs.Amm[] memory amms = new Structs.Amm[](ammsArray.length);
        for (uint8 i = 0; i < ammsArray.length; ++i) {
            amms[i] = Structs.Amm(ammsArray[i][0], ammsArray[i][1]);
        }
        return _howToSplitRoutingOnLeveledAmms(amms, deltaX);
    }

    function howMuchXToSpendToLevelAmms(uint256[2] memory betterAmmArray, uint256[2] memory worseAmmArray) public pure returns (uint256) {

        Structs.Amm memory betterAmm = Structs.Amm(betterAmmArray[0], betterAmmArray[1]);
        Structs.Amm memory worseAmm = Structs.Amm(worseAmmArray[0], worseAmmArray[1]);

        return _howMuchXToSpendToLevelAmms(betterAmm, worseAmm);
    }
}
