// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice // TODO: Add comment
interface IReinvestModule {
    function reinvest() external returns (uint256 reinvestedDebt);
}