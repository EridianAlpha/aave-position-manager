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

        // Set the initial reinvested debt and reinvested collateral to 0.
        reinvestedDebt = 0;
        reinvestedCollateral = 0;

        (
            uint256 initialCollateralBase,
            uint256 totalDebtBase,
            uint256 currentLiquidationThreshold,
            uint256 initialHealthFactorScaled,
            uint16 healthFactorTarget,
            address aavePoolAddress,
            address wstETHAddress,
            address usdcAddress
        ) = _getCurrentPositionValues(aavePM);

        // TODO: Calculate this elsewhere.
        uint16 healthFactorTargetRange = 10;

        // If the health factor is above the target, borrow more USDC and reinvest.
        if (initialHealthFactorScaled > healthFactorTarget + healthFactorTargetRange) {
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
        // It is also used to calculate the reinvested collateral by returning the updated position values.
        (uint256 endCollateralBase,,,,,) = _checkHealthFactorAboveMinimum(aavePM, aavePoolAddress);

        // Calculate the reinvested collateral by comparing the initial and end collateral values.
        if (endCollateralBase > initialCollateralBase) {
            reinvestedCollateral += (endCollateralBase - initialCollateralBase) / 1e2;
        }

        // Return the reinvested debt and reinvested collateral so the state can be updated on the AavePM contract.
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
