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
    ///      The function rebalances the Aave position by converting any ETH to WETH, then WETH to wstETH.
    ///      It then deposits the wstETH into Aave.
    ///      If the health factor is below the target, it repays debt to increase the health factor.
    ///      If the health factor is above the target, it borrows more USDC and reinvests.
    function _rebalance() internal {
        IAavePM aavePM = IAavePM(address(this));

        // Get data from state
        address aavePoolAddress = aavePM.getContractAddress("aavePool");
        address wstETHAddress = aavePM.getTokenAddress("wstETH");
        address usdcAddress = aavePM.getTokenAddress("USDC");

        // Convert any existing tokens and supply to Aave.
        // TODO: This should be done in a separate function so it's not always done. Only do it if needed.
        if (aavePM.getContractBalance("ETH") > 0) _wrapETHToWETH();
        if (aavePM.getContractBalance("WETH") > 0) _swapTokens("wstETH/ETH", "ETH", "wstETH");
        if (aavePM.getContractBalance("wstETH") > 0) {
            _aaveSupply(aavePoolAddress, wstETHAddress, aavePM.getContractBalance("wstETH"));
        }

        // Get the current Aave account data.
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            ,
            uint256 currentLiquidationThreshold,
            ,
            uint256 initialHealthFactor
        ) = IPool(aavePoolAddress).getUserAccountData(address(this));

        // Scale the initial health factor to 2 decimal places.
        uint256 initialHealthFactorScaled = initialHealthFactor / aavePM.getAaveHealthFactorDivisor();

        // Get the current health factor target.
        uint16 healthFactorTarget = aavePM.getHealthFactorTarget();

        // Calculate the maximum amount of USDC that can be borrowed.
        uint256 maxBorrowUSDC =
            _calculateMaxBorrowUSDC(totalCollateralBase, totalDebtBase, currentLiquidationThreshold, healthFactorTarget);

        // TODO: Calculate this elsewhere.
        uint16 healthFactorTargetRange = 10;

        if (initialHealthFactorScaled < (healthFactorTarget - healthFactorTargetRange)) {
            // If the health factor is below the target, repay debt to increase the health factor.
            _repayDebt(aavePM, totalDebtBase, maxBorrowUSDC, aavePoolAddress, usdcAddress, wstETHAddress);
        } else if (initialHealthFactorScaled > healthFactorTarget + healthFactorTargetRange) {
            // If the health factor is above the target, borrow more USDC and reinvest.
            _reinvest(aavePM, totalDebtBase, maxBorrowUSDC, aavePoolAddress, usdcAddress, wstETHAddress);
        }

        // Safety check to ensure the health factor is above the minimum target.
        // TODO: Improve check.
        (,,,,, uint256 endHealthFactor) = IPool(aavePoolAddress).getUserAccountData(address(this));
        uint256 endHealthFactorScaled = endHealthFactor / aavePM.getAaveHealthFactorDivisor();
        if (endHealthFactorScaled < (aavePM.getHealthFactorTargetMinimum() - 1)) {
            // TODO: Move this error to CoreFunctions interface.
            revert IAavePM.AavePM__HealthFactorBelowMinimum();
        }
    }

    function _repayDebt(
        IAavePM aavePM,
        uint256 totalDebtBase,
        uint256 maxBorrowUSDC,
        address aavePoolAddress,
        address usdcAddress,
        address wstETHAddress
    ) private {
        // Calculate the repayment amount required to reach the target health factor.
        uint256 repaymentAmountUSDC = totalDebtBase - maxBorrowUSDC;

        // Take out a flash loan for the USDC amount needed to repay and rebalance the health factor.
        // flashLoanSimple `amount` input parameter is decimals to the dollar, so divide by 1e2 to get the correct amount
        IPool(aavePoolAddress).flashLoanSimple(address(this), usdcAddress, repaymentAmountUSDC / 1e2, bytes(""), 0);

        // Deposit any remaining dust to Aave.
        // TODO: Set a lower limit for dust so it doesn't cost more in gas to deposit than the amount.
        if (aavePM.getContractBalance("wstETH") > 0) {
            _aaveSupply(aavePoolAddress, wstETHAddress, aavePM.getContractBalance("wstETH"));
        }
        if (aavePM.getContractBalance("USDC") > 0) {
            _aaveRepayDebt(aavePoolAddress, usdcAddress, aavePM.getContractBalance("USDC"));
        }
    }

    function _reinvest(
        IAavePM aavePM,
        uint256 totalDebtBase,
        uint256 maxBorrowUSDC,
        address aavePoolAddress,
        address usdcAddress,
        address wstETHAddress
    ) private {
        // Calculate the additional amount to borrow to reach the target health factor.
        uint256 additionalBorrowUSDC = maxBorrowUSDC - totalDebtBase;

        // _aaveBorrow input parameter is decimals to the dollar, so divide by 1e2 to get the correct amount.
        uint256 borrowAmountUSDC = additionalBorrowUSDC / 1e2;
        _aaveBorrow(aavePoolAddress, usdcAddress, borrowAmountUSDC);

        // Swap borrowed USDC ➜ WETH ➜ wstETH then supply to Aave.
        _swapTokens("USDC/ETH", "USDC", "ETH");
        _swapTokens("wstETH/ETH", "ETH", "wstETH");
        _aaveSupply(aavePoolAddress, wstETHAddress, aavePM.getContractBalance("wstETH"));
    }
}
