// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ReinvestModule interface
/// @notice This interface defines the essential structures and functions for the ReinvestModule contract.
interface IReinvestModule {
    error ReinvestModule__InvalidAavePMProxyAddress();

    function getVersion() external pure returns (string memory version);
    function reinvest() external returns (uint256 reinvestedDebt);
}
