// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "./libraries/Structs.sol";
import "./libraries/Arbitrage.sol";
import "./libraries/Route.sol";


contract Swap {

    // @notice - for now, only the first two AMMs in the list will actually be considered for anything
    // @param amountOfX - how much the user is willing to trade
    // @return amountsToSendToAmms - the pair of values indicating how much of X and Y should be sent to each AMM (ordered in the same way as the AMMs were passed in)
    // @return flashLoanRequiredAmount - how big of a flash loan we would need to take out to successfully complete the transation. This is done for the arbitrage step.
    function swapXforY(Structs.Amm[] memory amms, uint256 amountOfX) public pure returns (Structs.AmountsToSendToAmm[] memory amountsToSendToAmms, uint256 flashLoanRequiredAmount) {
        bool shouldArbitrage;

        uint256 totalYGainedFromRouting;
        Structs.XSellYGain[] memory routingsAndGains;
        (routingsAndGains, totalYGainedFromRouting, shouldArbitrage) = Route.route(amms, amountOfX);
        amountsToSendToAmms = new Structs.AmountsToSendToAmm[](amms.length);
        for (uint256 i = 0; i < amms.length; i++) {
            amountsToSendToAmms[i] = Structs.AmountsToSendToAmm(routingsAndGains[i].x, 0);
        }

        flashLoanRequiredAmount = 0;
        if (shouldArbitrage && amms.length > 1) {
            Structs.AmountsToSendToAmm[] memory arbitrages;
            (arbitrages, flashLoanRequiredAmount) = Arbitrage.arbitrage(amms, totalYGainedFromRouting);
            for (uint256 i = 0; i < amms.length; i++) {
                amountsToSendToAmms[i].x += arbitrages[i].x;
                amountsToSendToAmms[i].y += arbitrages[i].y;
            }
        }
    }
}
