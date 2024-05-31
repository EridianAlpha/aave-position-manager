// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/Test.sol";
import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {AavePM} from "src/AavePM.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ================================================================
// │                         REINVEST TESTS                      │
// ================================================================
contract ReinvestTests is AavePMTestSetup {
    function testFail_ReinvestEmptyContract() public {
        // There's no check for this, as it would only happen if the contract is empty.
        // It reverts on the borrow function.
        vm.prank(manager1);
        aavePM.reinvest();
    }

    function test_Reinvest() public {
        // Used as the setup for other reinvest tests.
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);
        aavePM.reinvest();
        checkEndHealthFactor(address(aavePM));
        vm.stopPrank();
    }

    function test_ReinvestNoChanges() public {
        // Setup contract using the standard reinvest test
        test_Reinvest();
        vm.startPrank(manager1);
        vm.expectRevert(IAavePM.AavePM__ReinvestNotRequired.selector);
        aavePM.reinvest();
        vm.stopPrank();
    }

    function test_ReinvestHealthFactorDecrease() public {
        // Setup contract using the standard rebalance test
        test_Reinvest();

        vm.startPrank(manager1);
        // Decrease the health factor target
        aavePM.updateHealthFactorTarget(HEALTH_FACTOR_TARGET_MINIMUM);

        aavePM.reinvest();
        checkEndHealthFactor(address(aavePM));
        vm.stopPrank();
    }

    function test_ReinvestHealthFactorIncrease() public {
        // Setup contract using the standard rebalance test
        test_Reinvest();

        vm.startPrank(manager1);
        // Increase the health factor target
        aavePM.updateHealthFactorTarget(aavePM.getHealthFactorTarget() + HEALTH_FACTOR_TARGET_CHANGE);

        vm.expectRevert(IAavePM.AavePM__ReinvestNotRequired.selector);
        aavePM.reinvest();
        vm.stopPrank();
    }

    function test_Exposed_ReinvestWithUSDC() public {
        // Send ETH from manager1 to the contract
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE);
        vm.stopPrank();

        reinvest();

        // Send ETH and convert it to USDC
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE);
        vm.stopPrank();

        _swapTokens("USDC/ETH", "ETH", "USDC");
        reinvest();
        checkEndHealthFactor(address(this));
    }

    function testFail_Exposed_ReinvestHFBelowMinimum() public {
        // Send ETH from manager1 to the contract
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE);
        vm.stopPrank();

        // As HEALTH_FACTOR_TARGET_MINIMUM is a constant, the best way to test this is to decrease the health factor target
        // directly to below the minimum value and confirm that the check at the end of the _reinvest() function fails.
        s_healthFactorTarget = HEALTH_FACTOR_TARGET_MINIMUM - 10;

        // As this is an internal call reverting, vm.expectRevert() does not work:
        // https://github.com/foundry-rs/foundry/issues/5806#issuecomment-1713846184
        // So instead the entire test is set to testFail, but this means that the specific
        // revert error message cannot be checked.
        reinvest();
    }
}
