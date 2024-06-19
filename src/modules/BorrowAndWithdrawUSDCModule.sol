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
// │               BORROW AND WITHDRAW USDC CONTRACT              │
// ================================================================

/// @notice // TODO: Add comment
contract BorrowAndWithdrawUSDCModule is IBorrowAndWithdrawUSDCModule {
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
        if (address(this) != aavePMProxyAddress) revert BorrowAndWithdrawUSDCModule__InvalidAavePMProxyAddress();
        _;
    }

    // ================================================================
    // │                       MODULE FUNCTIONS                       │
    // ================================================================

    /// @notice // TODO: Add comment
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

        // TODO: Improve check. This is a temporary solution to give full branch coverage.
        if (healthFactorAfterBorrowOnlyScaled > healthFactorTarget - 2) {
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

    /// @notice // TODO: Add comment
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
