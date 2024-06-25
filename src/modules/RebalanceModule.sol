// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ================================================================
// │                           IMPORTS                            │
// ================================================================

// Aave Imports
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// Interface Imports
import {IAavePM} from "src/interfaces/IAavePM.sol";
import {IAaveFunctionsModule} from "src/interfaces/IAaveFunctionsModule.sol";
import {IRebalanceModule} from "src/interfaces/IRebalanceModule.sol";

// ================================================================
// │                    REBALANCE MODULE CONTRACT                 │
// ================================================================

/// @title Rebalance Module for the Aave Position Manager
/// @author EridianAlpha
/// @notice This contract contains the functions for AavePM to rebalance the Aave position by repaying debt to increase the health factor.
contract RebalanceModule is IRebalanceModule {
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
        if (address(this) != aavePMProxyAddress) revert RebalanceModule__InvalidAavePMProxyAddress();
        _;
    }

    /// @notice The buffer for the Health Factor Target rebalance calculation
    uint16 public constant REBALANCE_HFT_BUFFER = 10;

    // ================================================================
    // │                       MODULE FUNCTIONS                       │
    // ================================================================

    /// @notice Rebalance the Aave position.
    /// @dev Caller must have `MANAGER_ROLE`.
    ///      The function rebalances the Aave position.
    ///      If the health factor is below the target, it repays debt to increase the health factor.
    function rebalance() public onlyAavePM returns (uint256 repaymentAmountUSDC) {
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
        ) = abi.decode(
            aavePM.delegateCallHelper(
                "aaveFunctionsModule",
                abi.encodeWithSelector(IAaveFunctionsModule.getCurrentPositionValues.selector, aavePM)
            ),
            (uint256, uint256, uint256, uint256, uint16, address, address, address)
        );

        // If the health factor is below the target, repay debt to increase the health factor.
        if (initialHealthFactorScaled < (healthFactorTarget - REBALANCE_HFT_BUFFER)) {
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
        aavePM.delegateCallHelper(
            "aaveFunctionsModule",
            abi.encodeWithSelector(IAaveFunctionsModule.checkHealthFactorAboveMinimum.selector, new bytes(0))
        );

        // Return the reinvested debt and reinvested collateral so the state can be updated on the AavePM contract.
        return (repaymentAmountUSDC);
    }

    /// @notice Repay debt to increase the health factor.
    /// @dev This function repays debt to increase the health factor.
    /// @param totalDebtBase The total debt in base units.
    /// @param aavePoolAddress The address of the Aave pool.
    /// @param usdcAddress The address of the USDC token.
    /// @param totalCollateralBase The total collateral in base units.
    /// @param currentLiquidationThreshold The current liquidation threshold.
    /// @param healthFactorTarget The target health factor.
    /// @return repaymentAmountUSDC The amount of USDC repaid.
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
            uint256 maxBorrowUSDC = abi.decode(
                IAavePM(address(this)).delegateCallHelper(
                    "aaveFunctionsModule",
                    abi.encodeWithSelector(
                        IAaveFunctionsModule.calculateMaxBorrowUSDC.selector,
                        totalCollateralBase,
                        totalDebtBase,
                        currentLiquidationThreshold,
                        healthFactorTarget
                    )
                ),
                (uint256)
            );

            // Calculate the repayment amount required to reach the target health factor.
            repaymentAmountUSDC = (totalDebtBase - maxBorrowUSDC) / 1e2;
        }

        // Take out a flash loan for the USDC amount needed to repay and rebalance the health factor.
        // flashLoanSimple `amount` input parameter is decimals to the dollar, so divide by 1e2 to get the correct amount
        IPool(aavePoolAddress).flashLoanSimple(address(this), usdcAddress, repaymentAmountUSDC, bytes(""), 0);
    }
}
