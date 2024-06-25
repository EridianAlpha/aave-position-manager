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
    string public constant VERSION = "0.0.1";

    /// @notice The address of the AavePM proxy contract.
    /// @dev The AavePM proxy address is set on deployment and is immutable.
    address public immutable aavePMProxyAddress;

    /// @notice Contract constructor to set the AavePM proxy address.
    /// @dev The AavePM proxy address is set on deployment and is immutable.
    /// @param _aavePMProxyAddress The address of the AavePM proxy contract.
    constructor(address _aavePMProxyAddress) {
        aavePMProxyAddress = _aavePMProxyAddress;
    }

    /// @notice Modifier to check that only the AavePM contract is the caller.
    /// @dev Uses `address(this)` since this contract is called by the AavePM contract using delegatecall.
    modifier onlyAavePM() {
        if (address(this) != aavePMProxyAddress) revert ReinvestModule__InvalidAavePMProxyAddress();
        _;
    }

    /// @notice The buffer for the Health Factor Target reinvest calculation
    uint16 public constant REINVEST_HFT_BUFFER = 10;

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

        // If the health factor is above the target, borrow more USDC and reinvest.
        if (initialHealthFactorScaled > healthFactorTarget + REINVEST_HFT_BUFFER) {
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
