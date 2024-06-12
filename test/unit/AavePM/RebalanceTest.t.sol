// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/Test.sol";
import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {AavePM} from "src/AavePM.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
// ================================================================
// │                         REBALANCE TESTS                      │
// ================================================================

contract RebalanceTests is AavePMTestSetup {
    function test_RebalanceEmptyContract() public {
        // There's no check for this, as it would only happen if the contract is empty.
        vm.prank(manager1);
        vm.expectRevert(IAavePM.AavePM__RebalanceNotRequired.selector);
        aavePM.rebalance();
    }

    function test_RebalanceSetup() public {
        // Used as the setup for other rebalance tests.
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply to start the position
        aavePM.aaveSupplyFromContractBalance();

        uint16 initialHealthFactorTarget = aavePM.getHealthFactorTarget();

        // Decrease HF target to ensure rebalance is required
        aavePM.updateHealthFactorTarget(aavePM.getHealthFactorTarget() - HEALTH_FACTOR_TARGET_CHANGE);

        // Reinvest to get the HF to that new target
        aavePM.reinvest();
        checkEndHealthFactor(address(aavePM));

        // Increase HF target to ensure rebalance is required
        aavePM.updateHealthFactorTarget(initialHealthFactorTarget);
        vm.stopPrank();
    }

    function test_RebalanceNoChanges() public {
        // Setup contract using the standard rebalance test
        test_RebalanceSetup();
        vm.startPrank(manager1);
        aavePM.rebalance();
        checkEndHealthFactor(address(aavePM));
        vm.stopPrank();
    }

    function test_RebalanceHealthFactorDecrease() public {
        // Setup contract using the standard rebalance test
        test_RebalanceSetup();

        vm.startPrank(manager1);
        // Decrease the health factor target
        aavePM.updateHealthFactorTarget(HEALTH_FACTOR_TARGET_MINIMUM);

        vm.expectRevert(IAavePM.AavePM__RebalanceNotRequired.selector);
        aavePM.rebalance();
        vm.stopPrank();
    }

    function test_RebalanceHealthFactorIncrease() public {
        // Setup contract using the standard rebalance test
        test_RebalanceSetup();

        vm.startPrank(manager1);
        // Increase the health factor target
        aavePM.updateHealthFactorTarget(aavePM.getHealthFactorTarget() + HEALTH_FACTOR_TARGET_CHANGE);
        aavePM.rebalance();
        checkEndHealthFactor(address(aavePM));
        vm.stopPrank();
    }

    function test_RebalanceHealthFactorMax() public {
        // Setup contract using the standard rebalance test
        test_RebalanceSetup();

        (, uint256 totalDebtBaseBefore,,,,) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address((aavePM)));

        vm.startPrank(manager1);
        // Increase the health factor target
        aavePM.updateHealthFactorTarget(type(uint16).max);
        uint256 repaymentAmountUSDC = aavePM.rebalance();

        // Check debt after is 0
        (, uint256 totalDebtBaseAfter,,,,) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address((aavePM)));
        assertEq(totalDebtBaseAfter, 0);

        // Add $1 to avoid dust
        assertEq((totalDebtBaseBefore + 1e8) / 1e2, repaymentAmountUSDC);
        vm.stopPrank();
    }

    function test_RebalanceHealthFactorIncreaseAndWithdrawUSDC() public {
        // Send ETH from manager1 to the contract
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply to start the position
        aavePM.aaveSupplyFromContractBalance();

        // Borrow the maximum amount of USDC to get the Health Factor to the target
        aavePM.aaveBorrowAndWithdrawUSDC(aavePM.getMaxBorrowAndWithdrawUSDCAmount(), owner1);

        // Increase the health factor target
        aavePM.updateHealthFactorTarget(aavePM.getHealthFactorTarget() + HEALTH_FACTOR_TARGET_CHANGE);

        // Rebalance
        aavePM.rebalance();

        // Check the end health factor
        checkEndHealthFactor(address(aavePM));
        vm.stopPrank();
    }

    function testFail_Exposed_RebalanceHFBelowMinimum() public {
        // Send ETH from manager1 to the contract
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE);
        vm.stopPrank();

        // As HEALTH_FACTOR_TARGET_MINIMUM is a constant, the best way to test this is to decrease the health factor target
        // directly to below the minimum value and confirm that the check at the end of the _rebalance() function fails.
        s_healthFactorTarget = HEALTH_FACTOR_TARGET_MINIMUM - 10;

        // As this is an internal call reverting, vm.expectRevert() does not work:
        // https://github.com/foundry-rs/foundry/issues/5806#issuecomment-1713846184
        // So instead the entire test is set to testFail, but this means that the specific
        // revert error message cannot be checked.
        _rebalance();
    }
}
