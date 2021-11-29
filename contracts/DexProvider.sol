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
        console.log("Inside executeSwap() - start");
        address pairAddress = IUniswapV2Factory(factoryAddress).getPair(
            tokenIn,
            tokenOut
        );
        console.log("executeSwap() - 1");
        require(pairAddress != address(0), "This pool does not exist");
        (address token0, ) = UniswapV2Library.sortTokens(tokenIn, tokenOut);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairAddress)
            .getReserves();
        console.log("executeSwap() - 2");
        (uint256 reserveIn, uint256 reserveOut) = token0 == tokenIn
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
        console.log("executeSwap() - 3");
        amountOut = UniswapV2Library.getAmountOut(
            amountIn,
            reserveIn,
            reserveOut
        );
        console.log("executeSwap() - 4");
        IERC20(tokenIn).transfer(pairAddress, amountIn);
        (uint256 amount0Out, uint256 amount1Out) = token0 == tokenIn
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));
        console.log("executeSwap() - 5");
        IUniswapV2Pair(pairAddress).swap(
            amount0Out,
            amount1Out,
            address(this),
            new bytes(0)
        );
        console.log("executeSwap() - 6");
        emit ExecuteSwapEvent(amountIn, amountOut);
        console.log("Exiting executeSwap()");
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
        address[] memory factoriesSupportingTokenPair,
        uint256[] memory routingAmountsToSendToAmms,
        Structs.AmountsToSendToAmm[] memory arbitrageAmountsToSendToAmms
    ) public {
        console.log("Inside flashSwap()");
        address pairAddress = IUniswapV2Factory(whereToLoan).getPair(
            tokenIn,
            tokenOut
        );

        (address token0, ) = UniswapV2Library.sortTokens(tokenIn, tokenOut);

        bytes memory data = abi.encode(
            factoriesSupportingTokenPair,
            routingAmountsToSendToAmms,
            arbitrageAmountsToSendToAmms,
            whereToLoan,
            amountIn
        );

        console.log("flashSwap() - 1");
        //        {
        //        uint256 one;
        //        uint256 two;
        //        (one, two) = getReserves(whereToLoan, tokenIn, tokenOut);
        //        console.log("K = %s", one * two);
        //        }

        (uint256 amount0Out, uint256 amount1Out) = token0 == tokenIn
            ? (uint256(0), yToLoan)
            : (yToLoan, uint256(0));
        console.log("flashSwap() - 2");

        IUniswapV2Pair(pairAddress).swap(
            amount0Out,
            amount1Out,
            address(this),
            data
        );
        console.log("exiting flashSwap()");
    }

    function uniswapV2Call(
        address,
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
        uint256 xGross;
        uint256 yGross = 0;
        console.log("uniswapV2Call() - 1");
        {
            (
                factoriesSupportingTokenPair,
                routingAmountsToSendToAmms,
                arbitrageAmountsToSendToAmms,
                whereToRepayLoan,
                xGross
            ) = abi.decode(
                data,
                (
                    address[],
                    uint256[],
                    Structs.AmountsToSendToAmm[],
                    address,
                    uint256
                )
            );

            console.log(
                "factoriesSupportingTokenPair.length = %s",
                factoriesSupportingTokenPair.length
            );
            console.log("uniswapV2Call() - 2");

            {
                address token0 = IUniswapV2Pair(msg.sender).token0();
                address token1 = IUniswapV2Pair(msg.sender).token1();

                assert(
                    msg.sender ==
                        IUniswapV2Factory(whereToRepayLoan).getPair(
                            token0,
                            token1
                        )
                );
                console.log("uniswapV2Call() - 3");

                (tokenIn, tokenOut) = amount0Out == 0
                    ? (token0, token1)
                    : (token1, token0);
            }
            console.log(
                "start of uniswapV2Call() - Balance of this address (in Y): %s",
                IERC20(tokenOut).balanceOf(address(this))
            );

            console.log("uniswapV2Call() - 4");

            console.log("xGross: %s", xGross);
            for (uint256 i = 0; i < arbitrageAmountsToSendToAmms.length; i++) {
                console.log(
                    "routingAmountsToSendToAmms[i] = %s, arbitrageAmountsToSendToAmms[i].y = %s, arbitrageAmountsToSendToAmms[i].x = %s",
                    routingAmountsToSendToAmms[i],
                    arbitrageAmountsToSendToAmms[i].y,
                    arbitrageAmountsToSendToAmms[i].x
                );
                if (arbitrageAmountsToSendToAmms[i].y != 0) {
                    console.log(
                        "Y->X on %s i = %s",
                        factoriesSupportingTokenPair[i],
                        i
                    );
                    xGross += executeSwap(
                        factoriesSupportingTokenPair[i],
                        tokenOut,
                        tokenIn,
                        arbitrageAmountsToSendToAmms[i].y
                    );
                }
            }
            console.log("uniswapV2Call() - 5");

            console.log("xGross: %s", xGross);
            for (uint256 i = 0; i < arbitrageAmountsToSendToAmms.length; i++) {
                uint256 xToSend = arbitrageAmountsToSendToAmms[i].x +
                    routingAmountsToSendToAmms[i];
                if (
                    xToSend != 0 &&
                    factoriesSupportingTokenPair[i] != whereToRepayLoan
                ) {
                    console.log(
                        "X->Y on %s i = %s",
                        factoriesSupportingTokenPair[i],
                        i
                    );
                    xGross -= xToSend;
                    yGross += executeSwap(
                        factoriesSupportingTokenPair[i],
                        tokenIn,
                        tokenOut,
                        xToSend
                    );
                }
            }
            console.log("uniswapV2Call() - 6");
        }

        //        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        //        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        //        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        //        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        //        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        //        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        //            uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        //            uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
        //            uint256 newK = balance0Adjusted.mul(balance1Adjusted);
        //        }

        //return the loan
        console.log("xGross = %s, yGross = %s", xGross, yGross);
        TransferHelper.safeTransfer(tokenIn, msg.sender, xGross);
        TransferHelper.safeTransfer(
            tokenOut,
            msg.sender,
            yGross /*+1450000000000000000000000*/
        );
        //        TransferHelper.safeTransfer(tokenOut, msg.sender, yGross);
        //        TransferHelper.safeTransfer(tokenOut, msg.sender, );

        console.log("uniswapV2Call() - 7");

        //        {
        //            uint256 one;
        //            uint256 two;
        //            (one, two) = getReserves(whereToRepayLoan, tokenIn, tokenOut);
        //            one += xGross;
        //            two = two - amount0Out - amount1Out + yGross;
        //            console.log("new K = %s", one * two);
        //        }

        assert(IERC20(tokenIn).balanceOf(address(this)) == 0);
        console.log(
            "end of UniswapV2Call() - Balance of this address (in Y): %s",
            IERC20(tokenOut).balanceOf(address(this))
        );
    }
}
