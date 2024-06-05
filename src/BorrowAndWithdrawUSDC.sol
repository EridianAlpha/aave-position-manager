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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ================================================================
// │               BORROW AND WITHDRAW USDC CONTRACT              │
// ================================================================

/// @notice // TODO: Add comment
contract BorrowAndWithdrawUSDC is TokenSwaps, AaveFunctions {
    /// @notice // TODO: Add comment
    function _borrowAndWithdrawUSDC(uint256 borrowAmountUSDC, address _owner)
        internal
        returns (uint256 repaidReinvestedDebt)
    {
        IAavePM aavePM = IAavePM(address(this));

        // Get data from state
        address aavePoolAddress = aavePM.getContractAddress("aavePool");
        address usdcAddress = aavePM.getTokenAddress("USDC");
        (uint256 totalCollateralBase, uint256 totalDebtBase,, uint256 currentLiquidationThreshold,,) =
            IPool(aavePoolAddress).getUserAccountData(address(this));

        uint256 healthFactorTarget = aavePM.getHealthFactorTarget();

        // Calculate the health factor after only borrowing USDC, assuming no reinvested debt is repaid
        uint256 healthFactorAfterBorrowOnlyScaled =
            ((totalCollateralBase * currentLiquidationThreshold) / (totalDebtBase + borrowAmountUSDC * 1e2)) / 1e2;

        // Set the initial repaid reinvested debt to 0
        repaidReinvestedDebt = 0;

        // TODO: Improve check
        if (healthFactorAfterBorrowOnlyScaled > healthFactorTarget - 2) {
            // The HF is above target after borrow of USDC only,
            // so the USDC can be borrowed without repaying reinvested debt
            _aaveBorrow(aavePoolAddress, usdcAddress, borrowAmountUSDC);
        } else if (aavePM.getReinvestedDebtTotal() > 0) {
            // The requested borrow amount would put the HF below the target
            // so repaying some reinvested debt is required
            repaidReinvestedDebt = _borrowCalculation(
                totalCollateralBase, totalDebtBase, currentLiquidationThreshold, borrowAmountUSDC, healthFactorTarget
            );

            // Flashloan to repay the dept and increase the Health Factor
            IPool(aavePoolAddress).flashLoanSimple(address(this), usdcAddress, repaidReinvestedDebt, bytes(""), 0);

            // Borrow the requested amount of USDC
            _aaveBorrow(aavePoolAddress, usdcAddress, borrowAmountUSDC);
        }

        IERC20(usdcAddress).transfer(_owner, borrowAmountUSDC);
        return (repaidReinvestedDebt);
    }

    function _borrowCalculation(
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 currentLiquidationThreshold,
        uint256 borrowAmountUSDC,
        uint256 healthFactorTarget
    ) private pure returns (uint256 repaidReinvestedDebt) {
        /* 
        *   Calculate the maximum amount of USDC that can be borrowed.
        *       - Solve for x to find the amount of reinvested debt to repay
        *       - flashLoanSimple `amount` input parameter is decimals to the dollar, so divide by 1e2 to get the correct amount
        *       - As the result is negative, case as int256 to avoid underflow and then recast to uint256 and invert after the calculation
        * 
        *                          (totalCollateralBase - x) * currentLiquidationThreshold
        *   Health Factor Target = -------------------------------------------------------
        *                                   totalDebtBase - x + borrowAmountUSDC
        */
        int256 calcRepaidReinvestedDebt = (
            (
                int256(totalCollateralBase) * int256(currentLiquidationThreshold / 1e2)
                    - int256(totalDebtBase) * int256(healthFactorTarget)
                    - int256(borrowAmountUSDC) * 1e2 * int256(healthFactorTarget)
            ) / (int256(currentLiquidationThreshold / 1e2) - int256(healthFactorTarget))
        ) / 1e2;

        // Invert the value if it's negative
        repaidReinvestedDebt =
            uint256(calcRepaidReinvestedDebt < 0 ? -calcRepaidReinvestedDebt : calcRepaidReinvestedDebt);
    }
}
