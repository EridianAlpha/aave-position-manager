// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// ================================================================
// │                          ACCESS TESTS                        │
// ================================================================
contract AavePMAccessTests is AavePMTestSetup {
    function test_RenounceRole() public {
        vm.startPrank(manager1);

        // Renounce the MANAGER_ROLE for manager1
        aavePM.renounceRole(keccak256("MANAGER_ROLE"), manager1);

        // Check that manager1 no longer has the MANAGER_ROLE
        require(!aavePM.hasRole(keccak256("MANAGER_ROLE"), manager1));

        vm.stopPrank();
    }

    function test_GetRoleMember() public view {
        // Check that the owner is the first member of the OWNER_ROLE
        require(aavePM.getRoleMember(keccak256("OWNER_ROLE"), 0) == owner1);
    }

    function test_GetRoleMemberCount() public view {
        // Check that there is only one member of the OWNER_ROLE
        require(aavePM.getRoleMemberCount(keccak256("OWNER_ROLE")) == 1);
    }

    function test_SupportsInterface() public view {
        // Check that the contract supports the IAccessControl interface
        require(aavePM.supportsInterface(type(IAccessControl).interfaceId));
    }
}
