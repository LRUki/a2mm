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

import "@uniswap/v2-periphery/contracts/interfaces/V1/IUniswapV1Exchange.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

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

    struct FlashSwapHelper {
        bytes data;
        address whereToLoan;
        uint256 yToLoan;
        uint256 whereToLoanIndex;
        address[] newFactoriesSupportingTokenPair;
        Structs.AmountsToSendToAmm[] newAmountsToSendToAmms;
    }

    function flashSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 noOfXToYSwapsLeft,
        uint256 totalYBorrowedBefore,
        address[] memory factoriesSupportingTokenPair,
        Structs.AmountsToSendToAmm[] memory amountsToSendToAmms,
        Structs.Amm[] memory amms,
        uint256[] memory xToYSwaps,
        address[] memory xToYSwapsFactories
    ) public {
        FlashSwapHelper memory flashSwapHelper;
        flashSwapHelper.whereToLoan = address(0);
        {
            // find an AMM to take a loan out from - this can be any one which we have an X->Y transaction on.
            for (uint256 i = 0; i < factoriesSupportingTokenPair.length; i++) {
                if (amountsToSendToAmms[i].x != 0) {
                    assert(amountsToSendToAmms[i].y == 0);
                    flashSwapHelper.whereToLoan = factoriesSupportingTokenPair[
                        i
                    ];
                    flashSwapHelper.whereToLoanIndex = i;
                    break;
                }
            }
            require(
                flashSwapHelper.whereToLoan != address(0),
                "no AMMs left; insufficient loan"
            );
            // determine how big the loan needs to be
            flashSwapHelper.yToLoan = SharedFunctions.quantityOfYForX(
                amms[flashSwapHelper.whereToLoanIndex],
                amountsToSendToAmms[flashSwapHelper.whereToLoanIndex].x
            );

            // filter out the AMM which we will be borrowing from next
            flashSwapHelper.newFactoriesSupportingTokenPair = new address[](
                factoriesSupportingTokenPair.length - 1
            );
            flashSwapHelper
                .newAmountsToSendToAmms = new Structs.AmountsToSendToAmm[](
                amountsToSendToAmms.length - 1
            );
            Structs.Amm[] memory newAmms = new Structs.Amm[](amms.length - 1);
            {
                uint256 j = 0;
                for (uint256 i = 0; i < amountsToSendToAmms.length; i++) {
                    if (
                        factoriesSupportingTokenPair[i] !=
                        flashSwapHelper.whereToLoan
                    ) {
                        flashSwapHelper.newFactoriesSupportingTokenPair[
                                j
                            ] = factoriesSupportingTokenPair[i];
                        newAmms[j] = amms[i];
                        flashSwapHelper.newAmountsToSendToAmms[
                                j++
                            ] = amountsToSendToAmms[i];
                    }
                }
            }

            noOfXToYSwapsLeft--;
            flashSwapHelper.data = abi.encode(
                flashSwapHelper.newFactoriesSupportingTokenPair,
                flashSwapHelper.newAmountsToSendToAmms,
                newAmms,
                amountIn,
                noOfXToYSwapsLeft,
                totalYBorrowedBefore,
                xToYSwaps,
                xToYSwapsFactories
            );
        }

        address pairAddress = IUniswapV2Factory(flashSwapHelper.whereToLoan)
            .getPair(tokenIn, tokenOut);

        (address token0, ) = UniswapV2Library.sortTokens(tokenIn, tokenOut);
        (uint256 amount0Out, uint256 amount1Out) = token0 == tokenIn
            ? (uint256(0), flashSwapHelper.yToLoan)
            : (flashSwapHelper.yToLoan, uint256(0));

        IUniswapV2Pair(pairAddress).swap(
            amount0Out,
            amount1Out,
            address(this),
            flashSwapHelper.data
        );
    }

    struct V2CallHelper {
        address tokenIn;
        address tokenOut;
        Structs.AmountsToSendToAmm[] amountsToSendToAmms;
        address[] factoriesSupportingTokenPair;
        uint256 amountIn;
        uint256 noOfXToYSwapsLeft;
        uint256 totalYBorrowedBefore;
        Structs.Amm[] amms;
        uint256[] xToYSwaps;
        address[] xToYSwapsFactories;
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

        V2CallHelper memory v2CallHelper;
        (
            v2CallHelper.factoriesSupportingTokenPair,
            v2CallHelper.amountsToSendToAmms,
            v2CallHelper.amms,
            v2CallHelper.amountIn,
            v2CallHelper.noOfXToYSwapsLeft,
            v2CallHelper.totalYBorrowedBefore,
            v2CallHelper.xToYSwaps,
            v2CallHelper.xToYSwapsFactories
        ) = abi.decode(
            data,
            (
                address[],
                Structs.AmountsToSendToAmm[],
                Structs.Amm[],
                uint256,
                uint256,
                uint256,
                uint256[],
                address[]
            )
        );

        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        (v2CallHelper.tokenIn, v2CallHelper.tokenOut) = amount0Out == 0
            ? (token0, token1)
            : (token1, token0);

        uint256 totalYBorrowedNow = amount0Out +
            amount1Out +
            v2CallHelper.totalYBorrowedBefore;
        if (v2CallHelper.noOfXToYSwapsLeft > 0) {
            // We (possibly) have insufficient Y, so need to also take a loan out somewhere else.
            flashSwap(
                v2CallHelper.tokenIn,
                v2CallHelper.tokenOut,
                v2CallHelper.amountIn,
                v2CallHelper.noOfXToYSwapsLeft,
                totalYBorrowedNow,
                v2CallHelper.factoriesSupportingTokenPair,
                v2CallHelper.amountsToSendToAmms,
                v2CallHelper.amms,
                v2CallHelper.xToYSwaps,
                v2CallHelper.xToYSwapsFactories
            );
            return;
        }

        for (uint256 i = 0; i < v2CallHelper.amountsToSendToAmms.length; i++) {
            if (v2CallHelper.amountsToSendToAmms[i].y != 0) {
                executeSwap(
                    v2CallHelper.factoriesSupportingTokenPair[i],
                    v2CallHelper.tokenOut,
                    v2CallHelper.tokenIn,
                    v2CallHelper.amountsToSendToAmms[i].y
                );
            }
        }

        for (uint256 i = 0; i < v2CallHelper.xToYSwaps.length; i++) {
            TransferHelper.safeTransfer(v2CallHelper.tokenIn, IUniswapV2Factory(v2CallHelper.xToYSwapsFactories[i]).getPair(token0, token1), v2CallHelper.xToYSwaps[i]);
        }

        console.log("leftover X = %s", IERC20(v2CallHelper.tokenIn).balanceOf(address(this)));
//        require(IERC20(v2CallHelper.tokenIn).balanceOf(address(this)) == 0, "All of X should be spent");
    }
}
