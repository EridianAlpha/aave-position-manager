// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/Test.sol";
import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
import {IWETH9} from "src/interfaces/IWETH9.sol";
import {ITokenSwapsModule} from "src/interfaces/ITokenSwapsModule.sol";
import {IAaveFunctionsModule} from "src/interfaces/IAaveFunctionsModule.sol";

// ================================================================
// │            aaveWithdrawWstETH TESTS            │
// ================================================================
contract AaveWithdrawWstETHTests is AavePMTestSetup {
    function testFail_AaveWithdrawWstETHEmptyContract() public {
        vm.startPrank(manager1);
        aavePM.aaveWithdrawWstETH(aavePM.getContractBalance("awstETH"), owner1);
        vm.stopPrank();
    }

    function test_AaveWithdrawWstETH() public {
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply to start the position.
        aavePM.aaveSupplyFromContractBalance();

        (uint256 totalCollateralBaseBefore,,,,,) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address(aavePM));

        // Withdraw immediately
        uint256 collateralDeltaBase = aavePM.aaveWithdrawWstETH(aavePM.getContractBalance("awstETH"), owner1);

        assertEq(collateralDeltaBase, totalCollateralBaseBefore);

        (uint256 totalCollateralBaseAfter,,,,,) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address(aavePM));

        assertEq(totalCollateralBaseAfter, 0);
        vm.stopPrank();
    }

    function test_Exposed_AaveWithdrawWstETHValueIncreaseLessThanDebt() public {
        // Set up a position and reinvest
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE);
        vm.stopPrank();

        reinvest();

        // Get the initial wstETH balance
        uint256 initialWstETHBalance = getContractBalance("awstETH");

        // "Increase" the collateral value by calling the internal function _aaveSupply to increase
        // the collateral value without incrementing the collateral counter
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE * 5);
        vm.stopPrank();

        aavePM.delegateCallHelper(
            "tokenSwapsModule", abi.encodeWithSelector(ITokenSwapsModule.wrapETHToWETH.selector, new bytes(0))
        );

        delegateCallHelper(
            "tokenSwapsModule",
            abi.encodeWithSelector(ITokenSwapsModule.swapTokens.selector, "wstETH/ETH", "ETH", "wstETH")
        );
        delegateCallHelper(
            "aaveFunctionsModule",
            abi.encodeWithSelector(
                IAaveFunctionsModule.aaveSupply.selector,
                getContractAddress("aavePool"),
                getTokenAddress("wstETH"),
                getContractBalance("wstETH")
            )
        );

        // Withdraw a collateral amount that is more than the collateral supplied but less than the reinvested debt
        aaveWithdrawWstETH(initialWstETHBalance, owner1);

        assertEq(getSuppliedCollateralTotal(), 0);
        assert(getReinvestedDebtTotal() > 0);
    }

    function test_Exposed_AaveWithdrawWstETHValueIncreaseMoreThanDebt() public {
        // Set up a position and reinvest
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE);
        vm.stopPrank();

        reinvest();

        // Get the initial wstETH balance
        uint256 initialWstETHBalance = getContractBalance("awstETH");

        // "Increase" the collateral value by calling the internal function _aaveSupply to increase
        // the collateral value without incrementing the collateral counter
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE * 5);
        vm.stopPrank();

        aavePM.delegateCallHelper(
            "tokenSwapsModule", abi.encodeWithSelector(ITokenSwapsModule.wrapETHToWETH.selector, new bytes(0))
        );

        delegateCallHelper(
            "tokenSwapsModule",
            abi.encodeWithSelector(ITokenSwapsModule.swapTokens.selector, "wstETH/ETH", "ETH", "wstETH")
        );
        delegateCallHelper(
            "aaveFunctionsModule",
            abi.encodeWithSelector(
                IAaveFunctionsModule.aaveSupply.selector,
                getContractAddress("aavePool"),
                getTokenAddress("wstETH"),
                getContractBalance("wstETH")
            )
        );

        // Withdraw a collateral amount that is more than the collateral supplied but less than the reinvested debt
        aaveWithdrawWstETH(initialWstETHBalance * 2, owner1);

        assertEq(getSuppliedCollateralTotal(), 0);
        assertEq(getReinvestedDebtTotal(), 0);
    }
}
