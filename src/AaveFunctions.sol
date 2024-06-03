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
import {IAavePM} from "./interfaces/IAavePM.sol";

// Inherited Contract Imports
// TokenSwaps imported here so that the _swapTokens function can be used here and in the AavePM contract.
import {TokenSwaps} from "./TokenSwaps.sol";

// ================================================================
// │                   AAVEFUNCTIONS CONTRACT                     │
// ================================================================

/// @notice // TODO: Add comment
contract AaveFunctions is TokenSwaps {
    /// @notice Deposit all wstETH into Aave.
    ///      // TODO: Update comment.
    function _aaveSupply(address aavePoolAddress, address tokenAddress, uint256 tokenBalance) internal {
        // Takes all tokens in the contract and deposits it into Aave
        TransferHelper.safeApprove(tokenAddress, aavePoolAddress, tokenBalance);
        IPool(aavePoolAddress).deposit(tokenAddress, tokenBalance, address(this), 0);
    }

    /// @notice Withdraw wstETH from Aave.
    ///      // TODO: Update comment.
    function _aaveWithdrawCollateral(address aavePoolAddress, address tokenAddress, uint256 withdrawAmount) internal {
        // TODO: This should have a HF check to make sure that this withdrawal doesn't drop the HF below the target.
        IPool(aavePoolAddress).withdraw(tokenAddress, withdrawAmount, address(this));
    }

    /// @notice Borrow USDC from Aave.
    ///      // TODO: Update comment.
    /// @param borrowAmount The amount of USDC to borrow. 8 decimal places to the dollar. e.g. 100000000 = $1.00.
    function _aaveBorrow(address aavePoolAddress, address tokenAddress, uint256 borrowAmount) internal {
        // TODO: This should have a HF check to make sure that this borrow doesn't drop the HF below the target.
        IPool(aavePoolAddress).borrow(tokenAddress, borrowAmount, 2, 0, address(this));
    }

    /// @notice Repay USDC debt to Aave.
    ///      // TODO: Update comment.
    /// @param repayAmount The amount of USDC to repay. 8 decimal places to the dollar. e.g. 100000000 = $1.00.
    function _aaveRepayDebt(address aavePoolAddress, address tokenAddress, uint256 repayAmount) internal {
        TransferHelper.safeApprove(tokenAddress, aavePoolAddress, repayAmount);
        IPool(aavePoolAddress).repay(tokenAddress, repayAmount, 2, address(this));
    }

    /// @notice // TODO: Add comment.
    /// @dev This function is used to avoid code duplication in the Reinvest and Rebalance contracts.
    function _getCurrentPositionValues(IAavePM aavePM)
        internal
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
    function _checkHealthFactorAboveMinimum(IAavePM aavePM, address aavePoolAddress)
        internal
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
    function _getTotalDebtInterest(uint256 totalDebtBase, uint256 reinvestedDebtTotal, uint256 withdrawnUSDCTotal)
        internal
        pure
        returns (uint256 interest)
    {
        interest = 0;
        if ((totalDebtBase - (reinvestedDebtTotal * 1e2) - (withdrawnUSDCTotal * 1e2)) < 0) {
            revert IAavePM.AavePM__NegativeInterestCalc();
        } else {
            uint256 interestInBaseUnits = (totalDebtBase - (reinvestedDebtTotal * 1e2) - (withdrawnUSDCTotal * 1e2));
            interest = interestInBaseUnits / 1e2;
        }
        return interest;
    }

    /// @notice // TODO: Add comment.
    function _getTotalCollateralDelta(
        uint256 totalCollateralBase,
        uint256 reinvestedCollateralTotal,
        uint256 suppliedCollateralTotal
    ) internal pure returns (uint256 delta, bool isPositive) {
        int256 result =
            int256(totalCollateralBase - (reinvestedCollateralTotal * 1e2) - (suppliedCollateralTotal * 1e2));
        if (result < 0) {
            delta = uint256(-result) / 1e2;
            isPositive = false;
        } else {
            delta = uint256(result) / 1e2;
            isPositive = true;
        }
        return (delta, isPositive);
    }

    /// @notice // TODO: Add comment
    function _convertExistingBalanceToWstETHAndSupplyToAave() internal returns (uint256 suppliedCollateral) {
        IAavePM aavePM = IAavePM(address(this));
        address aavePoolAddress = aavePM.getContractAddress("aavePool");
        address wstETHAddress = aavePM.getTokenAddress("wstETH");

        if (aavePM.getContractBalance("ETH") > 0) _wrapETHToWETH();
        if (aavePM.getContractBalance("USDC") > 0) _swapTokens("USDC/ETH", "USDC", "ETH");
        if (aavePM.getContractBalance("WETH") > 0) _swapTokens("wstETH/ETH", "ETH", "wstETH");

        uint256 wstETHBalance = aavePM.getContractBalance("wstETH");
        if (wstETHBalance > 0) {
            // Get collateral before
            (uint256 initialCollateralBase,,,,,) = IPool(aavePoolAddress).getUserAccountData(address(this));

            _aaveSupply(aavePoolAddress, wstETHAddress, wstETHBalance);

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

    /// @notice Flash loan callback function.
    /// @dev This function is called by the Aave pool contract after the flash loan is executed.
    ///      It is used to repay the flash loan and execute the operation.
    ///      The function is called by the Aave pool contract and is not intended to be called directly.
    /// @param asset The address of the asset being flash loaned.
    /// @param amount The amount of the asset being flash loaned.
    /// @param premium The fee charged for the flash loan.
    /// @param initiator The address of the contract that initiated the flash loan.
    /// @return bool True if the operation was successful.
    function _executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata /* params */
    ) internal returns (bool) {
        IAavePM aavePM = IAavePM(address(this));
        address aavePoolAddress = aavePM.getContractAddress("aavePool");
        address wstETHAddress = aavePM.getTokenAddress("wstETH");

        // Only the Aave pool contract can call and execute this function.
        if (msg.sender != aavePoolAddress) revert IAavePM.AaveFunctions__FlashLoanMsgSenderUnauthorized();

        // Only allow the AavePM contract to initiate the flashloan and execute this function.
        if (initiator != address(this)) revert IAavePM.AaveFunctions__FlashLoanInitiatorUnauthorized();

        uint256 repaymentAmountTotalUSDC = amount + premium;

        // Use the flash loan USDC to repay the debt.
        _aaveRepayDebt(aavePoolAddress, aavePM.getTokenAddress("USDC"), amount);

        // Now the HF is higher, withdraw the corresponding amount of wstETH from collateral.
        // TODO: Use Uniswap price as that's where the swap will happen.
        uint256 wstETHPrice = IPriceOracle(aavePM.getContractAddress("aaveOracle")).getAssetPrice(wstETHAddress);

        // Calculate the amount of wstETH to withdraw.
        // TODO: Why 1e20 ?
        uint256 wstETHToWithdraw = (repaymentAmountTotalUSDC * 1e20) / wstETHPrice;

        // When calculating slippageAllowance, multiple by 10 to allow for 1 decimal place.
        uint256 slippageAllowance = 1000 + (100 * 10) / aavePM.getSlippageTolerance();
        uint256 wstETHToWithdrawSlippageAllowance = (wstETHToWithdraw * slippageAllowance) / 1000;

        // Withdraw the wstETH from Aave.
        _aaveWithdrawCollateral(aavePoolAddress, wstETHAddress, wstETHToWithdrawSlippageAllowance);

        // Convert the wstETH to USDC.
        _swapTokens("wstETH/ETH", "wstETH", "ETH");
        _swapTokens("USDC/ETH", "ETH", "USDC");
        TransferHelper.safeApprove(asset, aavePoolAddress, repaymentAmountTotalUSDC);
        return true;
    }

    function _calculateMaxBorrowUSDC(
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 currentLiquidationThreshold,
        uint16 healthFactorTarget
    ) internal pure returns (uint256 maxBorrowUSDC) {
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
                / ((healthFactorTarget * 1e2) - currentLiquidationThreshold)
        );
    }
}
