// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

contract InterfaceTest is Test, Script {
    function test_AllFunctionsImplementedInInterface_AavePM() public {
        // Ignore list
        string memory accessControlFunctions = "DEFAULT_ADMIN_ROLE"; // Constants
        string memory uupsFunctions = "UPGRADE_INTERFACE_VERSION,proxiableUUID"; // Constants and function that can't be called through a proxy
        string memory ignoreList = string(abi.encodePacked(accessControlFunctions, ",", uupsFunctions));

        // Command as an array with arguments
        string[] memory command = new string[](4);
        command[0] = "./compare_methods.sh"; // Path to bash script
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
