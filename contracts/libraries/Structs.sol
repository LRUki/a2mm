// SPDX-License-Identifier: MIT
//solhint-disable-next-line
pragma solidity 0.6.6 || 0.8.3;


library Structs {

    struct Amm {
        uint256 x;
        uint256 y;
    }


    struct AmountsToSendToAmm {
        uint256 x;
        uint256 y;
    }
}
