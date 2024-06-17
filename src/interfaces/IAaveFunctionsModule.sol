// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAavePM} from "./IAavePM.sol";

/// @notice // TODO: Add comment
interface IAaveFunctionsModule {
    function aaveSupply(address aavePoolAddress, address tokenAddress, uint256 tokenBalance) external;
    function aaveWithdrawCollateral(address aavePoolAddress, address tokenAddress, uint256 withdrawAmount) external;
    function aaveBorrow(address aavePoolAddress, address tokenAddress, uint256 borrowAmount) external;
    function aaveRepayDebt(address aavePoolAddress, address tokenAddress, uint256 repayAmount) external;
    function getCurrentPositionValues(IAavePM aavePM)
        external
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
        );
    function checkHealthFactorAboveMinimum()
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
    function getTotalCollateralDelta(
        uint256 totalCollateralBase,
        uint256 reinvestedDebtTotal,
        uint256 suppliedCollateralTotal
    ) external pure returns (uint256 delta, bool isPositive);
    function convertExistingBalanceToWstETHAndSupplyToAave() external returns (uint256 suppliedCollateral);
    function calculateMaxBorrowUSDC(
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 currentLiquidationThreshold,
        uint16 healthFactorTarget
    ) external pure returns (uint256 maxBorrowUSDC);
}
