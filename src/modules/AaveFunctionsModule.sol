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
import {IAaveFunctionsModule} from "src/interfaces/IAaveFunctionsModule.sol";

// ================================================================
// │                  AAVE FUNCTIONS MODULE CONTRACT              │
// ================================================================

/// @title Aave Functions Module for the Aave Position Manager
/// @author EridianAlpha
/// @notice This contract contains the functions for AavePM to interact with the Aave protocol.
contract AaveFunctionsModule is IAaveFunctionsModule {
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
        if (address(this) != aavePMProxyAddress) revert AaveFunctionsModule__InvalidAavePMProxyAddress();
        _;
    }

    // ================================================================
    // │                       MODULE FUNCTIONS                       │
    // ================================================================

    /// @notice Deposit all wstETH into Aave.
    /// @dev This function is used to deposit all wstETH into Aave.
    /// @param aavePoolAddress The address of the Aave pool contract.
    /// @param tokenAddress The address of the token to deposit.
    /// @param tokenBalance The contract balance of the token to deposit.
    function aaveSupply(address aavePoolAddress, address tokenAddress, uint256 tokenBalance) public onlyAavePM {
        // Takes all tokens in the contract and deposits it into Aave
        TransferHelper.safeApprove(tokenAddress, aavePoolAddress, tokenBalance);
        IPool(aavePoolAddress).deposit(tokenAddress, tokenBalance, address(this), 0);
    }

    /// @notice Withdraw wstETH from Aave.
    /// @dev This function is used to withdraw wstETH from Aave.
    /// @param aavePoolAddress The address of the Aave pool contract.
    /// @param tokenAddress The address of the token to withdraw.
    /// @param withdrawAmount The amount of the token to withdraw.
    function aaveWithdrawCollateral(address aavePoolAddress, address tokenAddress, uint256 withdrawAmount)
        public
        onlyAavePM
    {
        IPool(aavePoolAddress).withdraw(tokenAddress, withdrawAmount, address(this));
    }

    /// @notice Borrow USDC from Aave.
    /// @dev This function is used to borrow USDC from Aave.
    /// @param aavePoolAddress The address of the Aave pool contract.
    /// @param tokenAddress The address of the token to borrow.
    /// @param borrowAmount The amount of USDC to borrow. 8 decimal places to the dollar. e.g. 100000000 = $1.00.
    function aaveBorrow(address aavePoolAddress, address tokenAddress, uint256 borrowAmount) public onlyAavePM {
        IPool(aavePoolAddress).borrow(tokenAddress, borrowAmount, 2, 0, address(this));
    }

    /// @notice Repay USDC debt to Aave.
    /// @dev This function is used to repay USDC debt to Aave.
    /// @param aavePoolAddress The address of the Aave pool contract.
    /// @param tokenAddress The address of the token to repay.
    /// @param repayAmount The amount of USDC to repay. 8 decimal places to the dollar. e.g. 100000000 = $1.00.
    function aaveRepayDebt(address aavePoolAddress, address tokenAddress, uint256 repayAmount) public onlyAavePM {
        TransferHelper.safeApprove(tokenAddress, aavePoolAddress, repayAmount);
        IPool(aavePoolAddress).repay(tokenAddress, repayAmount, 2, address(this));
    }

    /// @notice Getter function to get the current position values.
    /// @dev This function is used to avoid code duplication in the Reinvest and Rebalance contracts.
    /// @param aavePM The Aave Position Manager contract.
    /// @return initialCollateralBase The initial collateral in USD base unit with 8 decimals to the dollar.
    /// @return totalDebtBase The total debt in USD base unit with 8 decimals to the dollar.
    /// @return currentLiquidationThreshold The current liquidation threshold.
    /// @return initialHealthFactorScaled The initial health factor scaled to 2 decimal places.
    /// @return healthFactorTarget The health factor target.
    /// @return aavePoolAddress The address of the Aave pool contract.
    /// @return wstETHAddress The address of the wstETH token.
    /// @return usdcAddress The address of the USDC token.
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

    /// @notice Check if the health factor is above the minimum.
    /// @dev This function is used to check if the health factor is above the minimum.
    /// @return totalCollateralBase The total collateral in USD base unit with 8 decimals to the dollar.
    /// @return totalDebtBase The total debt in USD base unit with 8 decimals to the dollar.
    /// @return availableBorrowsBase The available borrows in USD base unit with 8 decimals to the dollar.
    /// @return currentLiquidationThreshold The current liquidation threshold.
    /// @return ltv The loan to value ratio.
    /// @return healthFactor The health factor.
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

    /// @notice Getter function to get the total collateral delta.
    /// @dev This function is used to calculate the total collateral delta.
    /// @param totalCollateralBase The total collateral in USD base unit with 8 decimals to the dollar.
    /// @param reinvestedDebtTotal The reinvested debt total in USD base unit with 8 decimals to the dollar.
    /// @param suppliedCollateralTotal The supplied collateral total in USD base unit with 8 decimals to the dollar.
    /// @return delta The total collateral delta.
    /// @return isPositive A boolean to indicate if the delta is positive.
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

    /// @notice Convert existing balance to wstETH and supply to Aave.
    /// @dev This function is used to convert the existing balance to wstETH and supply to Aave.
    /// @return suppliedCollateral The amount of wstETH supplied to Aave.
    function convertExistingBalanceToWstETHAndSupplyToAave() public onlyAavePM returns (uint256 suppliedCollateral) {
        IAavePM aavePM = IAavePM(address(this));
        address aavePoolAddress = aavePM.getContractAddress("aavePool");
        address wstETHAddress = aavePM.getTokenAddress("wstETH");

        // TODO: Work out why the code branch coverage says a branch is missing when the delegateCallHelper function
        //       is called in the first if statement, but is fine when called in the else statement.
        if (aavePM.getContractBalance("ETH") == 0) {
            // No-op: intentionally left blank to ensure code branch coverage.
        } else {
            aavePM.delegateCallHelper(
                "tokenSwapsModule", abi.encodeWithSelector(ITokenSwapsModule.wrapETHToWETH.selector, new bytes(0))
            );
        }
        if (aavePM.getContractBalance("USDC") == 0) {
            // No-op: intentionally left blank to ensure code branch coverage.
        } else {
            aavePM.delegateCallHelper(
                "tokenSwapsModule",
                abi.encodeWithSelector(ITokenSwapsModule.swapTokens.selector, "USDC/ETH", "USDC", "ETH")
            );
        }
        if (aavePM.getContractBalance("WETH") == 0) {
            // No-op: intentionally left blank to ensure code branch coverage.
        } else {
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

    /// @notice Calculate the minimum amount of tokens received from a Uniswap V3 swap.
    /// @dev This function is used to calculate the minimum amount of tokens received from a Uniswap V3 swap.
    /// @param totalCollateralBase The total collateral in USD base unit with 8 decimals to the dollar.
    /// @param totalDebtBase The total debt in USD base unit with 8 decimals to the dollar.
    /// @param currentLiquidationThreshold The current liquidation threshold.
    /// @param healthFactorTarget The health factor target.
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
