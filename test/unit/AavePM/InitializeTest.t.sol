// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";

import {console} from "forge-std/Test.sol";

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

        // TODO: Update these tests to use eventBlockNumbers
        // string memory currentVersion = aavePM.getVersion();
        // string memory upgradeHistoryVersion = aavePM.getUpgradeHistory()[0].version;
        // assert(keccak256(abi.encodePacked(currentVersion)) == keccak256(abi.encodePacked(upgradeHistoryVersion)));
        // assert(aavePM.getUpgradeHistory()[0].upgradeTime == block.timestamp);
        // assert(aavePM.getUpgradeHistory()[0].upgradeInitiator == defaultFoundryCaller);
    }
}
