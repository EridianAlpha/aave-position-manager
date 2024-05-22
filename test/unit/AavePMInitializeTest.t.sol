// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

// ================================================================
// │                        INITIALIZE TESTS                      │
// ================================================================
contract AavePMInitializeTests is AavePMTestSetup {
    function test_Initialize() public {
        assertEq(aavePM.getCreator(), msg.sender);

        assert(aavePM.hasRole(aavePM.getRoleHash("OWNER_ROLE"), owner1));
        assert(aavePM.getRoleAdmin(aavePM.getRoleHash("OWNER_ROLE")) == aavePM.getRoleHash("OWNER_ROLE"));

        assert(aavePM.hasRole(aavePM.getRoleHash("MANAGER_ROLE"), owner1));
        assert(aavePM.getRoleAdmin(aavePM.getRoleHash("MANAGER_ROLE")) == aavePM.getRoleHash("OWNER_ROLE"));
    }
}
