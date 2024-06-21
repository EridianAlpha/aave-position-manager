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
import {IWETH9} from "./interfaces/IWETH9.sol";
import {ITokenSwapsModule} from "./interfaces/ITokenSwapsModule.sol";
import {IAaveFunctionsModule} from "./interfaces/IAaveFunctionsModule.sol";

// ================================================================
// │                     FLASH LOAN CONTRACT                      │
// ================================================================

/// @title Flash Loan for the Aave Position Manager
/// @author EridianAlpha
/// @notice This contract contains the functions for AavePM to execute a flash loan to repay debt and withdraw collateral.
contract FlashLoan {
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
        aavePM.delegateCallHelper(
            "aaveFunctionsModule",
            abi.encodeWithSelector(
                IAaveFunctionsModule.aaveRepayDebt.selector, aavePoolAddress, aavePM.getTokenAddress("USDC"), amount
            )
        );

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
        aavePM.delegateCallHelper(
            "aaveFunctionsModule",
            abi.encodeWithSelector(
                IAaveFunctionsModule.aaveWithdrawCollateral.selector,
                aavePoolAddress,
                wstETHAddress,
                wstETHToWithdrawSlippageAllowance
            )
        );

        // Convert the wstETH to USDC.
        aavePM.delegateCallHelper(
            "tokenSwapsModule",
            abi.encodeWithSelector(ITokenSwapsModule.swapTokens.selector, "wstETH/ETH", "wstETH", "ETH")
        );
        aavePM.delegateCallHelper(
            "tokenSwapsModule", abi.encodeWithSelector(ITokenSwapsModule.swapTokens.selector, "USDC/ETH", "ETH", "USDC")
        );
        TransferHelper.safeApprove(asset, aavePoolAddress, repaymentAmountTotalUSDC);
        return true;
    }
}
