// SPDX-License-Identifier: MIT
//solhint-disable-next-line
pragma solidity 0.6.6 || 0.8.3;
//Solidity 0.8 already comes with ABIEncoderV2 out of the box; however, 0.6.6 doesn't.
pragma experimental ABIEncoderV2;

import "./libraries/Structs.sol";
import "./libraries/SharedFunctions.sol";
import "./libraries/SharedFunctions.sol";
import "./libraries/IERC20.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "hardhat/console.sol";

contract DexProvider is IUniswapV2Callee {
    event ExecuteSwapEvent(uint256 amountIn, uint256 amountOut);

    address[3] private _factoryAddresses;

    constructor(address[3] memory factoryAddresses) public {
        _factoryAddresses = factoryAddresses;
    }

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
        TransferHelper.safeTransfer(tokenIn, pairAddress, amountIn);
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

    // @param tokenIn - the first token we are interested in; usually considered to be the token which the user is putting in
    // @param tokenOut - the second token we are interested in; usually considered to be the token which the user wants to get back
    // @return factoriesSupportingTokenPair - an array of factory addresses which have the token pair
    // @return amms - a list of AMM structs containing the reserves of each AMM which has the token pair
    function _factoriesWhichSupportPair(address tokenIn, address tokenOut)
        internal
        view
        returns (
            address[] memory factoriesSupportingTokenPair,
            Structs.Amm[] memory amms0,
            Structs.Amm[] memory amms1
        )
    {
        uint256 noFactoriesSupportingTokenPair;
        for (uint256 i = 0; i < _factoryAddresses.length; i++) {
            if (
                IUniswapV2Factory(_factoryAddresses[i]).getPair(
                    tokenIn,
                    tokenOut
                ) != address(0)
            ) {
                noFactoriesSupportingTokenPair++;
            }
        }

        amms0 = new Structs.Amm[](noFactoriesSupportingTokenPair);
        amms1 = new Structs.Amm[](noFactoriesSupportingTokenPair);
        factoriesSupportingTokenPair = new address[](
            noFactoriesSupportingTokenPair
        );
        uint256 j = 0;
        for (uint256 i = 0; i < _factoryAddresses.length; i++) {
            if (
                IUniswapV2Factory(_factoryAddresses[i]).getPair(
                    tokenIn,
                    tokenOut
                ) != address(0)
            ) {
                (amms0[j].x, amms0[j].y) = getReserves(
                    _factoryAddresses[i],
                    tokenIn,
                    tokenOut
                );
                (amms1[j].x, amms1[j].y) = (amms0[j].x, amms0[j].y);
                factoriesSupportingTokenPair[j++] = _factoryAddresses[i];
            }
        }
    }

    struct XTxn {
        uint256 x;
        address factory;
        Structs.Amm amm;
    }

    struct YTxn {
        uint256 y;
        address factory;
        Structs.Amm amm;
    }

    function flashSwap(
        address tokenIn,
        address tokenOut,
        uint256 noOfXToYSwapsLeft,
        XTxn[] memory xTxns,
        YTxn[] memory yTxns
    ) public {
        XTxn memory whereToLoan = xTxns[noOfXToYSwapsLeft - 1];
        require(
            whereToLoan.factory != address(0),
            "no AMMs left; insufficient loan"
        );
        // determine how big the loan needs to be
        uint256 yToLoan = SharedFunctions.quantityOfYForX(
            whereToLoan.amm,
            whereToLoan.x
        );

        bytes memory data = abi.encode(--noOfXToYSwapsLeft, xTxns, yTxns);

        address pairAddress = IUniswapV2Factory(whereToLoan.factory).getPair(
            tokenIn,
            tokenOut
        );

        (address token0, ) = UniswapV2Library.sortTokens(tokenIn, tokenOut);
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
        address,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata data
    ) external override {
        require(
            (amount0Out > 0 && amount1Out == 0) ||
                (amount0Out == 0 && amount1Out > 0),
            "flash loan invalid"
        );

        (
            uint256 noOfXToYSwapsLeft,
            XTxn[] memory xTxns,
            YTxn[] memory yTxns
        ) = abi.decode(data, (uint256, XTxn[], YTxn[]));

        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        (address tokenIn, address tokenOut) = amount0Out == 0
            ? (token0, token1)
            : (token1, token0);

        if (noOfXToYSwapsLeft > 0) {
            // We (possibly) have insufficient Y, so need to also take a loan out somewhere else.
            flashSwap(tokenIn, tokenOut, noOfXToYSwapsLeft, xTxns, yTxns);
            return;
        }

        for (uint256 i = 0; i < yTxns.length; i++) {
            executeSwap(yTxns[i].factory, tokenOut, tokenIn, yTxns[i].y);
        }

        for (uint256 i = 0; i < xTxns.length; i++) {
            TransferHelper.safeTransfer(
                tokenIn,
                IUniswapV2Factory(xTxns[i].factory).getPair(token0, token1),
                xTxns[i].x
            );
        }
    }
}
