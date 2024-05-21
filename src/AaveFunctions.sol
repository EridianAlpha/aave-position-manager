// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ================================================================
// │                           IMPORTS                            │
// ================================================================

// Aave Imports
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// Uniswap Imports
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

// ================================================================
// │                   AAVEFUNCTIONS CONTRACT                     │
// ================================================================

/// @notice // TODO: Add comment
contract AaveFunctions {
    /// @notice Deposit all wstETH into Aave.
    ///      // TODO: Update comment.
    function _aaveSupply(address aavePoolAddress, address tokenAddress, uint256 tokenBalance) internal {
        // Takes all tokens in the contract and deposits it into Aave
        TransferHelper.safeApprove(tokenAddress, aavePoolAddress, tokenBalance);
        IPool(aavePoolAddress).deposit(tokenAddress, tokenBalance, address(this), 0);
    }

    /// @notice Withdraw wstETH from Aave.
    ///      // TODO: Update comment.
    function _aaveWithdrawCollateral(address aavePoolAddress, address tokenAddress, uint256 withdrawAmount) internal {
        // TODO: This should have a HF check to make sure that this withdrawal doesn't drop the HF below the target.
        IPool(aavePoolAddress).withdraw(tokenAddress, withdrawAmount, address(this));
    }

    /// @notice Borrow USDC from Aave.
    ///      // TODO: Update comment.
    /// @param borrowAmount The amount of USDC to borrow. 8 decimal places to the dollar. e.g. 100000000 = $1.00.
    function _aaveBorrow(address aavePoolAddress, address tokenAddress, uint256 borrowAmount) internal {
        // TODO: This should have a HF check to make sure that this borrow doesn't drop the HF below the target.
        IPool(aavePoolAddress).borrow(tokenAddress, borrowAmount, 2, 0, address(this));
    }

    /// @notice Repay USDC debt to Aave.
    ///      // TODO: Update comment.
    /// @param repayAmount The amount of USDC to repay. 8 decimal places to the dollar. e.g. 100000000 = $1.00.
    function _aaveRepayDebt(address aavePoolAddress, address tokenAddress, uint256 repayAmount) internal {
        TransferHelper.safeApprove(tokenAddress, aavePoolAddress, repayAmount);
        IPool(aavePoolAddress).repay(tokenAddress, repayAmount, 2, address(this));
    }
}