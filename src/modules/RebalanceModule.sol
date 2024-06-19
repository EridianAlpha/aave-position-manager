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
// │                       REBALANCE CONTRACT                     │
// ================================================================

/// @notice // TODO: Add comment
contract RebalanceModule is IRebalanceModule {
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

    address immutable aavePMProxyAddress;

    constructor(address _aavePMProxyAddress) {
        aavePMProxyAddress = _aavePMProxyAddress;
    }

    modifier onlyAavePM() {
        if (address(this) != aavePMProxyAddress) revert RebalanceModule__InvalidAavePMProxyAddress();
        _;
    }

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
        aavePM.delegateCallHelper(
            "aaveFunctionsModule",
            abi.encodeWithSelector(IAaveFunctionsModule.checkHealthFactorAboveMinimum.selector, new bytes(0))
        );

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
