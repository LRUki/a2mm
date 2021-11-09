// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "./Structs.sol";
import "./SharedFunctions.sol";

library Route {

    function route(uint256[2][] memory ammsArray, uint256 amountOfX) public pure returns (Structs.XSellYGain[] memory xSellYGain, uint256 totalY, bool shouldArbitrage) {
        Structs.Amm[] memory amms = new Structs.Amm[](ammsArray.length);
        for (uint8 i = 0; i < ammsArray.length; ++i){
            amms[i] = Structs.Amm(ammsArray[i][0], ammsArray[i][1]);
        }
        return _route(amms, amountOfX);
    }
    // @param amms - All AMM liquidity pools (x, y)
    // @param amountOfX - how much of X we are willing to trade for Y
    // @return xSellYGain - amount of X we should sell at each AMM, ordered in the same way as the order of AMMs were passed in
    // @return totalY - how much of Y we get overall
    // @return shouldArbitrage - 'true' if we didn't spend enough of X to level all AMMs; otherwise 'false'
    function _route(Structs.Amm[] memory amms, uint256 amountOfX) private pure returns (Structs.XSellYGain[] memory xSellYGain, uint256 totalY, bool shouldArbitrage) {
//        assert(amms.length >= 2);

        // Sort the AMMs - worst to best in exchange rate.
        uint256[] memory sortedIndices = SharedFunctions.sortAmmArrayIndicesByExchangeRate(amms);
        Structs.Amm memory aggregatedPool = Structs.Amm(amms[0].x, amms[0].y);
        Structs.Amm memory worstAmm = amms[sortedIndices[0]];
        uint256 deltaX;

        totalY = 0;

        xSellYGain = new Structs.XSellYGain[](amms.length);
        Structs.Amm[] memory leveledAmms = new Structs.Amm[](amms.length);
        leveledAmms[0] = amms[sortedIndices[sortedIndices.length - 1]];
        uint256 elemsAddedToLeveledAmmIndices = 1;
        bool hasXRunOut = false;

        shouldArbitrage = false;
        // Send X to the best until we either run out of X to spend, or we level out this AMM with the next best AMM, whichever comes first.
        if (amms.length >= 2) {
            for (uint256 i = amms.length - 2; i >= 0; --i) {
                uint256 nextBestAmmIndex = sortedIndices[i];
                Structs.Amm memory nextBestAmm = amms[nextBestAmmIndex];
                deltaX = _howMuchXToSpendOnDifferentPricedAmms(aggregatedPool, nextBestAmm);
                // If it turns out that the AMM we are trying to level with has the same price, then no need to level it
                if (deltaX == 0) {
                    aggregatedPool.x += nextBestAmm.x;
                    aggregatedPool.y += nextBestAmm.y;
                    leveledAmms[elemsAddedToLeveledAmmIndices++] = amms[sortedIndices[i]];
                    continue;
                }

                // If we ran out of X to spend, then there might be an arbitrage opportunity - We can check by assuming that we had more X
                // and checking if we would have needed to swap more at the worse AMMs before swapping there.
                if (deltaX >= amountOfX) {
                    deltaX = amountOfX;
                    amountOfX = 0;
                    shouldArbitrage = true;
                    uint256 deltaXWorst;
                    deltaXWorst = _howMuchXToSpendOnDifferentPricedAmms(aggregatedPool, worstAmm);
                    if (deltaXWorst == 0) {
                        shouldArbitrage = false;
                    }
                    hasXRunOut = true;
                }
                totalY += SharedFunctions.quantityOfYForX(aggregatedPool, deltaX);

                //Otherwise, we just split our money across the leveled AMMs until the price reaches the next best AMM
                uint256[] memory splits = _howToSplitRoutingOnLeveledAmms(leveledAmms, deltaX);
                for (uint256 j = 0; j < elemsAddedToLeveledAmmIndices; ++j) {
                    xSellYGain[sortedIndices[j]].x += splits[j];
                    xSellYGain[sortedIndices[j]].y += SharedFunctions.quantityOfYForX(leveledAmms[j], splits[j]);
                }

                if (hasXRunOut) {
                    break;
                }

                amountOfX -= deltaX;
                leveledAmms[elemsAddedToLeveledAmmIndices++] = amms[sortedIndices[i]];
            }
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


    function _test_howMuchXToSpendOnDifferentPricedAmms() public pure returns (uint256 deltaX){
        uint256 x1 = 2000000000000;
        uint256 x2 = 2000000000000;
        uint256 y1 = 50000000000000;
        uint256 y2 = 50000000000000;
        //TODO: this formula is inexact. Making it exact might have a higher gas fee, so might be worth investigating if the higher potential profit covers the potentially higher gas fee
        deltaX = (1002 * (SharedFunctions.sqrt(x1 * y2) * SharedFunctions.sqrt(2257 * x1 * y2 / 1_000_000_000 + x2 * y1) - x1 * y2)) / (1000 * y2);
    }


    //(Appendix B, formula 17)
    // @notice - has potential overflow/underflow issues
    // @param betterAmm - the AMM which has a better price for Y; can represent an aggregation of multiple AMMs' liquidity pools.
    // @param worseAmm - the AMM which as a the worse price for Y.
    // @return deltaX - the amount of X we would need to spend on betterAmm until it levels with worseAmm
    function _howMuchXToSpendOnDifferentPricedAmms(Structs.Amm memory betterAmm, Structs.Amm memory worseAmm) private pure returns (uint256 deltaX) {
        uint256 x1;
        uint256 x2;
        uint256 y1;
        uint256 y2;

        x1 = betterAmm.x;
        x2 = worseAmm.x;
        y1 = betterAmm.y;
        y2 = worseAmm.y;
        //TODO: this formula is inexact. Making it exact might have a higher gas fee, so might be worth investigating if the higher potential profit covers the potentially higher gas fee
        deltaX = (1002 * (SharedFunctions.sqrt(x1 * y2) * SharedFunctions.sqrt(2257 * x1 * y2 / 1_000_000_000 + x2 * y1) - x1 * y2)) / (1000 * y2);
    }
}
