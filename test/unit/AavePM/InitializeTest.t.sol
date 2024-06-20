// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";
import {Test, console} from "forge-std/Test.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {AavePM} from "src/AavePM.sol";

import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployAavePM} from "script/DeployAavePM.s.sol";
import {HelperFunctions} from "script/HelperFunctions.s.sol";

// ================================================================
// │                        INITIALIZE TESTS                      │
// ================================================================
contract AavePMInitializeTests is AavePMTestSetup {
    function test_Initialize() public {
        assertEq(aavePM.getCreator(), contractCreator);

        assert(aavePM.hasRole(keccak256("OWNER_ROLE"), owner1));
        assert(aavePM.getRoleAdmin(keccak256("OWNER_ROLE")) == keccak256("OWNER_ROLE"));

        assert(aavePM.hasRole(keccak256("MANAGER_ROLE"), owner1));
        assert(aavePM.getRoleAdmin(keccak256("MANAGER_ROLE")) == keccak256("OWNER_ROLE"));
    }
}
