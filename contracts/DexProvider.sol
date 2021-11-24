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
// import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
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

        bytes memory data = abi.encode(
            factoriesSupportingTokenPair,
            routingAmountsToSendToAmms,
            arbitrageAmountsToSendToAmms,
            whereToLoan
        );

        IUniswapV2Pair(pairAddress).swap(
            0,
            yToLoan,
            address(this),
            data
        );
    }

    function uniswapV2Call(
        address sender,
        uint256 tokenInAmount,
        uint256 tokenOutAmount,
        bytes calldata data
    ) external override {
        require(tokenOutAmount != 0, "We must be loaning Y!");
        require(tokenInAmount == 0, "We should not be loaning any X!");
        (
        address[] memory factoriesSupportingTokenPair,
        uint256[] memory routingAmountsToSendToAmms,
        Structs.AmountsToSendToAmm[] memory arbitrageAmountsToSendToAmms,
        address whereToRepayLoan
        ) = abi.decode(
            data,
            (address[], uint256[], Structs.AmountsToSendToAmm[], address)
        );
        //TODO: make sure that tokenIn and tokenOut are the right way around
        IUniswapV2Pair pair = IUniswapV2Pair(msg.sender);
        // tokenIn will be treated as X
        address tokenIn = pair.token0();
        // tokenIn will be treated as Y
        address tokenOut = pair.token1();
        assert(
            msg.sender ==
                IUniswapV2Factory(_UNIV2_FACTORY_ADDRESS).getPair(
                    tokenIn,
                    tokenOut
                )
        ); // ensure that msg.sender is a V2 pair

        //TODO: we are doing more transactions than we have to, and hence paying a higher transaction fee. Implement it in the way that Liyi mentioned, where we can return the loan in both X and Y
        for (uint256 i = 0; i < routingAmountsToSendToAmms.length; i++) {
            if (routingAmountsToSendToAmms[i] != 0) {
                TransferHelper.safeTransfer(tokenIn, msg.sender, routingAmountsToSendToAmms[i]);
            }
        }

        for (uint256 i = 0; i < arbitrageAmountsToSendToAmms.length; i++) {
            if (arbitrageAmountsToSendToAmms[i].x != 0) {
                TransferHelper.safeTransfer(tokenOut, msg.sender, arbitrageAmountsToSendToAmms[i].y);
            }
        }

        uint256 ySum = 0;
        Structs.Amm memory temp = Structs.Amm(0, 0);
        for (uint256 i = 0; i < arbitrageAmountsToSendToAmms.length; i++) {
            if (arbitrageAmountsToSendToAmms[i].x != 0) {
                (temp.x, temp.y) = getReserves(factoriesSupportingTokenPair[i], tokenIn, tokenOut);
                ySum += SharedFunctions.quantityOfYForX(temp, arbitrageAmountsToSendToAmms[i].x);
                TransferHelper.safeTransfer(tokenIn, msg.sender, arbitrageAmountsToSendToAmms[i].x);
            }
        }
        //TODO: check if this is the correct formula for interest on the loan
        uint256 returnLoan = tokenOutAmount * 1003 / 1000;

        TransferHelper.safeTransfer(tokenOut, whereToRepayLoan, ySum - returnLoan);
    }
}
