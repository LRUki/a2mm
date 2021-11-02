// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "./Structs.sol";


library SharedFunctions {

    // @notice - this is the Babylonian/Heron's method of finding the square root. It returns an integer value!
    // @param x - the number whose square root we want to find
    // @return y - the square roorted number (as integer)
    // solhint-disable-next-line func-visibility
    function sqrt(uint256 x) public pure returns (uint256 y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }


    // @notice - has potential issues of underflow or overflow. However, this is the least likely location in our code for this to occur.
    // @param amm - the AMM we are looking to trade at
    // @param x - how much of X we are willing to potentially spend
    // @return - how much of Y we would get if we traded x of X for Y
    // solhint-disable-next-line func-visibility
    function quantityOfYForX(Structs.Amm memory amm, uint256 x) public pure returns (uint256){
        // float and int multiplication is not supported, so we have to rewrite:
        // fixed commissionFee = 0.003;
        // return amm.y - (amm.x * amm.y)/(amm.x + x * (1 - commissionFee));
        // as:
        return amm.y - amm.x * (amm.y / (amm.x + x * 997 / 1000));
    }


    // @param amm - the AMM we are considering to trade at
    // @return - amount of Y we would get for unit X
    // solhint-disable-next-line func-visibility
    function exchangeRateForY(Structs.Amm memory amm) public pure returns (uint256){
        return quantityOfYForX(amm, 1);
    }


    // @notice - uses insertion sort, as we don't expect to have a large list (I think Arthur mentioned only using 4-5 maximum)
    // @param amms - all of the AMMs we are considering (either for routing or arbitrage)
    // @return indices - the indices of the amms array sorted by their exchange rate
    // solhint-disable-next-line func-visibility
    function sortAmmArrayIndicesByExchangeRate(Structs.Amm[] memory amms) public pure returns (uint256[] memory indices) {
        indices = new uint256[](amms.length);
        for (uint256 i = 0; i < amms.length; i++) {
            indices[i] = i;
        }

        uint256 n = amms.length;
        for (uint256 i = 1; i < n; ++i) {
            uint256 tmp = indices[i];
            uint256 j = i;
            while (j > 0 && exchangeRateForY(amms[tmp]) < exchangeRateForY(amms[indices[j - 1]])) {
                indices[j] = indices[j - 1];
                --j;
            }
            indices[j] = tmp;
        }
    }
}