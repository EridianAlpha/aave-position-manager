// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";

// ================================================================
// │                          MISC TESTS                          │
// ================================================================
contract AavePMMiscTests is AavePMTestSetup {
    function test_CoverageForReceiveFunction() public {
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success);
        assertEq(address(aavePM).balance, SEND_VALUE);
    }

    function test_CoverageForFallbackFunction() public {
        vm.expectRevert(IAavePM.AavePM__RescueEthFailed.selector);
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("123");
        require(!success);
    }
}
