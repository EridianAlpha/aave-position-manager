// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/Test.sol";
import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ================================================================
// │          WithdrawTokensFromContractBalanceTest TESTS         │
// ================================================================
contract WithdrawTokensFromContractBalanceTest is AavePMTestSetup {
    function withdrawToken_SetUp() public {
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // The first parameter: Whether to check the event signature.
        // The second parameter: Whether to check the indexed parameters (topics) of the event.
        // The third parameter: Whether to check the unindexed parameters (data) of the event.
        // The fourth parameter: Whether to check the event data's values.
        vm.expectEmit(true, true, true, false);
        emit IAavePM.AaveSuppliedFromContractBalance(0); // The data is a placeholder and not checked
        aavePM.aaveSupplyFromContractBalance();
        aavePM.aaveBorrowAndWithdrawUSDC(USDC_BORROW_AMOUNT, owner1);
        aavePM.reinvest();
        vm.stopPrank();

        vm.startPrank(owner1);
        IERC20(USDC).transfer(address(aavePM), USDC_BORROW_AMOUNT);
        vm.stopPrank();
    }

    function test_WithdrawTokenNonOwnerAddress() public {
        withdrawToken_SetUp();

        vm.startPrank(manager1);
        vm.expectRevert(AavePM__AddressNotAnOwner.selector);
        aavePM.withdrawTokensFromContractBalance("USDC", manager1);
        vm.stopPrank();
    }

    function test_WithdrawTokenNoTokensToWithdraw() public {
        withdrawToken_SetUp();

        vm.startPrank(manager1);
        vm.expectRevert(AavePM__NoTokensToWithdraw.selector);
        aavePM.withdrawTokensFromContractBalance("WETH", owner1);
        vm.stopPrank();
    }

    function test_WithdrawTokenInvalidToken() public {
        withdrawToken_SetUp();

        vm.startPrank(manager1);
        vm.expectRevert(AavePM__InvalidWithdrawalToken.selector);
        aavePM.withdrawTokensFromContractBalance("awstETH", owner1);
        vm.stopPrank();
    }

    function test_WithdrawToken() public {
        withdrawToken_SetUp();

        vm.startPrank(manager1);
        uint256 contractBalanceBefore = IERC20(USDC).balanceOf(address(aavePM));
        uint256 ownerBalanceBefore = IERC20(USDC).balanceOf(owner1);

        vm.expectEmit();
        emit IAavePM.TokensWithdrawnFromContractBalance("USDC", contractBalanceBefore);
        aavePM.withdrawTokensFromContractBalance("USDC", owner1);

        uint256 contractBalanceAfter = IERC20(USDC).balanceOf(address(aavePM));
        uint256 ownerBalanceAfter = IERC20(USDC).balanceOf(owner1);

        assertEq(ownerBalanceAfter - ownerBalanceBefore, contractBalanceBefore);
        assertEq(contractBalanceAfter, 0);
        vm.stopPrank();
    }
}
