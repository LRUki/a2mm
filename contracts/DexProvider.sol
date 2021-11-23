// SPDX-License-Identifier: MIT
//solhint-disable-next-line
pragma solidity 0.6.6 || 0.8.3;

import "./libraries/Structs.sol";
// import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";

contract DexProvider is IUniswapV2Callee {
    event ExecuteSwapEvent(uint256 amountIn, uint256 amountOut);
    address internal constant _UNIV2_FACTORY_ADDRESS =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address internal constant _SUSHI_FACTORY_ADDRESS =
        0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address internal constant _SHIBA_FACTORY_ADDRESS =
        0x115934131916C8b277DD010Ee02de363c09d037c;

    address[3] internal _factoryAddresses = [
        _UNIV2_FACTORY_ADDRESS,
        _SUSHI_FACTORY_ADDRESS,
        _SHIBA_FACTORY_ADDRESS
    ];

    function getReserves(
        address factoryAddress,
        address tokenA,
        address tokenB
    ) public view returns (uint256 reserveA, uint256 reserveB) {
        address pairAddress = IUniswapV2Factory(factoryAddress).getPair(
            tokenA,
            tokenB
        );
        require(pairAddress != address(0), "This pool does not exist");
        (address token0, ) = UniswapV2Library.sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairAddress)
            .getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    //swaps tokenIn -> tokenOut
    //assumes the contract already recieved `amountIn` of tokenIn by the user
    //at the end of the execution, this address will be holding the tokenOut
    function executeSwap(
        address factoryAddress,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        address pairAddress = IUniswapV2Factory(factoryAddress).getPair(
            tokenIn,
            tokenOut
        );
        require(pairAddress != address(0), "This pool does not exist");
        (address token0, ) = UniswapV2Library.sortTokens(tokenIn, tokenOut);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairAddress)
            .getReserves();
        (uint256 reserveIn, uint256 reserveOut) = token0 == tokenIn
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
        amountOut = UniswapV2Library.getAmountOut(
            amountIn,
            reserveIn,
            reserveOut
        );
        IERC20(tokenIn).transfer(pairAddress, amountIn);
        (uint256 amount0Out, uint256 amount1Out) = token0 == tokenIn
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));
        IUniswapV2Pair(pairAddress).swap(
            amount0Out,
            amount1Out,
            address(this),
            new bytes(0)
        );
        emit ExecuteSwapEvent(amountIn, amountOut);
        return amountOut;
    }

    function flashSwap(
        address tokenIn,
        address tokenOut,
        uint256 xToLoan,
        uint256 yToLoan,
        bytes memory data
    ) public {
        (address token0, ) = UniswapV2Library.sortTokens(tokenIn, tokenOut);
        (uint256 amount0Out, uint256 amount1Out) = token0 == tokenIn
            ? (xToLoan, yToLoan)
            : (yToLoan, xToLoan);
        address pairAddress = IUniswapV2Factory(_UNIV2_FACTORY_ADDRESS).getPair(
            tokenIn,
            tokenOut
        );

        IUniswapV2Pair(pairAddress).swap(
            amount0Out,
            amount1Out,
            address(this),
            data
        );
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        //TODO: make sure that tokenIn and tokenOut are the right way around
        IUniswapV2Pair pair = IUniswapV2Pair(msg.sender);
        address tokenIn = data.length == 2 ? pair.token1() : pair.token0();
        address tokenOut = data.length == 2 ? pair.token0() : pair.token1();
        (
            Structs.Amm[] memory amms,
            address[] memory factoriesSupportingTokenPair,
            uint256[] memory routingAmountsToSendToAmms,
            Structs.AmountsToSendToAmm[] memory arbitrageAmountsToSendToAmms
        ) = abi.decode(
                data,
                (
                    Structs.Amm[],
                    address[],
                    uint256[],
                    Structs.AmountsToSendToAmm[]
                )
            );
        assert(
            msg.sender ==
                IUniswapV2Factory(_UNIV2_FACTORY_ADDRESS).getPair(
                    tokenIn,
                    tokenOut
                )
        ); // ensure that msg.sender is a V2 pair
        //TODO: sort tokenInAmount, tokenOutAmount
        //1. tokenInAmount = sum of xs in amountsToSendToAmm - userAmountIn, tokenOutAmount = 0
        //1. tokenInAmount = 0 , tokenOutAmount = sum of ys in amountsToSendToAmm

        //2. convert ys to xs and keep track of x we get
        //xSum = 0
        // for (uint256 i = 0; i < amountsToSendToAmm.length; ++i) {
        //    xSum += executeSwap(_factoryAddresses[i], tokenOut,tokenIn, amountsToSendToAmm[i].y);
        // }

        //require(xSum + userAmountIn == sum(amountsToSendToAmm.x)) ????

        //3. convert tokenIn(x) to tokenOut(y) and keep track of tokenOut we get
        //ySum = 0
        // for (uint256 i = 0; i < amountsToSendToAmm.length; ++i) {
        //    ySum += executeSwap(_factoryAddresses[i], tokenIn, tokenOut, amountsToSendToAmm[i].x);
        // }

        //4 return tokenOutAmount of y + fee to Uniswap
        //keep the ySum - (tokenOutAmount of y + fee)
        //TODO:return back to the sender

        //------------------------------------- UPDATE FROM MIHEY: ---------------------------------------
        /*
         - the 'data' argument here is going to have to include the 'routingAmountsToSendToAmms' and
        'arbitrageAmountsToSendToAmms' return values from 'calculateRouteAndArbitarge()'.
        - 'tokenIn' will be set to zero;
        - 'tokenOut' will be set to 'amountOfYtoFlashLoan' (return value from 'calculateRouteAndArbitarge()'). Note
            that if this is zero, then we shouldn't reach the flash swap case.
        - Then, the steps we take are:
            - exchange X->Y using 'routingAmountsToSendToAmms'. No need to keep track of sum;
            - exchange Y->X using the '.y' members of 'arbitrageAmountsToSendToAmms'. No need to keep track of sum;
            - exchange X->Y using the '.x' members of 'arbitrageAmountsToSendToAmms', keeping track of how much Y
                we get from this (sum it all up, and call it 'ySum');
            - return the flash loan (we'll have to calculate it - call it 'returnLoan')
            - give the user 'ySum - returnLoan' amount of Y.
        */
    }
}
