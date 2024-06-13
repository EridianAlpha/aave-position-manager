// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ================================================================
// │                           IMPORTS                            │
// ================================================================

// Inherited Contract Imports
import {TokenSwaps} from "./TokenSwaps.sol";
import {AaveFunctions} from "./AaveFunctions.sol";

// Aave Imports
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// Interface Imports
import {IAavePM} from "./interfaces/IAavePM.sol";

// ================================================================
// │                       REBALANCE CONTRACT                     │
// ================================================================

/// @notice // TODO: Add comment
contract Rebalance is TokenSwaps, AaveFunctions {
    /// @notice Rebalance the Aave position.
    /// @dev Caller must have `MANAGER_ROLE`.
    ///      The function rebalances the Aave position.
    ///      If the health factor is below the target, it repays debt to increase the health factor.
    function _rebalance() internal returns (uint256 repaymentAmountUSDC) {
        IAavePM aavePM = IAavePM(address(this));

        (
            uint256 initialCollateralBase,
            uint256 totalDebtBase,
            uint256 currentLiquidationThreshold,
            uint256 initialHealthFactorScaled,
            uint16 healthFactorTarget,
            address aavePoolAddress,
            /* address wstETHAddress */
            ,
            address usdcAddress
        ) = _getCurrentPositionValues(aavePM);

        // TODO: Calculate this elsewhere.
        uint16 healthFactorTargetRange = 10;

        // If the health factor is below the target, repay debt to increase the health factor.
        if (initialHealthFactorScaled < (healthFactorTarget - healthFactorTargetRange)) {
            repaymentAmountUSDC = _repayDebt(
                totalDebtBase,
                aavePoolAddress,
                usdcAddress,
                initialCollateralBase,
                currentLiquidationThreshold,
                healthFactorTarget
            );
        } else {
            revert IAavePM.AavePM__RebalanceNotRequired();
        }

        // Safety check to ensure the health factor is above the minimum target.
        _checkHealthFactorAboveMinimum();

        // Return the reinvested debt and reinvested collateral so the state can be updated on the AavePM contract.
        return (repaymentAmountUSDC);
    }

    /// @notice // TODO: Add comment
    function _repayDebt(
        uint256 totalDebtBase,
        address aavePoolAddress,
        address usdcAddress,
        uint256 totalCollateralBase,
        uint256 currentLiquidationThreshold,
        uint16 healthFactorTarget
    ) private returns (uint256 repaymentAmountUSDC) {
        if (healthFactorTarget == type(uint16).max) {
            // If the health factor target is the maximum value,
            // then the maximum borrow amount is 0 and the whole position will be repayed + $1 to avoid dust.
            repaymentAmountUSDC = (totalDebtBase + 1e8) / 1e2;
        } else {
            // Calculate the maximum amount of USDC that can be borrowed.
            uint256 maxBorrowUSDC = _calculateMaxBorrowUSDC(
                totalCollateralBase, totalDebtBase, currentLiquidationThreshold, healthFactorTarget
            );

            // Calculate the repayment amount required to reach the target health factor.
            repaymentAmountUSDC = (totalDebtBase - maxBorrowUSDC) / 1e2;
        }

        // Take out a flash loan for the USDC amount needed to repay and rebalance the health factor.
        // flashLoanSimple `amount` input parameter is decimals to the dollar, so divide by 1e2 to get the correct amount
        IPool(aavePoolAddress).flashLoanSimple(address(this), usdcAddress, repaymentAmountUSDC, bytes(""), 0);
    }
}
