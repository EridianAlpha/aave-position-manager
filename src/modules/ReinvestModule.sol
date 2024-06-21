// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ================================================================
// │                           IMPORTS                            │
// ================================================================

// Aave Imports
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// Interface Imports
import {IAavePM} from "../interfaces/IAavePM.sol";
import {ITokenSwapsModule} from "../interfaces/ITokenSwapsModule.sol";
import {IAaveFunctionsModule} from "../interfaces/IAaveFunctionsModule.sol";
import {IReinvestModule} from "../interfaces/IReinvestModule.sol";

// ================================================================
// │                     REINVEST MODULE CONTRACT                 │
// ================================================================

/// @title Aave Functions Module for the Aave Position Manager
/// @author EridianAlpha
/// @notice This contract contains the functions for AavePM to borrow USDC,
///         swap to wstETH, and supply to Aave maintaining the target health factor.
contract ReinvestModule is IReinvestModule {
    // ================================================================
    // │                         MODULE SETUP                         │
    // ================================================================

    /// @notice The version of the contract.
    /// @dev Contract is upgradeable so the version is a constant set on each implementation contract.
    string internal constant VERSION = "0.0.1";

    /// @notice Getter function to get the contract version.
    /// @dev Public function to allow anyone to view the contract version.
    /// @return version The contract version.
    function getVersion() public pure returns (string memory version) {
        return VERSION;
    }

    address public immutable aavePMProxyAddress;

    constructor(address _aavePMProxyAddress) {
        aavePMProxyAddress = _aavePMProxyAddress;
    }

    modifier onlyAavePM() {
        if (address(this) != aavePMProxyAddress) revert ReinvestModule__InvalidAavePMProxyAddress();
        _;
    }

    // ================================================================
    // │                       MODULE FUNCTIONS                       │
    // ================================================================

    /// @notice Reinvest the Aave position.
    /// @dev This function reinvests the Aave position by borrowing USDC, swapping to wstETH, and supplying it back to Aave.
    /// @return reinvestedDebt The amount of debt reinvested.
    function reinvest() public onlyAavePM returns (uint256 reinvestedDebt) {
        IAavePM aavePM = IAavePM(address(this));

        // Set the initial reinvested debt to 0.
        reinvestedDebt = 0;

        (
            uint256 initialCollateralBase,
            uint256 totalDebtBase,
            uint256 currentLiquidationThreshold,
            uint256 initialHealthFactorScaled,
            uint16 healthFactorTarget,
            address aavePoolAddress,
            address wstETHAddress,
            address usdcAddress
        ) = abi.decode(
            aavePM.delegateCallHelper(
                "aaveFunctionsModule",
                abi.encodeWithSelector(IAaveFunctionsModule.getCurrentPositionValues.selector, aavePM)
            ),
            (uint256, uint256, uint256, uint256, uint16, address, address, address)
        );

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
        aavePM.delegateCallHelper(
            "aaveFunctionsModule",
            abi.encodeWithSelector(IAaveFunctionsModule.checkHealthFactorAboveMinimum.selector, new bytes(0))
        );

        // Return the reinvested debt and reinvested collateral so the state can be updated on the AavePM contract.
        return (reinvestedDebt);
    }

    /// @notice Reinvest the Aave position.
    /// @dev This function actions the reinvestment of the Aave position.
    /// @param aavePM The Aave Position Manager contract.
    /// @param totalDebtBase The total debt in base units.
    /// @param aavePoolAddress The address of the Aave pool.
    /// @param usdcAddress The address of the USDC token.
    /// @param wstETHAddress The address of the wstETH token.
    /// @param initialCollateralBase The initial collateral in base units.
    /// @param currentLiquidationThreshold The current liquidation threshold.
    /// @param healthFactorTarget The target health factor.
    /// @return borrowAmountUSDC The amount of USDC borrowed.
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
        uint256 maxBorrowUSDC = abi.decode(
            IAavePM(address(this)).delegateCallHelper(
                "aaveFunctionsModule",
                abi.encodeWithSelector(
                    IAaveFunctionsModule.calculateMaxBorrowUSDC.selector,
                    initialCollateralBase,
                    totalDebtBase,
                    currentLiquidationThreshold,
                    healthFactorTarget
                )
            ),
            (uint256)
        );

        // Calculate the additional amount to borrow to reach the target health factor.
        uint256 additionalBorrowUSDC = maxBorrowUSDC - totalDebtBase;

        // _aaveBorrow input parameter is decimals to the dollar, so divide by 1e2 to get the correct amount.
        borrowAmountUSDC = additionalBorrowUSDC / 1e2;
        aavePM.delegateCallHelper(
            "aaveFunctionsModule",
            abi.encodeWithSelector(
                IAaveFunctionsModule.aaveBorrow.selector, aavePoolAddress, usdcAddress, borrowAmountUSDC
            )
        );

        // Swap borrowed USDC ➜ WETH ➜ wstETH then supply to Aave.
        aavePM.delegateCallHelper(
            "tokenSwapsModule", abi.encodeWithSelector(ITokenSwapsModule.swapTokens.selector, "USDC/ETH", "USDC", "ETH")
        );
        aavePM.delegateCallHelper(
            "tokenSwapsModule",
            abi.encodeWithSelector(ITokenSwapsModule.swapTokens.selector, "wstETH/ETH", "ETH", "wstETH")
        );

        aavePM.delegateCallHelper(
            "aaveFunctionsModule",
            abi.encodeWithSelector(
                IAaveFunctionsModule.aaveSupply.selector,
                aavePoolAddress,
                wstETHAddress,
                aavePM.getContractBalance("wstETH")
            )
        );

        return borrowAmountUSDC;
    }
}
