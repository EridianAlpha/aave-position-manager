// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title BorrowAndWithdrawUSDCModule interface
/// @notice This interface defines the essential structures and functions for the BorrowAndWithdrawUSDCModule contract.
interface IBorrowAndWithdrawUSDCModule {
    error BorrowAndWithdrawUSDCModule__InvalidAavePMProxyAddress();

    function VERSION() external pure returns (string memory version);
    function aavePMProxyAddress() external view returns (address aavePMProxyAddress);

    function borrowAndWithdrawUSDC(uint256 borrowAmountUSDC, address _owner)
        external
        returns (uint256 repaidReinvestedDebt);
}
