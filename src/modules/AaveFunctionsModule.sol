// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ================================================================
// │                           IMPORTS                            │
// ================================================================

// Aave Imports
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
import {IPriceOracle} from "@aave/aave-v3-core/contracts/interfaces/IPriceOracle.sol";

// Uniswap Imports
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

// Interface Imports
import {IAavePM} from "../interfaces/IAavePM.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {ITokenSwapsModule} from "src/interfaces/ITokenSwapsModule.sol";

// ================================================================
// │                   AAVEFUNCTIONS CONTRACT                     │
// ================================================================

/// @notice // TODO: Add comment
contract AaveFunctionsModule {
    /// @notice Deposit all wstETH into Aave.
    ///      // TODO: Update comment.
    function aaveSupply(address aavePoolAddress, address tokenAddress, uint256 tokenBalance) public {
        // Takes all tokens in the contract and deposits it into Aave
        TransferHelper.safeApprove(tokenAddress, aavePoolAddress, tokenBalance);
        IPool(aavePoolAddress).deposit(tokenAddress, tokenBalance, address(this), 0);
    }

    /// @notice Withdraw wstETH from Aave.
    ///      // TODO: Update comment.
    function aaveWithdrawCollateral(address aavePoolAddress, address tokenAddress, uint256 withdrawAmount) public {
        IPool(aavePoolAddress).withdraw(tokenAddress, withdrawAmount, address(this));
    }

    /// @notice Borrow USDC from Aave.
    ///      // TODO: Update comment.
    /// @param borrowAmount The amount of USDC to borrow. 8 decimal places to the dollar. e.g. 100000000 = $1.00.
    function aaveBorrow(address aavePoolAddress, address tokenAddress, uint256 borrowAmount) public {
        IPool(aavePoolAddress).borrow(tokenAddress, borrowAmount, 2, 0, address(this));
    }

    /// @notice Repay USDC debt to Aave.
    ///      // TODO: Update comment.
    /// @param repayAmount The amount of USDC to repay. 8 decimal places to the dollar. e.g. 100000000 = $1.00.
    function aaveRepayDebt(address aavePoolAddress, address tokenAddress, uint256 repayAmount) public {
        TransferHelper.safeApprove(tokenAddress, aavePoolAddress, repayAmount);
        IPool(aavePoolAddress).repay(tokenAddress, repayAmount, 2, address(this));
    }

    /// @notice // TODO: Add comment.
    /// @dev This function is used to avoid code duplication in the Reinvest and Rebalance contracts.
    function getCurrentPositionValues(IAavePM aavePM)
        public
        view
        returns (
            uint256 initialCollateralBase,
            uint256 totalDebtBase,
            uint256 currentLiquidationThreshold,
            uint256 initialHealthFactorScaled,
            uint16 healthFactorTarget,
            address aavePoolAddress,
            address wstETHAddress,
            address usdcAddress
        )
    {
        // Get data from state
        aavePoolAddress = aavePM.getContractAddress("aavePool");
        wstETHAddress = aavePM.getTokenAddress("wstETH");
        usdcAddress = aavePM.getTokenAddress("USDC");

        // Solidity does not allow you to mix inline type definitions and
        // existing variable assignments in tuple destructuring.
        // So declare this variable here as it's the only one not assigned as a return value.
        uint256 initialHealthFactor;

        // Get the current Aave account data.
        (initialCollateralBase, totalDebtBase,, currentLiquidationThreshold,, initialHealthFactor) =
            IPool(aavePoolAddress).getUserAccountData(address(this));

        // Scale the initial health factor to 2 decimal places by dividing by 1e16.
        initialHealthFactorScaled = initialHealthFactor / 1e16;

        // Get the current health factor target.
        healthFactorTarget = aavePM.getHealthFactorTarget();

        return (
            initialCollateralBase,
            totalDebtBase,
            currentLiquidationThreshold,
            initialHealthFactorScaled,
            healthFactorTarget,
            aavePoolAddress,
            wstETHAddress,
            usdcAddress
        );
    }

    /// @notice // TODO: Add comment.
    function checkHealthFactorAboveMinimum()
        public
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        IAavePM aavePM = IAavePM(address(this));
        address aavePoolAddress = aavePM.getContractAddress("aavePool");

        // TODO: Improve check.
        (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor) =
            IPool(aavePoolAddress).getUserAccountData(address(this));
        uint256 healthFactorScaled = healthFactor / 1e16;
        if (healthFactorScaled < (aavePM.getHealthFactorTargetMinimum() - 1)) {
            revert IAavePM.AavePM__HealthFactorBelowMinimum();
        }

        return
            (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor);
    }

    /// @notice // TODO: Add comment.
    function getTotalCollateralDelta(
        uint256 totalCollateralBase,
        uint256 reinvestedDebtTotal,
        uint256 suppliedCollateralTotal
    ) public pure returns (uint256 delta, bool isPositive) {
        uint256 reinvestedAndSuppliedCollateralBase = (reinvestedDebtTotal + suppliedCollateralTotal) * 1e2;
        if (totalCollateralBase < reinvestedAndSuppliedCollateralBase) {
            delta = (reinvestedAndSuppliedCollateralBase - totalCollateralBase) / 1e2;
            isPositive = false;
        } else {
            delta = (totalCollateralBase - reinvestedAndSuppliedCollateralBase) / 1e2;
            isPositive = true;
        }
        return (delta, isPositive);
    }

    /// @notice // TODO: Add comment
    function convertExistingBalanceToWstETHAndSupplyToAave() public returns (uint256 suppliedCollateral) {
        IAavePM aavePM = IAavePM(address(this));
        address aavePoolAddress = aavePM.getContractAddress("aavePool");
        address wstETHAddress = aavePM.getTokenAddress("wstETH");

        if (aavePM.getContractBalance("ETH") > 0) {
            IWETH9(IAavePM(address(this)).getTokenAddress("WETH")).deposit{value: address(this).balance}();
        }
        if (aavePM.getContractBalance("USDC") > 0) {
            aavePM.delegateCallHelper(
                "tokenSwapsModule",
                abi.encodeWithSelector(ITokenSwapsModule.swapTokens.selector, "USDC/ETH", "USDC", "ETH")
            );
        }
        if (aavePM.getContractBalance("WETH") > 0) {
            aavePM.delegateCallHelper(
                "tokenSwapsModule",
                abi.encodeWithSelector(ITokenSwapsModule.swapTokens.selector, "wstETH/ETH", "ETH", "wstETH")
            );
        }

        uint256 wstETHBalance = aavePM.getContractBalance("wstETH");
        if (wstETHBalance > 0) {
            // Get collateral before
            (uint256 initialCollateralBase,,,,,) = IPool(aavePoolAddress).getUserAccountData(address(this));

            aaveSupply(aavePoolAddress, wstETHAddress, wstETHBalance);

            // Get collateral after
            (uint256 endCollateralBase,,,,,) = IPool(aavePoolAddress).getUserAccountData(address(this));

            // Calculate the amount of wstETH supplied to Aave.
            suppliedCollateral = 0;
            if (endCollateralBase - initialCollateralBase > 0) {
                suppliedCollateral = (endCollateralBase - initialCollateralBase) / 1e2;
            }
            return suppliedCollateral;
        }
    }

    /// @notice // TODO: Add comment
    function calculateMaxBorrowUSDC(
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 currentLiquidationThreshold,
        uint16 healthFactorTarget
    ) public pure returns (uint256 maxBorrowUSDC) {
        /* 
        *   Calculate the maximum amount of USDC that can be borrowed.
        *       - Minus totalDebtBase from totalCollateralBase to get the actual collateral not including reinvested debt.
        *       - currentLiquidationThreshold is a percentage with 4 decimal places e.g. 8250 = 82.5%.
        *       - healthFactorTarget is a value with 2 decimal places e.g. 200 = 2.00.
        *       - totalCollateralBase is in USD base unit with 8 decimals to the dollar e.g. 100000000 = $1.00.
        *       - totalDebtBase is in USD base unit with 8 decimals to the dollar e.g. 100000000 = $1.00.
        *       - 1e2 used as healthFactorTarget has 2 decimal places.
        *
        *                   ((totalCollateralBase - totalDebtBase) * currentLiquidationThreshold ) 
        *  maxBorrowUSDC = ------------------------------------------------------------------------
        *                          ((healthFactorTarget * 1e2) - currentLiquidationThreshold)      
        */
        maxBorrowUSDC = (
            ((totalCollateralBase - totalDebtBase) * currentLiquidationThreshold)
                / ((uint256(healthFactorTarget) * 1e2) - currentLiquidationThreshold)
        );
    }
}
