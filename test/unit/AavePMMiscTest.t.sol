// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";

// ================================================================
// │                          MISC TESTS                          │
// ================================================================
contract AavePMMiscTests is AavePMTestSetup {
    function test_CoverageForReceiveFunction() public {
        vm.prank(manager1);
        sendEth(address(aavePM), SEND_VALUE);
        assertEq(address(aavePM).balance, SEND_VALUE);
    }

    function test_CoverageForFallbackFunction() public {
        vm.prank(manager1);
        vm.expectRevert(IAavePM.AavePM__FunctionDoesNotExist.selector);
        sendEth(address(aavePM), SEND_VALUE, "123");
    }
}
