// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

// ================================================================
// │                        INITIALIZE TESTS                      │
// ================================================================
contract AavePMInitializeTests is AavePMTestSetup {
    function test_Initialize() public {
        assertEq(aavePM.getCreator(), msg.sender);

        assert(aavePM.hasRole(keccak256("OWNER_ROLE"), owner1));
        assert(aavePM.getRoleAdmin(keccak256("OWNER_ROLE")) == keccak256("OWNER_ROLE"));

        assert(aavePM.hasRole(keccak256("MANAGER_ROLE"), owner1));
        assert(aavePM.getRoleAdmin(keccak256("MANAGER_ROLE")) == keccak256("OWNER_ROLE"));
    }
}
