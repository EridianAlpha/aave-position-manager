// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";
import {console} from "forge-std/Test.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// ================================================================
// │                      EVIL MANAGER TESTS                     │
// ================================================================

// If a manager address is compromised these tests show the impact.
contract AavePMEvilManagerTests is AavePMTestSetup {
    function evilManagerSetup() public {
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);
        aavePM.aaveSupplyFromContractBalance();
        aavePM.reinvest();
        vm.stopPrank();
    }

    function testFail_EvilManagerLoopDrain() public {
        evilManagerSetup();
        vm.startPrank(manager1);
        for (uint256 i = 0; i <= aavePM.getManagerDailyInvocationLimit() + 1; i++) {
            aavePM.deleverage();
            aavePM.reinvest();
        }
        vm.stopPrank();
    }

    function test_EvilManagerLoopDrainThenAllowNextDay() public {
        evilManagerSetup();
        vm.startPrank(manager1);
        for (uint256 i = 1; i < aavePM.getManagerDailyInvocationLimit(); i++) {
            aavePM.updateHealthFactorTarget(aavePM.getHealthFactorTarget() + uint16(i));
        }
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1 hours);
        vm.startPrank(manager1);
        aavePM.deleverage();
        aavePM.reinvest();
        vm.stopPrank();
    }
}
