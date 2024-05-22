// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

// ================================================================
// │                         REBALANCE TESTS                      │
// ================================================================
contract RebalanceTests is AavePMTestSetup {
    function test_Rebalance() public {
        vm.startPrank(manager1);
        // Send some ETH to the contract
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success, "Failed to send ETH to AavePM contract");

        aavePM.rebalance();

        (,,,,, uint256 endHealthFactor) = aavePM.getAaveAccountData();
        uint256 endHealthFactorScaled = endHealthFactor / AAVE_HEALTH_FACTOR_DIVISOR;

        require(endHealthFactorScaled <= (aavePM.getHealthFactorTarget() + 1));
        require(endHealthFactorScaled >= (aavePM.getHealthFactorTarget() - 1));
        vm.stopPrank();
    }

    function test_RebalanceHealthFactorDecrease() public {
        test_Rebalance();

        // Update the health factor target
        vm.prank(owner1);
        aavePM.updateHealthFactorTarget(DECREASED_HEALTH_FACTOR_TARGET);

        vm.startPrank(manager1);
        aavePM.rebalance();

        (,,,,, uint256 endHealthFactor) = aavePM.getAaveAccountData();
        uint256 endHealthFactorScaled = endHealthFactor / AAVE_HEALTH_FACTOR_DIVISOR;

        require(endHealthFactorScaled <= (aavePM.getHealthFactorTarget() + 1));
        require(endHealthFactorScaled >= (aavePM.getHealthFactorTarget() - 1));
        vm.stopPrank();
    }

    // TODO: Add additional tests for the rebalance function for non-empty Aave accounts

    function test_RebalanceHealthFactorIncrease() public {
        test_Rebalance();

        // Update the health factor target
        vm.prank(owner1);
        aavePM.updateHealthFactorTarget(INCREASED_HEALTH_FACTOR_TARGET);

        vm.startPrank(manager1);
        aavePM.rebalance();

        (,,,,, uint256 endHealthFactor) = aavePM.getAaveAccountData();
        uint256 endHealthFactorScaled = endHealthFactor / AAVE_HEALTH_FACTOR_DIVISOR;

        // TODO: These ranges might be too tight
        require(endHealthFactorScaled <= (aavePM.getHealthFactorTarget() + 1));
        require(endHealthFactorScaled >= (aavePM.getHealthFactorTarget() - 1));
        vm.stopPrank();
    }
}
