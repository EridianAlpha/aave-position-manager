// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ================================================================
// │                           IMPORTS                            │
// ================================================================

// Aave Imports
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// Interface Imports
import {IAavePM} from "../interfaces/IAavePM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAaveFunctionsModule} from "../interfaces/IAaveFunctionsModule.sol";
import {IBorrowAndWithdrawUSDCModule} from "../interfaces/IBorrowAndWithdrawUSDCModule.sol";

// ================================================================
// │           BORROW AND WITHDRAW USDC MODULE CONTRACT           │
// ================================================================

/// @title Borrow and Withdraw USDC Module for the Aave Position Manager
/// @author EridianAlpha
/// @notice This contract contains the functions for AavePM to borrow and withdraw USDC from the Aave protocol.
contract BorrowAndWithdrawUSDCModule is IBorrowAndWithdrawUSDCModule {
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
        if (address(this) != aavePMProxyAddress) revert BorrowAndWithdrawUSDCModule__InvalidAavePMProxyAddress();
        _;
    }

    /// @notice The buffer for the Health Factor Target calculation
    uint16 public constant HFT_BUFFER = 2;

    // ================================================================
    // │                       MODULE FUNCTIONS                       │
    // ================================================================

    /// @notice Borrow USDC from the Aave protocol and withdraw it to the specified owner.
    /// @dev This function borrows USDC from the Aave protocol and withdraws it to the specified owner.
    /// @param borrowAmountUSDC The amount of USDC to borrow.
    /// @param _owner The address to withdraw the USDC to.
    /// @return repaidReinvestedDebt The amount of reinvested debt repaid (if any) to increase the Health Factor.
    function borrowAndWithdrawUSDC(uint256 borrowAmountUSDC, address _owner)
        public
        onlyAavePM
        returns (uint256 repaidReinvestedDebt)
    {
        IAavePM aavePM = IAavePM(address(this));

        // Get data from state
        address aavePoolAddress = aavePM.getContractAddress("aavePool");
        address usdcAddress = aavePM.getTokenAddress("USDC");
        (uint256 totalCollateralBase, uint256 totalDebtBase,, uint256 currentLiquidationThreshold,,) =
            IPool(aavePoolAddress).getUserAccountData(address(this));

        uint256 healthFactorTarget = aavePM.getHealthFactorTarget();

        // Calculate the health factor after only borrowing USDC, assuming no reinvested debt is repaid.
        uint256 healthFactorAfterBorrowOnlyScaled =
            ((totalCollateralBase * currentLiquidationThreshold) / (totalDebtBase + borrowAmountUSDC * 1e2)) / 1e2;

        // Set the initial repaid reinvested debt to 0.
        repaidReinvestedDebt = 0;

        // TODO: This is a temporary solution (if doing nothing, else logic action) to give full branch coverage.
        if (healthFactorAfterBorrowOnlyScaled > healthFactorTarget - HFT_BUFFER) {
            // The HF is above target after borrow of USDC only,
            // so the USDC can be borrowed without repaying reinvested debt.
        } else {
            // The requested borrow amount would put the HF below the target
            // so repaying some reinvested debt is required.
            repaidReinvestedDebt = _borrowCalculation(
                totalCollateralBase, totalDebtBase, currentLiquidationThreshold, borrowAmountUSDC, healthFactorTarget
            );

            // Flashloan to repay the dept and increase the Health Factor.
            IPool(aavePoolAddress).flashLoanSimple(address(this), usdcAddress, repaidReinvestedDebt, bytes(""), 0);
        }

        aavePM.delegateCallHelper(
            "aaveFunctionsModule",
            abi.encodeWithSelector(
                IAaveFunctionsModule.aaveBorrow.selector, aavePoolAddress, usdcAddress, borrowAmountUSDC
            )
        );

        IERC20(usdcAddress).transfer(_owner, borrowAmountUSDC);
        return (repaidReinvestedDebt);
    }

    /// @notice Calculate the amount of reinvested debt to repay to increase the Health Factor.
    /// @dev This function calculates the amount of reinvested debt to repay to increase the Health Factor.
    /// @param totalCollateralBase The total collateral base in the Aave pool.
    /// @param totalDebtBase The total debt base in the Aave pool.
    /// @param currentLiquidationThreshold The current liquidation threshold in the Aave pool.
    /// @param borrowAmountUSDC The amount of USDC to borrow.
    /// @param healthFactorTarget The target Health Factor.
    /// @return repaidReinvestedDebt The amount of reinvested debt repaid to increase the Health Factor.
    function _borrowCalculation(
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 currentLiquidationThreshold,
        uint256 borrowAmountUSDC,
        uint256 healthFactorTarget
    ) private pure returns (uint256 repaidReinvestedDebt) {
        /* 
        *   Calculate the maximum amount of USDC that can be borrowed.
        *       - Solve for x to find the amount of reinvested debt to repay.
        *       - flashLoanSimple `amount` input parameter is decimals to the dollar, so divide by 1e2 to get the correct amount.
        *       - As the result is negative, case as int256 to avoid underflow and then recast to uint256 and invert after the calculation.
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
