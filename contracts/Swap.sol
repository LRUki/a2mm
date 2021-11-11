// SPDX-License-Identifier: MIT
pragma solidity 0.6.6 || 0.8.3;
pragma experimental ABIEncoderV2;

import "./libraries/Structs.sol";
import "./libraries/Arbitrage.sol";
import "./libraries/Route.sol";
import "./DexProvider.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract Swap {
    address private _sushiFactoryAddress = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address private _uniV2FactoryAddress = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    DexProvider private _dexProvider;
    
    constructor(address dexProviderAddress) public {
	    _dexProvider = DexProvider(dexProviderAddress);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountOfX) external {
	    _dexProvider.executeSwap(_uniV2FactoryAddress, tokenIn, tokenOut, amountOfX);
    } 

    // @notice - for now, only the first two AMMs in the list will actually be considered for anything
    // @param amountOfX - how much the user is willing to trade
    // @return amountsToSendToAmms - the pair of values indicating how much of X and Y should be sent to each AMM (ordered in the same way as the AMMs were passed in)
    // @return flashLoanRequiredAmount - how big of a flash loan we would need to take out to successfully complete the transation. This is done for the arbitrage step.
//     function swapXforY(Structs.Amm[] memory amms, uint256 amountOfX) public pure returns (Structs.AmountsToSendToAmm[] memory amountsToSendToAmms, uint256 flashLoanRequiredAmount) {
//         bool shouldArbitrage;

//         uint256 totalYGainedFromRouting;
//         Structs.XSellYGain[] memory routingsAndGains;
//         (routingsAndGains, totalYGainedFromRouting, shouldArbitrage) = Route.route(amms, amountOfX);
//         amountsToSendToAmms = new Structs.AmountsToSendToAmm[](amms.length);
//         for (uint256 i = 0; i < amms.length; i++) {
//             amountsToSendToAmms[i] = Structs.AmountsToSendToAmm(routingsAndGains[i].x, 0);
//         }
//         if (shouldArbitrage) {
//            Structs.AmountsToSendToAmm[] memory arbitrages;
//            (shouldArbitrage, arbitrages, flashLoanRequiredAmount) = Arbitrage.arbitrage(amms, totalYGainedFromRouting);
//            if (shouldArbitrage) {
//                for (uint256 i = 0; i < amms.length; i++) {
//                    //If we are adding an extra step after arbitrage, we might want to update the AMMs here once again.
//                    amountsToSendToAmms[i].x += arbitrages[i].x;
//                    amountsToSendToAmms[i].y += arbitrages[i].y;
//                }
//            }
//         }
//         flashLoanRequiredAmount = 0;
//     }
}
