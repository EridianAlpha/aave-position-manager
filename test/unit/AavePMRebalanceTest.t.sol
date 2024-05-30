// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/Test.sol";
import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

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

    function test_Rebalance() public {
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);
        aavePM.rebalance();
        checkEndHealthFactor(address(aavePM));
        vm.stopPrank();
    }

    function test_RebalanceHealthFactorDecrease() public {
        test_Rebalance();

        vm.startPrank(manager1);
        // Decrease the health factor target
        aavePM.updateHealthFactorTarget(HEALTH_FACTOR_TARGET_MINIMUM);

        aavePM.rebalance();
        checkEndHealthFactor(address(aavePM));
        vm.stopPrank();
    }

    function test_RebalanceHealthFactorIncrease() public {
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
}
