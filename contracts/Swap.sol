// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity 0.6.6 || 0.8.3;
pragma experimental ABIEncoderV2;

import "./libraries/Structs.sol";
import "./libraries/Arbitrage.sol";
import "./libraries/Route.sol";
import "./libraries/SharedFunctions.sol";
import "./interfaces/IWETH9.sol";
import "./DexProvider.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";

import "hardhat/console.sol";

contract Swap is DexProvider {
  Structs.AmountsToSendToAmm[3] private _amountsToSendToAmm;

  event SwapEvent(uint256 amountIn, uint256 amountOut);

  // @param tokenIn - the first token we are interested in; usually considered to be the token which the user is putting in
  // @param tokenOut - the second token we are interested in; usually considered to be the token which the user wants to get back
  // @return factoriesSupportingTokenPair - an array of factory addresses which have the token pair
  // @return amms - a list of AMM structs containing the reserves of each AMM which has the token pair
  function _factoriesWhichSupportPair(address tokenIn, address tokenOut)
    private
    view
    returns (
      address[] memory factoriesSupportingTokenPair,
      Structs.Amm[] memory amms
    )
  {
    uint256 noFactoriesSupportingTokenPair = 0;
    for (uint256 i = 0; i < _factoryAddresses.length; i++) {
      if (
        IUniswapV2Factory(_factoryAddresses[i]).getPair(tokenIn, tokenOut) !=
        address(0x0)
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
        IUniswapV2Factory(_factoryAddresses[i]).getPair(tokenIn, tokenOut) !=
        address(0x0)
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

  function swap(
    address tokenIn,
    address tokenOut,
    uint256 amountIn
  ) external {
    require(
      IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn),
      "user needs to approve"
    );
    (
      address[] memory factoriesSupportingTokenPair,
      Structs.Amm[] memory amms
    ) = _factoriesWhichSupportPair(tokenIn, tokenOut);

    (
      uint256[] memory routingAmountsToSendToAmms,
      Structs.AmountsToSendToAmm[] memory arbitrageAmountsToSendToAmms,
      uint256 amountOfYtoFlashLoan,
      uint256 whereToLoanIndex
    ) = calculateRouteAndArbitarge(amms, amountIn);
    console.log(amountOfYtoFlashLoan, "<- loan amount");
    for (uint256 i = 0; i < _amountsToSendToAmm.length; ++i) {
      _amountsToSendToAmm[i].x =
        arbitrageAmountsToSendToAmms[i].x +
        routingAmountsToSendToAmms[i];
      _amountsToSendToAmm[i].y = arbitrageAmountsToSendToAmms[i].y;
    }

    uint256 yToLoan = 0;
    for (uint256 i = 0; i < _amountsToSendToAmm.length; ++i) {
      yToLoan += arbitrageAmountsToSendToAmms[i].y;
    }
    console.log(yToLoan, "TOLOAN");
    uint256 amountOut = 0;
    if (yToLoan > 0) {
      //TODO: how to get the amountOut from flashSwap?
      console.log("FLASH");
      bytes memory data = abi.encode(
        factoriesSupportingTokenPair,
        routingAmountsToSendToAmms,
        arbitrageAmountsToSendToAmms
      );

      //            for (uint256 i = 0; i < amms.length; i++) {
      //                console.log(factoriesSupportingTokenPair[i]);
      //                console.log(routingAmountsToSendToAmms[i]);
      //                console.log(arbitrageAmountsToSendToAmms[i].x, arbitrageAmountsToSendToAmms[i].y);
      //            }

      address whereToLoan = factoriesSupportingTokenPair[whereToLoanIndex];
      flashSwap(tokenIn, tokenOut, yToLoan, whereToLoan, data);
    } else {
      console.log("NO FLASH");
      for (uint256 i = 0; i < _amountsToSendToAmm.length; ++i) {
        //TODO: the 'require' below this is fishy... it's possible that the user had enough of Y for the arbitrage, and hence doesn't need a flash loan, but is still arbitraging and hence transferring Y for X
        require(_amountsToSendToAmm[i].y == 0, "y should be 0");
        if (_amountsToSendToAmm[i].x > 0) {
          amountOut += executeSwap(
            factoriesSupportingTokenPair[i],
            tokenIn,
            tokenOut,
            _amountsToSendToAmm[i].x
          );
        }
      }
    }

    require(
      IERC20(tokenOut).transfer(msg.sender, amountOut),
      "token failed to be sent back"
    );
    emit SwapEvent(amountIn, amountOut);
  }

  // @param tokenIn - the token which the user will provide/is wanting to sell
  // @param tokenOut - the token which the user will be given/is wanting to buy
  // @param amountIn - how much of tokenIn the user is wanting to exchange for totalOut amount of tokenOut
  // @return totalOut - the amount of token the user will get in return for amountIn of tokenIn
  function simulateSwap(
    address tokenIn,
    address tokenOut,
    uint256 amountIn
  ) external view returns (uint256 totalOut) {
    (, Structs.Amm[] memory amms0) = _factoriesWhichSupportPair(
      tokenIn,
      tokenOut
    );
    Structs.Amm[] memory amms1 = new Structs.Amm[](amms0.length);
    for (uint256 i = 0; i < amms0.length; i++) {
      (amms1[i].x, amms1[i].y) = (amms0[i].x, amms0[i].y);
    }

    totalOut = 0;
    (
      uint256[] memory routes,
      Structs.AmountsToSendToAmm[] memory arbitrages,
      uint256 flashLoanRequired,
      uint256 whereToLoanIndex
    ) = calculateRouteAndArbitarge(amms0, amountIn);
    for (uint256 i = 0; i < amms0.length; i++) {
      totalOut += SharedFunctions.quantityOfYForX(
        amms1[i],
        routes[i] + arbitrages[i].x
      );
    }
    return totalOut - flashLoanRequired;
  }

  // @param arbitragingFor - the token which the user will provide/is wanting to arbitrage for
  // @param intermediateToken - the token which the user is wanting to user during the arbitrage step \
  // (arbitragingFor -> intermediateToken -> arbitragingFor)
  // @return arbitrageGain - how much of token 'arbitragingFor' the user will gain for executing this arbitrage
  // @return tokenInRequired - how much of 'arbitragingFor' the user would be required to own to complete the \
  // arbitrage without a flash loan, using our arbitraging algorithm
  function simulateArbitrage(address arbitragingFor, address intermediateToken)
    external
    view
    returns (uint256 arbitrageGain, uint256 tokenInRequired)
  {
    (, Structs.Amm[] memory amms0) = _factoriesWhichSupportPair(
      arbitragingFor,
      intermediateToken
    );
    Structs.Amm[] memory amms1 = new Structs.Amm[](amms0.length);
    for (uint256 i = 0; i < amms0.length; i++) {
      (amms1[i].x, amms1[i].y) = (amms0[i].x, amms0[i].y);
    }

    Structs.AmountsToSendToAmm[] memory arbitrages;
    (arbitrages, tokenInRequired, ) = Arbitrage.arbitrageForY(amms0, 0);
    arbitrageGain = 0;
    for (uint256 i = 0; i < amms0.length; i++) {
      arbitrageGain += SharedFunctions.quantityOfYForX(
        amms1[i],
        arbitrages[i].x
      );
    }
  }

  // @notice - for now, only the first two AMMs in the list will actually be considered for anything
  // @param amountOfX - how much the user is willing to trade
  // @return amountsToSendToAmms - the pair of values indicating how much of X and Y should be sent to each AMM \
  // (ordered in the same way as the AMMs were passed in)
  // @return flashLoanRequiredAmount - how big of a flash loan we would need to take out to successfully \
  // complete the transation. This is done for the arbitrage step.
  function calculateRouteAndArbitarge(
    Structs.Amm[] memory amms,
    uint256 amountOfX
  )
    public
    pure
    returns (
      uint256[] memory routingAmountsToSendToAmms,
      Structs.AmountsToSendToAmm[] memory arbitrageAmountsToSendToAmms,
      uint256 amountOfYtoFlashLoan,
      uint256 whereToLoanIndex
    )
  {
    whereToLoanIndex = Arbitrage.MAX_INT;
    bool shouldArbitrage;

    uint256 totalYGainedFromRouting;
    (
      routingAmountsToSendToAmms,
      totalYGainedFromRouting,
      shouldArbitrage,
      amms
    ) = Route.route(amms, amountOfX);

    amountOfYtoFlashLoan = 0;
    arbitrageAmountsToSendToAmms = new Structs.AmountsToSendToAmm[](1);
    arbitrageAmountsToSendToAmms[0] = Structs.AmountsToSendToAmm(0, 0);
    if (shouldArbitrage && amms.length > 1) {
      Structs.AmountsToSendToAmm[] memory arbitrages;
      (
        arbitrageAmountsToSendToAmms,
        amountOfYtoFlashLoan,
        whereToLoanIndex
      ) = Arbitrage.arbitrageForY(amms, totalYGainedFromRouting);
    }
  }

  function calculateRouteAndArbitargeWrapper(
    uint256[2][] memory ammsArray,
    uint256 amountOfX
  )
    public
    pure
    returns (
      uint256[] memory,
      Structs.AmountsToSendToAmm[] memory,
      uint256,
      uint256
    )
  {
    Structs.Amm[] memory amms = new Structs.Amm[](ammsArray.length);
    for (uint256 i = 0; i < ammsArray.length; ++i) {
      amms[i] = Structs.Amm(ammsArray[i][0], ammsArray[i][1]);
    }
    return calculateRouteAndArbitarge(amms, amountOfX);
  }

  //allow contract to recieve eth
  //not sure if we need it but might as well
  //solhint-disable-next-line
  receive() external payable {}
}
