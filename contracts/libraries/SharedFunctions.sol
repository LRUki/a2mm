// SPDX-License-Identifier: MIT
//solhint-disable-next-line
pragma solidity 0.6.6 || 0.8.3;
pragma experimental ABIEncoderV2;

import "./Structs.sol";


library SharedFunctions {

    // @param amms - the AMMs whose pools we want to aggregate (i.e. add together element-wise)
    // @returns aggregatePool - the aggregated pool
    function aggregateAmmPools(Structs.Amm[] memory amms) public pure returns (Structs.Amm memory aggregatePool) {
        aggregatePool = Structs.Amm(0, 0);
        for (uint256 i = 0; i < amms.length; ++i) {
            aggregatePool.x += amms[i].x;
            aggregatePool.y += amms[i].y;
        }
    }


    // @param amm1 - the first AMM whose pool we want to aggregate (i.e. add together element-wise)
    // @param amm2 - the second AMM whose pool we want to aggregate
    // @returns aggregatePool - the aggregated pool
    function aggregateAmmPools(Structs.Amm memory amm1, Structs.Amm memory amm2) public pure returns (Structs.Amm memory aggregatePool) {
        aggregatePool = Structs.Amm(amm1.x + amm2.x, amm1.y + amm2.y);
    }


    // @notice - this is the Babylonian/Heron's method of finding the square root. It returns an integer value!
    // @param x - the number whose square root we want to find
    // @return y - the square rooted number (as integer)
    function sqrt(uint256 x) public pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }


    // @notice - has potential issues of underflow or overflow.
    // @param x - the amount of X in the AMM we are looking to trade at
    // @param y - the amount of Y in the AMM we are looking to trade at
    // @param dx - how much of X we are willing to potentially spend
    // @return amountOut - how much of Y we would get if we traded x of X for Y
    function quantityOfYForX(uint256 x, uint256 y, uint256 dx) public pure returns (uint256 amountOut) {
//        require(dx > 0, "Insufficient 'dx'");
        require(y > 0, "Insufficient liquidity: y");
        if (dx == 0) {
            return 0;
        }
        uint amountInWithFee = dx * 997;
        uint numerator = amountInWithFee * y;
        uint denominator = x * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }


    function quantityOfYForX(Structs.Amm memory amm, uint256 dx) public pure returns (uint256){
        return quantityOfYForX(amm.x, amm.y, dx);
    }


    function quantityOfXForY(Structs.Amm memory amm, uint256 dy) public pure returns (uint256){
        return quantityOfYForX(amm.y, amm.x, dy);
    }


    function _howMuchToSpendToLevelAmms(uint256 t11, uint256 t12, uint256 t21, uint256 t22) private pure returns (uint256) {
        //TODO: this formula is inexact. Making it exact might have a higher gas fee, so might be worth investigating if the higher potential profit covers the potentially higher gas fee
        require(t12 > 0 && t22 > 0, "Liquidity must be more than 0.");
        uint256 left = sqrt(t11 * t22) * sqrt((t11 * t22 * 2257) / 1_000_000_000 + t12 * t21);
        uint256 right = t11 * t22;
        if (right >= left) {
            //We can't level these any more than they are
            return 0;
        }
        return (1002 * (left - right)) / (1000 * t22);
    }


    //(Appendix B, formula 17)
    // @notice - has potential overflow/underflow issues
    // @param betterAmm - the AMM which has a better price for Y; can represent an aggregation of multiple AMMs' liquidity pools.
    // @param worseAmm - the AMM which as a the worse price for Y, i.e. Y/X is lower here than on betterAmm
    // @return deltaX - the amount of X we would need to spend on betterAmm until it levels with worseAmm
    function howMuchXToSpendToLevelAmms(Structs.Amm memory betterAmm, Structs.Amm memory worseAmm) public pure returns (uint256) {
        uint256 x1 = betterAmm.x;
        uint256 x2 = worseAmm.x;
        uint256 y1 = betterAmm.y;
        uint256 y2 = worseAmm.y;

        return _howMuchToSpendToLevelAmms(x1, x2, y1, y2);
    }


    function howMuchXToSpendToLevelAmmsWrapper(uint256[2] memory betterAmmArray, uint256[2] memory worseAmmArray) public pure returns (uint256) {

        Structs.Amm memory betterAmm = Structs.Amm(betterAmmArray[0], betterAmmArray[1]);
        Structs.Amm memory worseAmm = Structs.Amm(worseAmmArray[0], worseAmmArray[1]);

        return howMuchXToSpendToLevelAmms(betterAmm, worseAmm);
    }


    //(Appendix B, formula 17)
    // @notice - has potential overflow/underflow issues
    // @param betterAmm - the AMM which has a better price for X; can represent an aggregation of multiple AMMs' liquidity pools.
    // @param worseAmm - the AMM which as a the worse price for X, i.e. X/Y is lower here than on betterAmm
    // @return - the amount of Y we would need to spend on betterAmm until it levels with worseAmm
    function howMuchYToSpendToLevelAmms(Structs.Amm memory betterAmm, Structs.Amm memory worseAmm) public pure returns (uint256) {
        uint256 x1 = betterAmm.x;
        uint256 x2 = worseAmm.x;
        uint256 y1 = betterAmm.y;
        uint256 y2 = worseAmm.y;

        return _howMuchToSpendToLevelAmms(y1, y2, x1, x2);
    }


    // @notice - uses insertion sort, as we don't expect to have a large list (I think Arthur mentioned only using 4-5 maximum)
    // @param amms - all of the AMMs we are considering (either for routing or arbitrage)
    // @return indices - the indices of the amms array sorted by their exchange rate in ascending Y/X order
    function sortAmmArrayIndicesByExchangeRate(Structs.Amm[] memory amms) public pure returns (uint256[] memory indices) {
        indices = new uint256[](amms.length);
        for (uint256 i = 0; i < amms.length; i++) {
            indices[i] = i;
        }

        uint256 n = amms.length;
        for (uint256 i = 1; i < n; ++i) {
            uint256 tmp = indices[i];
            uint256 j = i;
            while (j > 0 && amms[tmp].y * amms[indices[j - 1]].x < amms[indices[j - 1]].y * amms[tmp].x) {
                indices[j] = indices[j - 1];
                --j;
            }
            indices[j] = tmp;
        }
    }


    function howToSplitRoutingOnLeveledAmmsWrapper(uint256[2][] memory ammsArray, uint256 deltaX) public pure returns (uint256[] memory) {
        Structs.Amm[] memory amms = new Structs.Amm[](ammsArray.length);
        for (uint8 i = 0; i < ammsArray.length; ++i) {
            amms[i] = Structs.Amm(ammsArray[i][0], ammsArray[i][1]);
        }
        return howToSplitRoutingOnLeveledAmms(amms, deltaX);
    }


    // @notice - we might have overflow issues; also, it's possible that not all of 'deltaX' is spend due to how integer division rounds down
    // @param amms - all of the AMMs we are considering to route between
    // @param delta - how much of a token we are looking to split among the AMMs
    // @param updateAmms - whether the AMMs' x and y values should be updated with the newly calculated x (and then corresponding y) values.
    // @return splits - an array telling us how much of the token to send to each of the leveled AMMs
    function howToSplitRoutingOnLeveledAmms(Structs.Amm[] memory amms, uint256 delta) public pure returns (uint256[] memory splits) {
        uint256 numberOfAmms = amms.length;
        splits = new uint256[](numberOfAmms);

        uint256 sumX = 0;
        uint256 sumY = 0;
        for (uint256 i = 0; i < numberOfAmms; ++i) {
            sumX += amms[i].x;
            sumY += amms[i].y;
        }

        //We prefer working with smaller numbers - less likely to run into overflow issues or losing
        // precision on division
        uint256 smallerDenom;
        bool areXsSmaller;
        if (sumX < sumY) {
            smallerDenom = sumX;
            areXsSmaller = true;
        } else {
            smallerDenom = sumY;
            areXsSmaller = false;
        }

        // We just take the weighted average to know how to split our spending:
        if (areXsSmaller) {
            for (uint256 i = 0; i < numberOfAmms; ++i) {
                splits[i] = (amms[i].x * delta) / sumX;
            }
        } else {
            for (uint256 i = 0; i < numberOfAmms; ++i) {
                splits[i] = (amms[i].y * delta) / sumY;
            }
        }
    }
}