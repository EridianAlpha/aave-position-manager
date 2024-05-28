// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

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

        (,,,,, uint256 endHealthFactor) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address(aavePM));
        uint256 endHealthFactorScaled = endHealthFactor / 1e16;

        require(endHealthFactorScaled <= (aavePM.getHealthFactorTarget() + REBALANCED_HEALTH_FACTOR_TOLERANCE));
        require(endHealthFactorScaled >= (aavePM.getHealthFactorTarget() - REBALANCED_HEALTH_FACTOR_TOLERANCE));
        vm.stopPrank();
    }

    function test_RebalanceHealthFactorDecrease() public {
        test_Rebalance();

        vm.startPrank(manager1);
        // Decrease the health factor target
        aavePM.updateHealthFactorTarget(HEALTH_FACTOR_TARGET_MINIMUM);

        aavePM.rebalance();

        (,,,,, uint256 endHealthFactor) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address(aavePM));
        uint256 endHealthFactorScaled = endHealthFactor / 1e16;

        require(endHealthFactorScaled <= (aavePM.getHealthFactorTarget() + REBALANCED_HEALTH_FACTOR_TOLERANCE));
        require(endHealthFactorScaled >= (aavePM.getHealthFactorTarget() - REBALANCED_HEALTH_FACTOR_TOLERANCE));
        vm.stopPrank();
    }

    // TODO: Add additional tests for the rebalance function for non-empty Aave accounts

    function test_RebalanceHealthFactorIncrease() public {
        test_Rebalance();

        vm.startPrank(manager1);
        // Increase the health factor target
        aavePM.updateHealthFactorTarget(aavePM.getHealthFactorTarget() + HEALTH_FACTOR_TARGET_CHANGE);
        aavePM.rebalance();

        (,,,,, uint256 endHealthFactor) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address(aavePM));
        uint256 endHealthFactorScaled = endHealthFactor / 1e16;

        // TODO: These ranges should be set as a global test variable
        require(endHealthFactorScaled <= (aavePM.getHealthFactorTarget() + REBALANCED_HEALTH_FACTOR_TOLERANCE));
        require(endHealthFactorScaled >= (aavePM.getHealthFactorTarget() - REBALANCED_HEALTH_FACTOR_TOLERANCE));
        vm.stopPrank();
    }
}
