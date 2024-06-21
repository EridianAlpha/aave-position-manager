// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title RebalanceModule interface
/// @notice This interface defines the essential structures and functions for the RebalanceModule contract.
interface IRebalanceModule {
    error RebalanceModule__InvalidAavePMProxyAddress();

    function getVersion() external pure returns (string memory version);
    function rebalance() external returns (uint256 repaymentAmountUSDC);
}
