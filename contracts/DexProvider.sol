// SPDX-License-Identifier: MIT
//solhint-disable-next-line
pragma solidity 0.6.6 || 0.8.3;
//Solidity 0.8 already comes with ABIEncoderV2 out of the box; however, 0.6.6 doesn't.
pragma experimental ABIEncoderV2;

import "./libraries/Structs.sol";
import "./libraries/SharedFunctions.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "hardhat/console.sol";

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
    //assumes the contract already received `amountIn` of tokenIn by the user
    //at the end of the execution, this address will be holding the tokenOut
    function executeSwap(
        address factoryAddress,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        console.log("Inside executeSwap() - start");
        address pairAddress = IUniswapV2Factory(factoryAddress).getPair(
            tokenIn,
            tokenOut
        );
        console.log("Inside executeSwap() - 1");
        require(pairAddress != address(0), "This pool does not exist");
        (address token0, ) = UniswapV2Library.sortTokens(tokenIn, tokenOut);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairAddress)
            .getReserves();
        console.log("Inside executeSwap() - 2");
        (uint256 reserveIn, uint256 reserveOut) = token0 == tokenIn
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
        console.log("Inside executeSwap() - 3");
        amountOut = UniswapV2Library.getAmountOut(
            amountIn,
            reserveIn,
            reserveOut
        );
        console.log("Inside executeSwap() - 4");
        IERC20(tokenIn).transfer(pairAddress, amountIn);
        (uint256 amount0Out, uint256 amount1Out) = token0 == tokenIn
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));
        console.log("Inside executeSwap() - 5");
        IUniswapV2Pair(pairAddress).swap(
            amount0Out,
            amount1Out,
            address(this),
            new bytes(0)
        );
        console.log("Inside executeSwap() - 6");
        emit ExecuteSwapEvent(amountIn, amountOut);
        console.log("Inside executeSwap() - end");
        return amountOut;
    }

    // @param tokenIn - the first token we are interested in; usually considered to be the token which the user is putting in
    // @param tokenOut - the second token we are interested in; usually considered to be the token which the user wants to get back
    // @return factoriesSupportingTokenPair - an array of factory addresses which have the token pair
    // @return amms - a list of AMM structs containing the reserves of each AMM which has the token pair
    function _factoriesWhichSupportPair(address tokenIn, address tokenOut)
        internal
        view
        returns (
            address[] memory factoriesSupportingTokenPair,
            Structs.Amm[] memory amms
        )
    {
        uint256 noFactoriesSupportingTokenPair = 0;
        for (uint256 i = 0; i < _factoryAddresses.length; i++) {
            if (
                IUniswapV2Factory(_factoryAddresses[i]).getPair(
                    tokenIn,
                    tokenOut
                ) != address(0x0)
            ) {
                noFactoriesSupportingTokenPair++;
            }
        }

        amms = new Structs.Amm[](noFactoriesSupportingTokenPair);
        factoriesSupportingTokenPair = new address[](
            noFactoriesSupportingTokenPair
        );
        uint256 j = 0;
        for (
            uint256 i = 0;
            i < _factoryAddresses.length && j < noFactoriesSupportingTokenPair;
            i++
        ) {
            if (
                IUniswapV2Factory(_factoryAddresses[i]).getPair(
                    tokenIn,
                    tokenOut
                ) != address(0x0)
            ) {
                (amms[j].x, amms[j].y) = getReserves(
                    _factoryAddresses[i],
                    tokenIn,
                    tokenOut
                );
                factoriesSupportingTokenPair[j++] = _factoryAddresses[i];
            }
        }

        return (factoriesSupportingTokenPair, amms);
    }

    function flashSwap(
        address tokenIn,
        address tokenOut,
        uint256 yToLoan,
        address whereToLoan,
        address[] memory factoriesSupportingTokenPair,
        uint256[] memory routingAmountsToSendToAmms,
        Structs.AmountsToSendToAmm[] memory arbitrageAmountsToSendToAmms
    ) public {
        address pairAddress = IUniswapV2Factory(whereToLoan).getPair(
            tokenIn,
            tokenOut
        );

        (address token0, ) = UniswapV2Library.sortTokens(tokenIn, tokenOut);

        bytes memory data = abi.encode(
            factoriesSupportingTokenPair,
            routingAmountsToSendToAmms,
            arbitrageAmountsToSendToAmms,
            whereToLoan
        );

        console.log("Inside flashSwap()");

        (uint256 amount0Out, uint256 amount1Out) = token0 == tokenIn
            ? (uint256(0), yToLoan)
            : (yToLoan, uint256(0));
        IUniswapV2Pair(pairAddress).swap(
            amount0Out,
            amount1Out,
            address(this),
            data
        );
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata data
    ) external override {
        console.log("Inside uniswapV2Call() - start");
        require(
            (amount0Out > 0 && amount1Out == 0) ||
                (amount0Out == 0 && amount1Out > 0),
            "flash loan invalid"
        );

        address tokenIn;
        address tokenOut;
        address whereToRepayLoan;
        Structs.AmountsToSendToAmm[] memory arbitrageAmountsToSendToAmms;
        uint256[] memory routingAmountsToSendToAmms;
        address[] memory factoriesSupportingTokenPair;
        uint256 yGross = 0;
        console.log("Inside uniswapV2Call() - 1");
        {
            (
                factoriesSupportingTokenPair,
                routingAmountsToSendToAmms,
                arbitrageAmountsToSendToAmms,
                whereToRepayLoan
            ) = abi.decode(
                data,
                (address[], uint256[], Structs.AmountsToSendToAmm[], address)
            );
            console.log("Inside uniswapV2Call() - 2");

            address token0 = IUniswapV2Pair(msg.sender).token0();
            address token1 = IUniswapV2Pair(msg.sender).token1();
            assert(
                msg.sender ==
                    IUniswapV2Factory(whereToRepayLoan).getPair(token0, token1)
            );
            console.log("Inside uniswapV2Call() - 3");

            (tokenIn, tokenOut) = amount0Out == 0
                ? (token0, token1)
                : (token1, token0);

            console.log("Inside uniswapV2Call() - 4");

            for (uint256 i = 0; i < arbitrageAmountsToSendToAmms.length; i++) {
                if (arbitrageAmountsToSendToAmms[i].y != 0) {
                    executeSwap(
                        factoriesSupportingTokenPair[i],
                        tokenOut,
                        tokenIn,
                        arbitrageAmountsToSendToAmms[i].y
                    );
                }
            }
            console.log("Inside uniswapV2Call() - 5");

            for (uint256 i = 0; i < arbitrageAmountsToSendToAmms.length; i++) {
                if (arbitrageAmountsToSendToAmms[i].x != 0) {
                    yGross += executeSwap(
                        factoriesSupportingTokenPair[i],
                        tokenIn,
                        tokenOut,
                        arbitrageAmountsToSendToAmms[i].x +
                            routingAmountsToSendToAmms[i]
                    );
                }
            }
            console.log("Inside uniswapV2Call() - 6");
        }
        //TODO: check if this is the correct formula for interest on the loan; can we consider this when thinking about arbitrage opportunity?
        // uint256 returnLoan = (tokenOutAmount * 1003) / 1000;

        //return the loan
        TransferHelper.safeTransfer(
            tokenOut,
            whereToRepayLoan,
            amount0Out + amount1Out
        );
        console.log("Inside uniswapV2Call() - 7");

        assert(IERC20(tokenIn).balanceOf(address(this)) == 0);
        assert(
            IERC20(tokenOut).balanceOf(address(this)) ==
                yGross - amount0Out - amount1Out
        );
        console.log("Inside uniswapV2Call() - end");
    }
}
