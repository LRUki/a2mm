// SPDX-License-Identifier: MIT
pragma solidity  0.6.6 || 0.8.3;

interface IReserveFeed {
	function getUniV2Reserves(address tokenIn, address tokenOut) external view returns (uint, uint);
	function getSushiReserves(address tokenIn, address tokenOut) external view returns (uint, uint);
}