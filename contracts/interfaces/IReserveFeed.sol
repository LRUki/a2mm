// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity 0.8.3 || 0.6.6;

interface IReserveFeed {
	function getUniV2Reserves(address tokenIn, address tokenOut) external view returns (uint, uint);
	function getSushiReserves(address tokenIn, address tokenOut) external view returns (uint, uint);
}