// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

contract InterfaceTest is Test, Script {
    function test_AllFunctionsImplementedInInterface_AavePM() public {
        string memory accessControlFunctions =
            "getRoleAdmin,hasRole,getRoleMember,getRoleMemberCount,grantRole,revokeRole,renounceRole,supportsInterface,DEFAULT_ADMIN_ROLE";

        // ADD ADDITIONAL FUNCTIONS TO IGNORE HERE
        // string memory otherFunctions = "TEST";
        // string memory ignoreList = string(abi.encodePacked(accessControlFunctions, ",", otherFunctions));

        string memory ignoreList = accessControlFunctions;

        // Command as an array with arguments
        string[] memory command = new string[](4);
        command[0] = "./compare_methods.sh";
        command[1] = "./src/Interfaces/IAavePM.sol"; // Path to the interface contract file
        command[2] = "AavePM"; // Contract name
        command[3] = ignoreList; // Ignore list as a single string

        // Execute the script
        bytes memory result = vm.ffi(command);
        assertEq(string(result), "---");
    }

    function runTests() public {
        test_AllFunctionsImplementedInInterface_AavePM();
    }
}
