// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/Test.sol";
import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {AavePM} from "src/AavePM.sol";

import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ================================================================
// │                         REBALANCE TESTS                      │
// ================================================================
contract RebalanceTests is AavePMTestSetup {
    function checkEndHealthFactor(address _address) public view {
        (,,,,, uint256 endHealthFactor) = IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(_address);
        uint256 endHealthFactorScaled = endHealthFactor / 1e16;

        require(endHealthFactorScaled <= (aavePM.getHealthFactorTarget() + REBALANCED_HEALTH_FACTOR_TOLERANCE));
        require(endHealthFactorScaled >= (aavePM.getHealthFactorTarget() - REBALANCED_HEALTH_FACTOR_TOLERANCE));
    }

    function testFail_RebalanceEmptyContract() public {
        // There's no check for this, as it would only happen if the contract is empty.
        // It reverts on the borrow function.
        vm.prank(manager1);
        aavePM.rebalance();
    }

    function test_Rebalance() public {
        // Standard rebalance test.
        // Used as the setup for other rebalance tests.
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);
        aavePM.rebalance();
        checkEndHealthFactor(address(aavePM));
        vm.stopPrank();
    }

    function test_RebalanceNoChanges() public {
        // Setup contract using the standard rebalance test
        test_Rebalance();
        vm.startPrank(manager1);
        aavePM.rebalance();
        checkEndHealthFactor(address(aavePM));
        vm.stopPrank();
    }

    function test_RebalanceHealthFactorDecrease() public {
        // Setup contract using the standard rebalance test
        test_Rebalance();

        vm.startPrank(manager1);
        // Decrease the health factor target
        aavePM.updateHealthFactorTarget(HEALTH_FACTOR_TARGET_MINIMUM);

        aavePM.rebalance();
        checkEndHealthFactor(address(aavePM));
        vm.stopPrank();
    }

    function test_RebalanceHealthFactorIncrease() public {
        // Setup contract using the standard rebalance test
        test_Rebalance();

        vm.startPrank(manager1);
        // Increase the health factor target
        aavePM.updateHealthFactorTarget(aavePM.getHealthFactorTarget() + HEALTH_FACTOR_TARGET_CHANGE);
        aavePM.rebalance();
        checkEndHealthFactor(address(aavePM));
        vm.stopPrank();
    }

    function test_Exposed_RebalanceWithUSDC() public {
        // Send ETH from manager1 to the contract
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE);
        vm.stopPrank();

        // Call internal functions as the current test contract (no prank)
        _rebalance();

        // Send ETH and convert it to USDC
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE);
        vm.stopPrank();

        _swapTokens("USDC/ETH", "ETH", "USDC");
        _rebalance();
        checkEndHealthFactor(address(this));
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
