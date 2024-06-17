// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice // TODO: Add comment
interface IRebalanceModule {
    function rebalance() external returns (uint256 repaymentAmountUSDC);
}
