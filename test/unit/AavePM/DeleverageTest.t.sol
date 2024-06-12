// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/Test.sol";
import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {AavePM} from "src/AavePM.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// ================================================================
// │                        DELEVERAGE TESTS                      │
// ================================================================
contract DeleverageTests is AavePMTestSetup {
    function test_DeleverageEmptyContract() public {
        vm.prank(manager1);
        vm.expectRevert(IAavePM.AavePM__RebalanceNotRequired.selector);
        aavePM.deleverage();
    }

    function test_DeleverageSetup() public {
        // Used as the setup for other deleverage tests.
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply to start the position.
        aavePM.aaveSupplyFromContractBalance();

        // Reinvest to create reinvested debt.
        aavePM.reinvest();
        vm.stopPrank();
    }

    function test_Deleverage() public {
        test_DeleverageSetup();

        vm.startPrank(manager1);

        // Get healthFactorTarget before deleverage.
        uint16 healthFactorTargetBefore = aavePM.getHealthFactorTarget();

        aavePM.deleverage();
        // Check position debt is zero
        (, uint256 totalDebtBaseAfter,,,,) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address((aavePM)));
        assertEq(totalDebtBaseAfter, 0);

        // Get healthFactorTarget after deleverage.
        uint16 healthFactorTargetAfter = aavePM.getHealthFactorTarget();

        assertEq(healthFactorTargetBefore, healthFactorTargetAfter);

        vm.stopPrank();
    }

    function test_DeleverageMaxHealthFactor() public {
        test_DeleverageSetup();

        vm.startPrank(manager1);

        // Set healthFactorTarget to max value.
        aavePM.updateHealthFactorTarget(type(uint16).max);

        aavePM.deleverage();
        // Check position debt is zero
        (, uint256 totalDebtBaseAfter,,,,) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address((aavePM)));
        assertEq(totalDebtBaseAfter, 0);

        // Get healthFactorTarget after deleverage.
        uint16 healthFactorTargetAfter = aavePM.getHealthFactorTarget();

        assertEq(type(uint16).max, healthFactorTargetAfter);

        vm.stopPrank();
    }
}
