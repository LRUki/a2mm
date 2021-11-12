// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "./Structs.sol";
import "./SharedFunctions.sol";


library Arbitrage {

    // @notice -
    // @param amms - The AMMs across which we are considering to arbitrage
    // @param amountOfYHeld - maximum amount of Y we are considering to use on arbitrage; if more is required, \
    // then a flash loan will be required, as big as 'flashLoanRequiredAmount'.
    // @return shouldArbitrage - Whether there was a profitable arbitrage opportunity between the considered AMMs
    // @return amountsToSendToAmms - the calculated amounts of (x, y) pairs to send to the AMMs for arbitrage. \
    // Ordered in the same order as the argument.
    // @return flashLoanRequiredAmount - how large of a flash loan is required to complete the arbitrage
    function arbitrage(Structs.Amm[] memory amms, uint256 amountOfYHeld) public pure returns (Structs.AmountsToSendToAmm[] memory amountsToSendToAmms, uint256 flashLoanRequiredAmount) {
        require(amms.length >= 2, 'We cannot arbitrage between less than 2 AMMs. Please make sure the amms array contains at least 2 AMMs.');

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
        );
        arbHelper.ML = Structs.Amm(amms[arbHelper.sortedAmmIndices[arbHelper.l]].x, amms[arbHelper.sortedAmmIndices[arbHelper.l]].y);
        arbHelper.MR = Structs.Amm(amms[arbHelper.sortedAmmIndices[arbHelper.r]].x, amms[arbHelper.sortedAmmIndices[arbHelper.r]].y);

        amountsToSendToAmms = new Structs.AmountsToSendToAmm[](amms.length);
        for (uint256 i = 0; i < amms.length; ++i) {
            amountsToSendToAmms[i] = Structs.AmountsToSendToAmm(0, 0);
            //TODO: Here we are assuming that the AMMs are taken by reference and not by value. Make sure this is the case
            arbHelper.sortedAmms[i] = amms[arbHelper.sortedAmmIndices[i]];
        }

        flashLoanRequiredAmount = 0;
        uint256[] memory ySplits;

        //Level until the union of ML and MR is sortedAmmIndices.
        while (arbHelper.l < arbHelper.r) {
            arbHelper.dyBar = SharedFunctions.howMuchYToSpendToLevelAmms(arbHelper.ML, amms[arbHelper.sortedAmmIndices[arbHelper.l + 1]]);

            //The amount we would need to spend, in terms of X, to level out the aggregated AMMs ML with the next
            // cheapest AMM;
            arbHelper.dxBar = SharedFunctions.howMuchXToSpendToLevelAmms(arbHelper.MR, amms[arbHelper.sortedAmmIndices[arbHelper.r - 1]]);
            //We then need to find out how much Y we need to spend to actually get the above mentioned amount of X. This
            // just involves inverting the second formula from (16) to make d_y the subject.
            // Note that if the commission fee is not 0.3% (or the formula is not xy=k), then this would differ:
            arbHelper.dy = (1000 * arbHelper.ML.x * arbHelper.ML.y - 1000 * arbHelper.ML.y * arbHelper.dxBar) / (997 * arbHelper.dxBar);

            //TODO: for some reason we can't pass array slices as function arguments, so have to create an array with the slice each time. Can this be done more efficiently?
            //Create arrays which hole the left AMMs and right AMMs. These are the ones which have been leveled within
            // their respective array.
            Structs.Amm[] memory sortedAmmsUpTol = new Structs.Amm[](amms.length - arbHelper.r);
            for (uint256 k = 0; k <= arbHelper.l; ++k) {
                sortedAmmsUpTol[k - arbHelper.r] = arbHelper.sortedAmms[k];
            }
            Structs.Amm[] memory sortedAmmsrToEnd = new Structs.Amm[](amms.length - arbHelper.r);
            for (uint256 k = arbHelper.r; k < amms.length; ++k) {
                sortedAmmsrToEnd[k - arbHelper.r] = arbHelper.sortedAmms[k];
            }

            if (arbHelper.r - arbHelper.l == 1) {
                //If the union of the left and right arrays is all of the AMMs, then the last step is to just
                // arbitrage on their aggregates.
                uint256 dyOpt = _optimalAmountToSpendOnArbitrageForY(arbHelper.ML, arbHelper.MR);
                ySplits = SharedFunctions.howToSplitRoutingOnLeveledAmms(sortedAmmsUpTol, dyOpt);
            } else if (arbHelper.dyBar < arbHelper.dy) {
                //Need to level the left AMMs, as the cost of leveling the right ones would be higher
                ySplits = SharedFunctions.howToSplitRoutingOnLeveledAmms(sortedAmmsUpTol, arbHelper.dyBar);
                arbHelper.increaseLow = true;
            } else {
                //Need to level the right AMMs, as the cost of leveling the left ones would be higher
                ySplits = SharedFunctions.howToSplitRoutingOnLeveledAmms(sortedAmmsUpTol, arbHelper.dy);
                arbHelper.increaseLow = false;
            }

            //Route the difference in y needed to level the AMMs (to get some X) on the left AMMs (ML)
            uint256 xGainSum = 0;
            for (uint256 k = 0; k <= arbHelper.l; ++k) {
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

            //Then we also route the x we gained to the right AMMs (MR)
            uint256[] memory xSplits = SharedFunctions.howToSplitRoutingOnLeveledAmms(sortedAmmsrToEnd, xGainSum);
            for (uint256 k = arbHelper.r; k < amms.length; ++k) {
                uint256 yGain = SharedFunctions.quantityOfXForY(arbHelper.sortedAmms[k], xSplits[k - arbHelper.r]);
                amountsToSendToAmms[arbHelper.sortedAmmIndices[k]].x += xSplits[k - arbHelper.r];
                amms[arbHelper.sortedAmmIndices[k]].x += xSplits[k - arbHelper.r];
                amms[arbHelper.sortedAmmIndices[k]].y -= yGain;
            }

            //Depending on which value was lowest at the start, we either move 'l' up, or 'r' down, and update
            // aggregate pools
            if (arbHelper.increaseLow) {
                arbHelper.ML.x += amms[arbHelper.sortedAmmIndices[++arbHelper.l]].x;
                arbHelper.ML.y += amms[arbHelper.sortedAmmIndices[arbHelper.l]].y;
            } else {
                assert(arbHelper.r > 0);
                arbHelper.MR.x += amms[arbHelper.sortedAmmIndices[--arbHelper.r]].x;
                arbHelper.MR.y += amms[arbHelper.sortedAmmIndices[arbHelper.r]].y;
            }
        }
    }


    //(Appendix B, formula 22)
    // @notice - possible underflow/overflow; \
    // This formula would be different if the commission fee is not 0.3% or the pricing formula is not the constant  \
    // product exchange formula; this formula is inexact. Making it exact might have a higher gas fee, so might be  \
    // worth investigating if the higher potential profit covers the potentially higher gas fee
    // @param amm1 - The AMM which we are selling X on
    // @param amm2 - The AMM which we are buying X on
    function _isArbitrageProfitable(Structs.Amm memory amm1, Structs.Amm memory amm2) private pure returns (bool) {
        return 500 * amm2.y * amm1.x < 497 * amm1.y * amm2.x;
    }


    //(Appendix B, formula 20)
    // @notice - possible underflow/overflow; \
    // This formula would be different if the commission fee is not 0.3% or the pricing formula is not the constant  \
    // product exchange formula; this formula is inexact. Making it exact might have a higher gas fee, so might be  \
    // worth investigating if the higher potential profit covers the potentially higher gas fee
    // @param t1_1 - The amount of liquidity of token 't1' on the first AMM
    // @param t2_1 - The amount of liquidity of token 't2' on the first AMM
    // @param t1_2 - The amount of liquidity of token 't1' on the second AMM
    // @param t2_2 - The amount of liquidity of token 't2' on the second AMM
    // @return dXOpt - the optimal amount we should wager on the arbitrage for optimal profit
    function _optimalAmountToSpendOnArbitrage(uint256 t1_1, uint256 t2_1, uint256 t1_2, uint256 t2_2) private pure returns (uint256) {
        assert(t2_1 * t1_2 > t2_2 * t1_1);
        return 1003 * (997 * SharedFunctions.sqrt(t1_1 * t1_2 * t2_1 * t2_2) / 1000 - t1_1 * t2_2) / (997 * t2_1 + 1000 * t2_2);
    }


    function _optimalAmountToSpendOnArbitrageForX(Structs.Amm memory amm1, Structs.Amm memory amm2) private pure returns (uint256) {
        require(amm1.y * amm2.x > amm2.y * amm1.x, 'Buying Y must be cheaper on amm1, however it is not!');
        return _optimalAmountToSpendOnArbitrage(amm1.x, amm1.y, amm2.x, amm2.y);
    }


    function _optimalAmountToSpendOnArbitrageForY(Structs.Amm memory amm1, Structs.Amm memory amm2) private pure returns (uint256) {
        require(amm1.x * amm2.y > amm2.x * amm1.y, 'Buying X must be cheaper on amm1, however it is not!');
        return _optimalAmountToSpendOnArbitrage(amm1.y, amm1.x, amm2.y, amm2.x);
    }


    struct ArbHelper {
        uint256[] sortedAmmIndices;
        uint256 l;
        uint256 r;
        Structs.Amm ML;
        Structs.Amm MR;
        Structs.Amm[] sortedAmms;
        uint256 dyBar;
        uint256 dxBar;
        uint256 dy;
        bool increaseLow;
    }
}
