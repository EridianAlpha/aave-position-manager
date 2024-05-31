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
// │                        REINVEST CONTRACT                     │
// ================================================================

/// @notice // TODO: Add comment
contract Reinvest is TokenSwaps, AaveFunctions {
    /// @notice // TODO: Add comment
    function _reinvest() internal returns (uint256 reinvestedDebt, uint256 reinvestedCollateral) {
        IAavePM aavePM = IAavePM(address(this));

        // Get data from state
        address aavePoolAddress = aavePM.getContractAddress("aavePool");
        address wstETHAddress = aavePM.getTokenAddress("wstETH");
        address usdcAddress = aavePM.getTokenAddress("USDC");

        // Get the current Aave account data.
        (
            uint256 initialCollateralBase,
            uint256 totalDebtBase,
            ,
            uint256 currentLiquidationThreshold,
            ,
            uint256 initialHealthFactor
        ) = IPool(aavePoolAddress).getUserAccountData(address(this));

        // Scale the initial health factor to 2 decimal places by dividing by 1e16.
        uint256 initialHealthFactorScaled = initialHealthFactor / 1e16;

        // Get the current health factor target.
        uint16 healthFactorTarget = aavePM.getHealthFactorTarget();

        // Set the initial reinvested debt to 0.
        reinvestedDebt = 0;

        // TODO: Calculate this elsewhere.
        uint16 healthFactorTargetRange = 10;

        if (initialHealthFactorScaled > healthFactorTarget + healthFactorTargetRange) {
            // If the health factor is above the target, borrow more USDC and reinvest.
            reinvestedDebt = _reinvestAction(
                aavePM,
                totalDebtBase,
                aavePoolAddress,
                usdcAddress,
                wstETHAddress,
                initialCollateralBase,
                currentLiquidationThreshold,
                healthFactorTarget
            );
        } else {
            revert IAavePM.AavePM__ReinvestNotRequired();
        }

        // Safety check to ensure the health factor is above the minimum target.
        // TODO: Improve check.
        (uint256 endCollateralBase,,,,, uint256 endHealthFactor) =
            IPool(aavePoolAddress).getUserAccountData(address(this));
        uint256 endHealthFactorScaled = endHealthFactor / 1e16;

        if (endHealthFactorScaled < (aavePM.getHealthFactorTargetMinimum() - 1)) {
            revert IAavePM.AavePM__HealthFactorBelowMinimum();
        }

        // Set the initial reinvested collateral to 0.
        reinvestedCollateral = 0;

        if (endCollateralBase > initialCollateralBase) {
            reinvestedCollateral += (endCollateralBase - initialCollateralBase) / 1e2;
        }
        return (reinvestedDebt, reinvestedCollateral);
    }

    function _reinvestAction(
        IAavePM aavePM,
        uint256 totalDebtBase,
        address aavePoolAddress,
        address usdcAddress,
        address wstETHAddress,
        uint256 initialCollateralBase,
        uint256 currentLiquidationThreshold,
        uint16 healthFactorTarget
    ) private returns (uint256 borrowAmountUSDC) {
        // Calculate the maximum amount of USDC that can be borrowed.
        uint256 maxBorrowUSDC = _calculateMaxBorrowUSDC(
            initialCollateralBase, totalDebtBase, currentLiquidationThreshold, healthFactorTarget
        );

        // Calculate the additional amount to borrow to reach the target health factor.
        uint256 additionalBorrowUSDC = maxBorrowUSDC - totalDebtBase;

        // _aaveBorrow input parameter is decimals to the dollar, so divide by 1e2 to get the correct amount.
        borrowAmountUSDC = additionalBorrowUSDC / 1e2;
        _aaveBorrow(aavePoolAddress, usdcAddress, borrowAmountUSDC);

        // Swap borrowed USDC ➜ WETH ➜ wstETH then supply to Aave.
        _swapTokens("USDC/ETH", "USDC", "ETH");
        _swapTokens("wstETH/ETH", "ETH", "wstETH");
        _aaveSupply(aavePoolAddress, wstETHAddress, aavePM.getContractBalance("wstETH"));

        return borrowAmountUSDC;
    }
}
