// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice // TODO: Add comment
interface IBorrowAndWithdrawUSDCModule {
    function borrowAndWithdrawUSDC(uint256 borrowAmountUSDC, address _owner)
        external
        returns (uint256 repaidReinvestedDebt);
}
