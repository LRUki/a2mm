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

    function flashSwap(
        address tokenIn,
        address tokenOut,
        uint256 yToLoan,
        address whereToLoan,
        uint256 amountIn,
        uint256 ySum,
        uint256 totalYBorrowedBefore,
        address[] memory factoriesSupportingTokenPair,
        uint256[] memory routingAmountsToSendToAmms,
        Structs.AmountsToSendToAmm[] memory arbitrageAmountsToSendToAmms,
        Structs.Amm[] memory amms
    ) public {
        address pairAddress = IUniswapV2Factory(whereToLoan).getPair(
            tokenIn,
            tokenOut
        );

        bytes memory data;
        {
            address[] memory newFactoriesSupportingTokenPair = new address[](
                factoriesSupportingTokenPair.length - 1
            );
            uint256[] memory newRoutingAmountsToSendToAmms = new uint256[](
                routingAmountsToSendToAmms.length - 1
            );
            Structs.AmountsToSendToAmm[]
                memory newArbitrageAmountsToSendToAmms = new Structs.AmountsToSendToAmm[](
                    arbitrageAmountsToSendToAmms.length - 1
                );

            {
                uint256 j = 0;
                for (
                    uint256 i = 0;
                    i < routingAmountsToSendToAmms.length;
                    i++
                ) {
                    if (factoriesSupportingTokenPair[i] != whereToLoan) {
                        newFactoriesSupportingTokenPair[
                            j
                        ] = factoriesSupportingTokenPair[i];
                        newRoutingAmountsToSendToAmms[
                            j
                        ] = routingAmountsToSendToAmms[i];
                        newArbitrageAmountsToSendToAmms[
                            j++
                        ] = arbitrageAmountsToSendToAmms[i];
                    }
                }
            }

            data = abi.encode(
                newFactoriesSupportingTokenPair,
                newRoutingAmountsToSendToAmms,
                newArbitrageAmountsToSendToAmms,
                whereToLoan,
                amountIn,
                ySum,
                totalYBorrowedBefore,
                amms
            );
        }

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

    struct V2CallHelper {
        address tokenIn;
        address tokenOut;
        address whereToRepayLoan;
        Structs.AmountsToSendToAmm[] arbitrageAmountsToSendToAmms;
        uint256[] routingAmountsToSendToAmms;
        address[] factoriesSupportingTokenPair;
        uint256 amountIn;
        uint256 ySum;
        uint256 totalYBorrowedBefore;
        Structs.Amm[] amms;
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
            v2CallHelper.routingAmountsToSendToAmms,
            v2CallHelper.arbitrageAmountsToSendToAmms,
            v2CallHelper.whereToRepayLoan,
            v2CallHelper.amountIn,
            v2CallHelper.ySum,
            v2CallHelper.totalYBorrowedBefore,
            v2CallHelper.amms
        ) = abi.decode(
            data,
            (
                address[],
                uint256[],
                Structs.AmountsToSendToAmm[],
                address,
                uint256,
                uint256,
                uint256,
                Structs.Amm[]
            )
        );

        {
            address token0 = IUniswapV2Pair(msg.sender).token0();
            address token1 = IUniswapV2Pair(msg.sender).token1();

            assert(
                msg.sender ==
                    IUniswapV2Factory(v2CallHelper.whereToRepayLoan).getPair(
                        token0,
                        token1
                    )
            );

            (v2CallHelper.tokenIn, v2CallHelper.tokenOut) = amount0Out == 0
                ? (token0, token1)
                : (token1, token0);
        }

        uint256 totalYBorrowedNow = amount0Out +
            amount1Out +
            v2CallHelper.totalYBorrowedBefore;
        if (v2CallHelper.ySum > totalYBorrowedNow) {
            address whereToLoan = address(0);
            uint256 whereToLoanIndex;
            for (
                uint256 i = 0;
                i < v2CallHelper.factoriesSupportingTokenPair.length;
                i++
            ) {
                if (
                    v2CallHelper.routingAmountsToSendToAmms[i] +
                        v2CallHelper.arbitrageAmountsToSendToAmms[i].x !=
                    0
                ) {
                    assert(v2CallHelper.arbitrageAmountsToSendToAmms[i].y == 0);
                    whereToLoan = v2CallHelper.factoriesSupportingTokenPair[i];
                    whereToLoanIndex = i;
                    break;
                }
            }
            require(whereToLoan != address(0), "no AMMs left; insufficient loan");
            uint256 yFromLoanAmm = SharedFunctions.quantityOfYForX(
                v2CallHelper.amms[whereToLoanIndex],
                v2CallHelper.routingAmountsToSendToAmms[whereToLoanIndex] +
                    v2CallHelper
                        .arbitrageAmountsToSendToAmms[whereToLoanIndex]
                        .x
            );
            flashSwap(
                v2CallHelper.tokenIn,
                v2CallHelper.tokenOut,
                yFromLoanAmm,
                whereToLoan,
                v2CallHelper.amountIn,
                v2CallHelper.ySum,
                totalYBorrowedNow,
                v2CallHelper.factoriesSupportingTokenPair,
                v2CallHelper.routingAmountsToSendToAmms,
                v2CallHelper.arbitrageAmountsToSendToAmms,
                v2CallHelper.amms
            );
            assert(IERC20(v2CallHelper.tokenIn).balanceOf(address(this)) == 0);
            return;
        }

        uint256 xToRepay = v2CallHelper.amountIn;
        for (
            uint256 i = 0;
            i < v2CallHelper.arbitrageAmountsToSendToAmms.length;
            i++
        ) {
            if (v2CallHelper.arbitrageAmountsToSendToAmms[i].y != 0) {
                require(
                    v2CallHelper.factoriesSupportingTokenPair[i] !=
                        v2CallHelper.whereToRepayLoan,
                    "Can't swap where borrowing"
                );
                xToRepay += executeSwap(
                    v2CallHelper.factoriesSupportingTokenPair[i],
                    v2CallHelper.tokenOut,
                    v2CallHelper.tokenIn,
                    v2CallHelper.arbitrageAmountsToSendToAmms[i].y
                );
            }
        }

        for (
            uint256 i = 0;
            i < v2CallHelper.arbitrageAmountsToSendToAmms.length;
            i++
        ) {
            uint256 xToSend = v2CallHelper.arbitrageAmountsToSendToAmms[i].x +
                v2CallHelper.routingAmountsToSendToAmms[i];
            if (xToSend != 0) {
                require(
                    v2CallHelper.factoriesSupportingTokenPair[i] !=
                        v2CallHelper.whereToRepayLoan,
                    "Can't swap where borrowing"
                );
                xToRepay -= xToSend;
                executeSwap(
                    v2CallHelper.factoriesSupportingTokenPair[i],
                    v2CallHelper.tokenIn,
                    v2CallHelper.tokenOut,
                    xToSend
                );
            }
        }

        TransferHelper.safeTransfer(v2CallHelper.tokenIn, msg.sender, xToRepay);
        assert(IERC20(v2CallHelper.tokenIn).balanceOf(address(this)) == 0);
    }
}
