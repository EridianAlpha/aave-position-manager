// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/Test.sol";
import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ================================================================
// │             AaveRepayUSDCFromContractBalance TESTS           │
// ================================================================
contract AaveRepayUSDCFromContractBalanceTests is AavePMTestSetup {
    function test_RepayEmptyContract() public {
        vm.prank(manager1);
        vm.expectRevert(IAavePM.AavePM__NoDebtToRepay.selector);
        aavePM.aaveRepayUSDCFromContractBalance();
    }

    function aaveRepaySetup(uint256 testRepayAmount) public {
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply to start the position.
        aavePM.aaveSupplyFromContractBalance();

        // Withdraw to create debt and get some USDC.
        aavePM.aaveBorrowAndWithdrawUSDC(USDC_BORROW_AMOUNT, owner1);
        vm.stopPrank();

        // Send an amount of withdrawn USDC back to the contract from owner1
        vm.startPrank(owner1);
        USDC.transfer(address(aavePM), testRepayAmount);
        vm.stopPrank();

        assertEq(USDC.balanceOf(address(aavePM)), testRepayAmount);
    }

    function test_AaveRepayAll() public {
        aaveRepaySetup(USDC_BORROW_AMOUNT);

        vm.startPrank(manager1);
        // Confirm that the AavePM contract has some debt that needs repaying
        (, uint256 totalDebtBaseBefore,,,,) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address(aavePM));
        require(totalDebtBaseBefore > 0, "totalDebtBaseBefore should be greater than 0");

        // Confirm the withdrawnUSDCTotal equals the USDC_BORROW_AMOUNT
        assertEq(aavePM.getWithdrawnUSDCTotal(), USDC_BORROW_AMOUNT);

        // Repay the USDC debt from the contract balance
        vm.expectEmit(true, true, true, false);
        emit IAavePM.AaveRepayedUSDCFromContractBalance(0); // The data is a placeholder and not checked
        aavePM.aaveRepayUSDCFromContractBalance();

        // Check that the debt has been repaid
        (, uint256 totalDebtAfter,,,,) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address(aavePM));

        require(totalDebtAfter == 0, "totalDebtAfter should be 0");
        vm.stopPrank();
    }

    function test_AaveRepayHalf() public {
        aaveRepaySetup(USDC_BORROW_AMOUNT / 2);

        vm.startPrank(manager1);
        // Confirm that the AavePM contract has some debt that needs repaying
        (, uint256 totalDebtBaseBefore,,,,) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address(aavePM));
        require(totalDebtBaseBefore > 0, "totalDebtBaseBefore should be greater than 0");

        // Confirm the withdrawnUSDCTotal equals the USDC_BORROW_AMOUNT
        assertEq(aavePM.getWithdrawnUSDCTotal(), USDC_BORROW_AMOUNT);

        // Repay the USDC debt from the contract balance
        aavePM.aaveRepayUSDCFromContractBalance();

        // Check that the debt has been repaid
        assertEq(aavePM.getWithdrawnUSDCTotal(), USDC_BORROW_AMOUNT / 2);
        vm.stopPrank();
    }

    function test_AaveReinvestAndRepayHalf() public {
        // Give owner1 the full amount of USDC
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply to start the position.
        aavePM.aaveSupplyFromContractBalance();

        // Withdraw to create debt and get some USDC.
        aavePM.aaveBorrowAndWithdrawUSDC(USDC_BORROW_AMOUNT, owner1);
        vm.stopPrank();

        // Close the position
        vm.startPrank(manager1);
        aavePM.aaveClosePosition(owner1);
        vm.stopPrank();

        // Setup the position again and reinvest the USDC
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);
        aavePM.aaveSupplyFromContractBalance();
        aavePM.reinvest();

        // Then borrow and withdraw USDC again
        aavePM.aaveBorrowAndWithdrawUSDC(USDC_BORROW_AMOUNT / 2, owner1);
        vm.stopPrank();

        // Send all borrowed USDC back to the contract from owner1
        vm.startPrank(owner1);
        USDC.transfer(address(aavePM), USDC.balanceOf(owner1));
        vm.stopPrank();

        vm.startPrank(manager1);
        // Confirm the withdrawnUSDCTotal equals the USDC_BORROW_AMOUNT
        assertEq(aavePM.getWithdrawnUSDCTotal(), USDC_BORROW_AMOUNT / 2);

        // Repay the USDC debt from the contract balance
        aavePM.aaveRepayUSDCFromContractBalance();

        // Check that the debt has been repaid
        assertEq(aavePM.getWithdrawnUSDCTotal(), 0);
        vm.stopPrank();
    }

    function test_AaveReinvestAndRepayAll() public {
        // Give owner1 the full amount of USDC
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply to start the position.
        aavePM.aaveSupplyFromContractBalance();

        // Withdraw as much USDC as possible.
        aavePM.aaveBorrowAndWithdrawUSDC(type(uint256).max, owner1);
        vm.stopPrank();

        // Close the position
        vm.startPrank(manager1);
        vm.expectEmit();
        emit IAavePM.AaveClosedPosition(owner1);
        aavePM.aaveClosePosition(owner1);
        vm.stopPrank();

        // Setup the position again (with 5x less ETH than before) and reinvest the USDC
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE / 5);
        aavePM.aaveSupplyFromContractBalance();
        aavePM.reinvest();

        // Send all borrowed USDC back to the contract from owner1
        vm.startPrank(owner1);
        USDC.transfer(address(aavePM), USDC.balanceOf(owner1));
        vm.stopPrank();

        vm.startPrank(manager1);
        // Repay the USDC debt from the contract balance
        aavePM.aaveRepayUSDCFromContractBalance();

        // Check that the debt has been repaid
        assertEq(aavePM.getWithdrawnUSDCTotal(), 0);
        assertEq(aavePM.getReinvestedDebtTotal(), 0);
        vm.stopPrank();
    }
}
