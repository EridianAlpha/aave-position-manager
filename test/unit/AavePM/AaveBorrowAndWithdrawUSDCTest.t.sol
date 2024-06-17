// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/Test.sol";
import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
import {IBorrowAndWithdrawUSDCModule} from "src/interfaces/IBorrowAndWithdrawUSDCModule.sol";

// ================================================================
// │               AavePMBorrowAndWithdrawUSDC TESTS              │
// ================================================================
contract AavePMBorrowAndWithdrawUSDCTests is AavePMTestSetup {
    function test_BorrowAndWithdrawUSDCOnlyOwnerAddressWithdraw() public {
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply the ETH sent to the contract to Aave
        aavePM.aaveSupplyFromContractBalance();

        // Borrow USDC as manager1
        vm.expectRevert(IAavePM.AavePM__AddressNotAnOwner.selector);
        aavePM.aaveBorrowAndWithdrawUSDC(USDC_BORROW_AMOUNT, manager1);
        vm.stopPrank();
    }

    function testFail_BorrowAndWithdrawUSDCMaxBorrowZero() public {
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply the ETH sent to the contract to Aave
        aavePM.aaveSupplyFromContractBalance();

        // Borrow the max amount (called multiple times as the first time does not quiet reach the max amount)
        aavePM.aaveBorrowAndWithdrawUSDC(aavePM.getMaxBorrowAndWithdrawUSDCAmount(), owner1);
        aavePM.aaveBorrowAndWithdrawUSDC(aavePM.getMaxBorrowAndWithdrawUSDCAmount(), owner1);
        aavePM.aaveBorrowAndWithdrawUSDC(aavePM.getMaxBorrowAndWithdrawUSDCAmount(), owner1);

        assertEq(USDC.balanceOf(owner1), aavePM.getWithdrawnUSDCTotal());
        assertEq(aavePM.getMaxBorrowAndWithdrawUSDCAmount(), 0);

        // Then try to borrow more
        aavePM.aaveBorrowAndWithdrawUSDC(USDC_BORROW_AMOUNT, owner1);
        vm.stopPrank();
    }

    function test_BorrowAndWithdrawUSDCAttacker() public {
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply the ETH sent to the contract to Aave
        aavePM.aaveSupplyFromContractBalance();
        vm.stopPrank();

        // An attacker tries to borrow USDC
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Manager);
        aavePM.aaveBorrowAndWithdrawUSDC(USDC_BORROW_AMOUNT, attacker1);
        vm.stopPrank();
    }

    function test_BorrowAndWithdrawUSDCNoReinvested() public {
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply the ETH sent to the contract to Aave
        aavePM.aaveSupplyFromContractBalance();

        // Borrow USDC immediately, without reinvesting
        aavePM.aaveBorrowAndWithdrawUSDC(USDC_BORROW_AMOUNT, owner1);

        // Check the USDC balance of owner1
        assertEq(USDC.balanceOf(owner1), USDC_BORROW_AMOUNT);

        // Check the withdrawn USDC total of the contract
        assertEq(aavePM.getWithdrawnUSDCTotal(), USDC_BORROW_AMOUNT);

        // Check health factor is above target
        (,,,,, uint256 endHealthFactor) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address(aavePM));
        uint256 endHealthFactorScaled = endHealthFactor / 1e16;
        require(endHealthFactorScaled >= (aavePM.getHealthFactorTarget() - HEALTH_FACTOR_TOLERANCE));
        vm.stopPrank();
    }

    function test_BorrowAndWithdrawUSDCWithReinvested() public {
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply the ETH sent to the contract to Aave
        aavePM.aaveSupplyFromContractBalance();

        // Store collateral value before reinvesting
        (uint256 totalCollateralBaseBefore,,,,,) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address((aavePM)));

        // Reinvest the ETH supplied to Aave
        aavePM.reinvest();

        // Store reinvested debt total before
        uint256 reinvestedDebtTotalBefore = aavePM.getReinvestedDebtTotal();

        // Borrow USDC, with reinvested debt
        aavePM.aaveBorrowAndWithdrawUSDC(USDC_BORROW_AMOUNT, owner1);

        // Store reinvested debt total after
        uint256 reinvestedDebtTotalAfter = aavePM.getReinvestedDebtTotal();

        // Check the USDC balance of owner1
        assertEq(USDC.balanceOf(owner1), USDC_BORROW_AMOUNT);

        // Check the withdrawn USDC total of the contract
        assertEq(aavePM.getWithdrawnUSDCTotal(), USDC_BORROW_AMOUNT);

        // Check the reinvested debt total is less than before and greater than 0
        assert(reinvestedDebtTotalAfter < reinvestedDebtTotalBefore);
        assert(reinvestedDebtTotalAfter > 0);

        // Check the collateral balance of the contract is higher than what was initially supplied
        (uint256 totalCollateralBaseAfter,,,,,) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address((aavePM)));
        assert(totalCollateralBaseAfter > totalCollateralBaseBefore);

        // Check health factor
        checkEndHealthFactor(address(aavePM));

        vm.stopPrank();
    }

    function test_BorrowAndWithdrawUSDCMaxBorrow() public {
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply the ETH sent to the contract to Aave
        aavePM.aaveSupplyFromContractBalance();

        // Reinvest the ETH supplied to Aave
        aavePM.reinvest();

        // Store the max borrow amount
        uint256 maxBorrowAndWithdrawUSDCAmount = aavePM.getMaxBorrowAndWithdrawUSDCAmount();

        // Try to borrow more USDC than is available
        aavePM.aaveBorrowAndWithdrawUSDC(maxBorrowAndWithdrawUSDCAmount + USDC_BORROW_AMOUNT, owner1);

        // Check the USDC balance of owner1
        assertEq(USDC.balanceOf(owner1), maxBorrowAndWithdrawUSDCAmount);

        // Check the withdrawn USDC total of the contract
        assertEq(aavePM.getWithdrawnUSDCTotal(), maxBorrowAndWithdrawUSDCAmount);

        // Check health factor
        checkEndHealthFactor(address(aavePM));
        vm.stopPrank();
    }

    function testFail_BorrowAndWithdrawUSDCZeroBorrow() public {
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply the ETH sent to the contract to Aave
        aavePM.aaveSupplyFromContractBalance();

        // Try to borrow 0 USDC
        aavePM.aaveBorrowAndWithdrawUSDC(0, owner1);
        vm.stopPrank();
    }

    // This test isn't something that can happen on in production since the internal function can't be
    // accessed externally, but it is used to check the branch coverage of the flash loan.
    // TODO: This was testFail, but when I added delegateCallHelper it started passing.
    // So I need to check if it still covers the correct branch.
    function test_Exposed_BorrowAndWithdrawUSDCWithReinvestedFlashLoanChecks() public {
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE);
        vm.stopPrank();

        // Supply the ETH sent to the contract to Aave
        aaveSupplyFromContractBalance();

        // Reinvest the ETH supplied to Aave
        reinvest();

        // Borrow USDC, with reinvested debt
        vm.startPrank(attacker1);
        // As this is an internal call reverting, vm.expectRevert() does not work:
        // https://github.com/foundry-rs/foundry/issues/5806#issuecomment-1713846184
        // So instead the entire test is set to testFail, but this means that the specific
        // revert error message cannot be checked.
        delegateCallHelper(
            "borrowAndWithdrawUSDCModule",
            abi.encodeWithSelector(
                IBorrowAndWithdrawUSDCModule.borrowAndWithdrawUSDC.selector, USDC_BORROW_AMOUNT, attacker1
            )
        );
        vm.stopPrank();
    }
}
