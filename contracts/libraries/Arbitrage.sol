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
    function arbitrage(Structs.Amm[] memory amms, uint256 amountOfYHeld) public pure returns (bool, Structs.AmountsToSendToAmm[] memory amountsToSendToAmms, uint256 flashLoanRequiredAmount) {
        //TODO
        amountsToSendToAmms = new Structs.AmountsToSendToAmm[](amms.length);
        return (false, amountsToSendToAmms, 42);
    }


    //TODO: this formula would be different if the commission fee is not 0.3% or the pricing formula is not the constant product exchange formula
    //TODO: this formula is inexact. Making it exact might have a higher gas fee, so might be worth investigating if the higher potential profit covers the potentially higher gas fee
    //(Appendix B, formula 22)
    //Tells us if an arbitrage opportunity is profitable (without considering transaction fees).
    // @notice - possible underflow/overflow, however not as likely as some other functions;
    // @param amm1 - the first of two AMMs we are considering to do arbitrage on
    // @param amm2 - the second of two AMMs we are considering to do arbitrage on
    // @return - whether it is profitable to do arbitrage between these two AMMs
    function _isArbitrageProfitable(Structs.Amm memory amm1, Structs.Amm memory amm2) private pure returns (bool) {
        return 500 * amm2.y / amm2.x < 497 * amm1.y / amm1.x;
    }


    //(Appendix B, formula 20)
    // @notice - possible underflow/overflow; \
    // This formula would be different if the commission fee is not 0.3% or the pricing formula is not the constant  \
    // product exchange formula; this formula is inexact. Making it exact might have a higher gas fee, so might be  \
    // worth investigating if the higher potential profit covers the potentially higher gas fee
    // @param amm1 - the first of two AMMs we are considering to do arbitrage on
    // @param amm2 - the second of two AMMs we are considering to do arbitrage on
    // @return dXOpt - the optimal amount we should wager on the arbitrage for optimal profit
    function _optimalAmountToSpendOnArbitrage(Structs.Amm memory amm1, Structs.Amm memory amm2) private pure returns (uint256 dXOpt) {
        dXOpt = 1003 * (997 * SharedFunctions.sqrt(amm1.x * amm2.x * amm1.y * amm2.y) / 1000 - amm1.x * amm2.y) / (997 * amm1.y + 1000 * amm2.y);
    }


    //(Appendix D)
    // @notice
    // @param amms - the AMMs we are considering doing arbitrage between
    // @return
    function _arbitrageForY(Structs.Amm[] memory amms) private pure {
        sortedAmms = SharedFunctions.sortAmmArrayIndicesByExchangeRate(amms);

        l = 0;
        r = amms.length - 1;
        Structs.Amm[] memory lowAmms = Structs.Amm[](amms.length - 1);
        Structs.Amm[] memory highAmms = Structs.Amm[](amms.length - 1);
        while (true) {
            ml = SharedFunctions.aggregateAmmPools(lowAmms[:l+1]);
            mr = SharedFunctions.aggregateAmmPools(highAmms[r:]);
            if (_isArbitrageProfitable(ml, mr)) {

            }
        }
        //TODO
    }
}
