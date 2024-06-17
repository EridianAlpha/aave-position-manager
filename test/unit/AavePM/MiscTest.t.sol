// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";
import {console} from "forge-std/Test.sol";

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

    function test_DelegateCallHelperRevert() public {
        vm.startPrank(manager1);
        vm.expectRevert(IAavePM.AavePM__DelegateCallFailed.selector);
        aavePM.delegateCallHelper(
            "aaveFunctionsModule", abi.encodeWithSelector(IAavePM.AavePM__FunctionDoesNotExist.selector, new bytes(0))
        );
        vm.stopPrank();
    }
}
