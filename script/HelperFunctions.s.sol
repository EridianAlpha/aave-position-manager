// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {Script, console} from "forge-std/Script.sol";

// Use this helper contract instead of the default library contract script as
// for some reason I couldn't work out, it deployed the library to the chain,
// even though it doesn't need to.
// Import into other scripts to use with: import {DevOpsTools} from "./HelperFunctions.s.sol";
contract DevOpsTools {
    Vm public constant devOpsVm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    string public constant RELATIVE_BROADCAST_PATH = "./broadcast";
    string public constant RELATIVE_SCRIPT_PATH = "./lib/foundry-devops/src/get_recent_deployment.sh";

    function get_most_recent_deployment(string memory contractName, uint256 chainId) public returns (address) {
        return get_most_recent_deployment(contractName, chainId, RELATIVE_BROADCAST_PATH, RELATIVE_SCRIPT_PATH);
    }

    function cleanStringPath(string memory stringToClean) public pure returns (string memory) {
        bytes memory inputBytes = bytes(stringToClean);
        uint256 start = 0;
        uint256 end = inputBytes.length;

        // Find the start of the non-whitespace characters
        for (uint256 i = 0; i < inputBytes.length; i++) {
            if (inputBytes[i] != " ") {
                start = i;
                break;
            }
        }

        // Find the end of the non-whitespace characters
        for (uint256 i = inputBytes.length; i > 0; i--) {
            if (inputBytes[i - 1] != " ") {
                end = i;
                break;
            }
        }

        // Remove the leading '.' if it exists
        if (inputBytes[start] == ".") {
            start += 1;
        }

        // Create a new bytes array for the trimmed string
        bytes memory trimmedBytes = new bytes(end - start);

        // Copy the trimmed characters to the new bytes array
        for (uint256 i = 0; i < trimmedBytes.length; i++) {
            trimmedBytes[i] = inputBytes[start + i];
        }

        return string(trimmedBytes);
    }

    function get_most_recent_deployment(
        string memory contractName,
        uint256 chainId,
        string memory relativeBroadcastPath,
        string memory relativeScriptPath
    ) public returns (address) {
        relativeBroadcastPath = cleanStringPath(relativeBroadcastPath);
        relativeScriptPath = cleanStringPath(relativeScriptPath);

        string[] memory pwd = new string[](1);
        pwd[0] = "pwd";
        string memory absolutePath = string(devOpsVm.ffi(pwd));

        string[] memory getRecentDeployment = new string[](5);
        getRecentDeployment[0] = "bash";
        getRecentDeployment[1] = string.concat(absolutePath, relativeScriptPath);
        getRecentDeployment[2] = contractName;
        getRecentDeployment[3] = devOpsVm.toString(chainId);
        getRecentDeployment[4] = string.concat(absolutePath, "/", relativeBroadcastPath);

        bytes memory retData = devOpsVm.ffi(getRecentDeployment);
        console.log("Return Data:");
        console.logBytes(retData);
        address returnedAddress = address(uint160(bytes20(retData)));
        if (returnedAddress != address(0)) {
            return returnedAddress;
        } else {
            revert("No contract deployed");
        }
    }
}

contract HelperFunctions is Script {
    function parseHexString(string memory _a) internal pure returns (address _parsedAddress) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint256 i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } // handle upper case letters
            else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } // handle upper case letters
            else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }

    function getInstanceAddress() internal view returns (address) {
        string memory contractAddressStr = vm.envString("CONTRACT_ADDRESS");
        require(bytes(contractAddressStr).length > 0, "Contract address not provided");

        address targetContractAddress = parseHexString(contractAddressStr);
        require(targetContractAddress != address(0), "Invalid contract address");

        return targetContractAddress;
    }

    function writeToFile(string memory filePath, string memory data) public {
        string[] memory args = new string[](3);
        args[0] = "bash";
        args[1] = "-c";
        args[2] = string.concat("echo '", data, "' > ", filePath);

        vm.ffi(args);
    }

    function addressToString(address _addr) public pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }
}
