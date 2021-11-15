// SPDX-License-Identifier: MIT
//solhint-disable-next-line
pragma solidity 0.6.6 || 0.8.3;
pragma experimental ABIEncoderV2;

import "./Structs.sol";
import "./SharedFunctions.sol";
import "hardhat/console.sol";


library Arbitrage {
    uint256 constant MAX_INT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    //function below is only for testing purposes
    //we need to expose a wrapper functions as there is an issue passing in Structs from javascript
    function arbitrageWrapper(uint256[2][] memory ammsArray, uint256 amountOfYHeld) public view returns (Structs.AmountsToSendToAmm[] memory, uint256) {
        Structs.Amm[] memory amms = new Structs.Amm[](ammsArray.length);
        for (uint256 i = 0; i < ammsArray.length; ++i) {
            amms[i] = Structs.Amm(ammsArray[i][0], ammsArray[i][1]);
        }
        return arbitrage(amms, amountOfYHeld);
    }


    // @param amms - The AMMs across which we are considering to arbitrage
    // @param amountOfYHeld - maximum amount of Y we are considering to use on arbitrage; if more is required, \
    // then a flash loan will be required, as big as 'flashLoanRequiredAmount'.
    // @return shouldArbitrage - Whether there was a profitable arbitrage opportunity between the considered AMMs
    // @return amountsToSendToAmms - the calculated amounts of (x, y) pairs to send to the AMMs for arbitrage. \
    // Ordered in the same order as the argument.
    // @return flashLoanRequiredAmount - how large of a flash loan is required to complete the arbitrage
    function arbitrage(Structs.Amm[] memory amms, uint256 amountOfYHeld) public view returns (Structs.AmountsToSendToAmm[] memory amountsToSendToAmms, uint256 flashLoanRequiredAmount) {
        require(amms.length >= 2, "Need at least 2 AMMs in 'amms'");

        ArbHelper memory arbHelper = ArbHelper(
            SharedFunctions.sortAmmArrayIndicesByExchangeRate(amms)
        , 0
        , amms.length - 1
        , Structs.Amm(0, 0)
        , Structs.Amm(0, 0)
        , new Structs.Amm[](amms.length)
        , 0
        , 0
        , 0
        , false
        , false
        );
        arbHelper.ml = Structs.Amm(amms[arbHelper.sortedAmmIndices[arbHelper.left]].x, amms[arbHelper.sortedAmmIndices[arbHelper.left]].y);
        arbHelper.mr = Structs.Amm(amms[arbHelper.sortedAmmIndices[arbHelper.right]].x, amms[arbHelper.sortedAmmIndices[arbHelper.right]].y);

        amountsToSendToAmms = new Structs.AmountsToSendToAmm[](amms.length);
        for (uint256 i = 0; i < amms.length; ++i) {
            amountsToSendToAmms[i] = Structs.AmountsToSendToAmm(0, 0);
            arbHelper.sortedAmms[i] = amms[arbHelper.sortedAmmIndices[i]];
        }

        flashLoanRequiredAmount = 0;
        uint256[] memory ySplits;

        //Level until the union of ml and mr is sortedAmmIndices.
        while (arbHelper.left < arbHelper.right && _isArbitrageProfitable(arbHelper.ml, arbHelper.mr)) {
            arbHelper.dyBar = SharedFunctions.howMuchYToSpendToLevelAmms(arbHelper.ml, amms[arbHelper.sortedAmmIndices[arbHelper.left + 1]]);
            console.log('arbHelper.dyBar: %s', arbHelper.dyBar);

            //The amount we would need to spend, in terms of X, to level out the aggregated AMMs ml with the next
            // cheapest AMM;
            arbHelper.dxBar = SharedFunctions.howMuchXToSpendToLevelAmms(arbHelper.mr, amms[arbHelper.sortedAmmIndices[arbHelper.right - 1]]);
            console.log('arbHelper.dxBar: %s', arbHelper.dxBar);
            //We then need to find out how much Y we need to spend to actually get the above mentioned amount of X. This
            // just involves inverting the second formula from (16) to make d_y the subject.
            // Note that if the commission fee is not 0.3% (or the formula is not xy=k), then this would differ:
            uint256 minuend = 1000 * arbHelper.ml.x * arbHelper.ml.y;
            uint256 subtrahend = 1000 * arbHelper.ml.y * arbHelper.dxBar;
            if (subtrahend > minuend || arbHelper.dxBar == 0) {
                arbHelper.dy = MAX_INT;
            } else {
                arbHelper.dy = (minuend - subtrahend) / (997 * arbHelper.dxBar);
            }
            console.log('arbHelper.dy: %s', arbHelper.dy);

            uint256 dyOpt = _optimalAmountToSpendOnArbitrageForY(arbHelper.ml, arbHelper.mr);

            //TODO: for some reason we can't pass array slices as function arguments, so have to create an array with the slice each time. Can this be done more efficiently?
            //Create arrays which hole the left AMMs and right AMMs. These are the ones which have been leveled within
            // their respective array.
            console.log('amms.length: %s', amms.length);
            console.log('arbHelper.left: %s', arbHelper.left);
            Structs.Amm[] memory sortedAmmsUpTol = new Structs.Amm[](arbHelper.left + 1);
            for (uint256 k = 0; k <= arbHelper.left; ++k) {
                console.log('k: %s', k);
                sortedAmmsUpTol[k] = arbHelper.sortedAmms[k];
            }
            console.log('-----------------------------');
            Structs.Amm[] memory sortedAmmsrToEnd = new Structs.Amm[](amms.length - arbHelper.right);
            console.log('arbHelper.right: %s', arbHelper.right);
            for (uint256 k = arbHelper.right; k < amms.length; ++k) {
                console.log('k: %s', k);
                sortedAmmsrToEnd[k - arbHelper.right] = arbHelper.sortedAmms[k];
            }
            console.log('passed both for loops');
            console.log('===============================\n');
            arbHelper.doneArbitraging = false;

            if (arbHelper.right - arbHelper.left == 1 || (dyOpt < arbHelper.dyBar && dyOpt < arbHelper.dy)) {
                console.log('-----------------------------');
                console.log('not broken1');
                console.log('-----------------------------');
                //If the union of the left and right arrays is all of the AMMs, then the last step is to just
                // arbitrage on their aggregates.
                console.log('after _optimalAmountToSpendOnArbitrageForY() = %s', dyOpt);
                ySplits = SharedFunctions.howToSplitRoutingOnLeveledAmms(sortedAmmsUpTol, dyOpt);
                arbHelper.doneArbitraging = true;
                console.log('-----------------------------');
                console.log('not broken4');
                console.log('-----------------------------');
            } else if (arbHelper.dyBar < arbHelper.dy) {
                console.log('-----------------------------');
                console.log('not broken2');
                console.log('-----------------------------');
                //Need to level the left AMMs, as the cost of leveling the right ones would be higher
                ySplits = SharedFunctions.howToSplitRoutingOnLeveledAmms(sortedAmmsUpTol, arbHelper.dyBar);
                arbHelper.increaseLow = true;
            } else if (arbHelper.dyBar >= arbHelper.dy) {
                console.log('-----------------------------');
                console.log('not broken3');
                console.log('-----------------------------');
                //Need to level the right AMMs, as the cost of leveling the left ones would be higher
                ySplits = SharedFunctions.howToSplitRoutingOnLeveledAmms(sortedAmmsUpTol, arbHelper.dy);
                arbHelper.increaseLow = false;
            }
            console.log('-----------------------------');
            console.log('not broken5');
            console.log('-----------------------------');

            //Route the difference in y needed to level the AMMs (to get some X) on the left AMMs (ml)
            uint256 xGainSum = 0;
            for (uint256 k = 0; k <= arbHelper.left; ++k) {
                uint256 xGain = SharedFunctions.quantityOfXForY(arbHelper.sortedAmms[k], ySplits[k]);
                xGainSum += xGain;
                amountsToSendToAmms[arbHelper.sortedAmmIndices[k]].y += ySplits[k];
                amms[arbHelper.sortedAmmIndices[k]].y += ySplits[k];
                amms[arbHelper.sortedAmmIndices[k]].x -= xGain;
                if (amountOfYHeld >= ySplits[k]) {
                    amountOfYHeld -= ySplits[k];
                } else {
                    flashLoanRequiredAmount += ySplits[k] - amountOfYHeld;
                    amountOfYHeld = 0;
                }
            }

            //Then we also route the x we gained to the right AMMs (mr)
            uint256[] memory xSplits = SharedFunctions.howToSplitRoutingOnLeveledAmms(sortedAmmsrToEnd, xGainSum);
            for (uint256 k = arbHelper.right; k < amms.length; ++k) {
                uint256 yGain = SharedFunctions.quantityOfXForY(arbHelper.sortedAmms[k], xSplits[k - arbHelper.right]);
                amountsToSendToAmms[arbHelper.sortedAmmIndices[k]].x += xSplits[k - arbHelper.right];
                amms[arbHelper.sortedAmmIndices[k]].x += xSplits[k - arbHelper.right];
                amms[arbHelper.sortedAmmIndices[k]].y -= yGain;
            }

            //Depending on which value was lowest at the start, we either move 'l' up, or 'r' down, and update
            // aggregate pools
             if (arbHelper.increaseLow) {
                arbHelper.ml.x += amms[arbHelper.sortedAmmIndices[++arbHelper.left]].x;
                arbHelper.ml.y += amms[arbHelper.sortedAmmIndices[arbHelper.left]].y;
            } else {
                arbHelper.mr.x += amms[arbHelper.sortedAmmIndices[--arbHelper.right]].x;
                arbHelper.mr.y += amms[arbHelper.sortedAmmIndices[arbHelper.right]].y;
            }
            console.log('AMM1: (%s, %s)', amms[0].x, amms[0].y);
            console.log('AMM2: (%s, %s)', amms[1].x, amms[1].y);
            console.log('AMM3: (%s, %s)', amms[2].x, amms[2].y);

            if (arbHelper.doneArbitraging) {
                break;
            }
        }
    }


    //(Appendix B, formula 22)
    // @notice - possible underflow/overflow; \
    // This formula would be different if the commission fee is not 0.3% or the pricing formula is not the constant  \
    // product exchange formula; this formula is inexact. Making it exact might have a higher gas fee, so might be  \
    // worth investigating if the higher potential profit covers the potentially higher gas fee
    // @param amm1 - The AMM which we are selling Y on
    // @param amm2 - The AMM which we are buying Y on
    function _isArbitrageProfitable(Structs.Amm memory amm1, Structs.Amm memory amm2) private pure returns (bool) {
        return 500 * amm2.x * amm1.y < 497 * amm1.x * amm2.y;
    }


    //(Appendix B, formula 20)
    // @notice - possible underflow/overflow; \
    // This formula would be different if the commission fee is not 0.3% or the pricing formula is not the constant  \
    // product exchange formula; this formula is inexact. Making it exact might have a higher gas fee, so might be  \
    // worth investigating if the higher potential profit covers the potentially higher gas fee
    // @param t11 - The amount of liquidity of token 't1' on the first AMM
    // @param t21 - The amount of liquidity of token 't2' on the first AMM
    // @param t12 - The amount of liquidity of token 't1' on the second AMM
    // @param t22 - The amount of liquidity of token 't2' on the second AMM
    // @return dXOpt - the optimal amount we should wager on the arbitrage for optimal profit
    function _optimalAmountToSpendOnArbitrage(uint256 t11, uint256 t21, uint256 t12, uint256 t22) private view returns (uint256) {
        console.log('Hello3');
        assert(t21 * t12 >= t22 * t11);
        console.log('Hello4');
        uint256 left = 997 * SharedFunctions.sqrt(t11 * t12) * SharedFunctions.sqrt(t21 * t22) / 1000;
        uint256 right = t11 * t22;
        if (right >= left) {
            //We can't level these any more than they are
            return 0;
        }
        return 1003 * (left - right) / (997 * t21 + 1000 * t22);
    }


    //(Appendix B, formula 20)
    // @notice - possible underflow/overflow; \
    // This formula would be different if the commission fee is not 0.3% or the pricing formula is not the constant  \
    // product exchange formula; this formula is inexact. Making it exact might have a higher gas fee, so might be  \
    // worth investigating if the higher potential profit covers the potentially higher gas fee
    // @param amm1 - The AMM whose price for Y is lower, i.e. Y/X is higher; we would sell X here
    // @param amm2 - The AMM whose price for Y is higher, i.e. Y/X is lower; we would sell Y here
    // @return dXOpt - the optimal amount we should wager on the arbitrage for optimal profit
    function _optimalAmountToSpendOnArbitrageForX(Structs.Amm memory amm1, Structs.Amm memory amm2) private view returns (uint256) {
        require(amm1.y * amm2.x >= amm2.y * amm1.x, "Y must be cheaper on amm1!");
        return _optimalAmountToSpendOnArbitrage(amm1.x, amm1.y, amm2.x, amm2.y);
    }


    //(Appendix B, formula 20)
    // @notice - possible underflow/overflow; \
    // This formula would be different if the commission fee is not 0.3% or the pricing formula is not the constant  \
    // product exchange formula; this formula is inexact. Making it exact might have a higher gas fee, so might be  \
    // worth investigating if the higher potential profit covers the potentially higher gas fee
    // @param amm1 - The AMM whose price for X is lower, i.e. X/Y is higher; we would sell Y here
    // @param amm2 - The AMM whose price for X is higher, i.e. X/Y is lower; we would sell X here
    // @return dXOpt - the optimal amount we should wager on the arbitrage for optimal profit
    function _optimalAmountToSpendOnArbitrageForY(Structs.Amm memory amm1, Structs.Amm memory amm2) private view returns (uint256) {
        console.log('Hello1');
        require(amm1.x * amm2.y >= amm2.x * amm1.y, "X must be cheaper on amm1!");
        console.log('Hello2');
        return _optimalAmountToSpendOnArbitrage(amm1.y, amm1.x, amm2.y, amm2.x);
    }


    struct ArbHelper {
        uint256[] sortedAmmIndices;
        uint256 left;
        uint256 right;
        Structs.Amm ml;
        Structs.Amm mr;
        Structs.Amm[] sortedAmms;
        uint256 dyBar;
        uint256 dxBar;
        uint256 dy;
        bool increaseLow;
        bool doneArbitraging;
    }
}
