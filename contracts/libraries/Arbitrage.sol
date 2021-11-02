// SPDX-License-Identifier: MIT

/* solhint-disable */
pragma solidity ^0.8.3;

import "./Structs.sol";
import "./SharedFunctions.sol";


library Arbitrage {

    //Returns a boolean to tell us if there is an arbitrage opportunity, and if there is, also returns
    // how much we should spend on each AMM with a (x, y) pair for each AMM ordered in the same
    // order as the argument.
    // @notice
    // @param amms
    // @param amountOfYHeld
    // @return shouldArbitrage -
    // @return amountsToSendToAmms -
    // @return flashLoanRequiredAmount -
    function arbitrage(Structs.Amm[] memory amms, uint256 amountOfYHeld) public pure returns (bool, Structs.AmountsToSendToAmm[] memory amountsToSendToAmms, uint256 flashLoanRequiredAmount) {
        //TODO
        amountsToSendToAmms = new Structs.AmountsToSendToAmm[](amms.length);
        return (false, amountsToSendToAmms, 42);
    }


    //TODO: this formula would be different if the commission fee is not 0.3% or the pricing formula is not the constant product exchange formula
    //TODO: this formula is inexact. Making it exact might have a higher gas fee, so might be worth investigating if the higher potential profit covers the potentially higher gas fee
    //(Appendix B, formula 22)
    //Tells us if an arbitrage opportunity is profitable (without considering transaction fees).
    // @notice
    // @param amm1
    // @param amm2
    // @return
    function _isArbitrageProfitable(Structs.Amm memory amm1, Structs.Amm memory amm2) private pure returns (bool) {
        return 500 * amm2.y / amm2.x < 497 * amm1.y / amm1.x;
    }


    //TODO: this formula would be different if the commission fee is not 0.3% or the pricing formula is not the constant product exchange formula
    //TODO: this formula is inexact. Making it exact might have a higher gas fee, so might be worth investigating if the higher potential profit covers the potentially higher gas fee
    //Note that this function is designed to only find the optimal when we only consider 2 AMMs.
    //(Appendix B, formula 20)
    // @notice - possible underflow/overflow
    // @param amm1 - the first of two AMMs we are considering to do arbitrage on
    // @param amm2 - the second of two AMMs we are considering to do arbitrage on
    // @return dXOpt - the optimal amount we should wager on the arbitrage for optimal profit
    function _optimalAmountToSpendOnArbitrage(Structs.Amm memory amm1, Structs.Amm memory amm2) private pure returns (uint256 dXOpt) {
        //TODO: make sure no overflows occur here
        dXOpt = 1003 * (997 * SharedFunctions.sqrt(amm1.x * amm2.x * amm1.y * amm2.y) / 1000 - amm1.x * amm2.y) / (997 * amm1.y + 1000 * amm2.y);
    }


    //(Appendix D)
    // @notice
    // @param amms - the AMMs we are considering doing arbitrage between
    // @return
    function _arbitrageForY(Structs.Amm[] memory amms) private pure {
        //TODO
    }
}
/* solhint-enable */
