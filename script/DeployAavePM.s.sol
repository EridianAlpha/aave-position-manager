// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AavePM} from "src/AavePM.sol";
import {IAavePM} from "src/interfaces/IAavePM.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

// Import Modules
import {TokenSwapsModule} from "src/modules/TokenSwapsModule.sol";
import {AaveFunctionsModule} from "src/modules/AaveFunctionsModule.sol";

contract DeployAavePM is Script {
    function run() public returns (AavePM, HelperConfig, IAavePM.ContractAddress[] memory) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        IAavePM.ContractAddress[] memory contractAddresses = config.contractAddresses;
        IAavePM.TokenAddress[] memory tokenAddresses = config.tokenAddresses;
        IAavePM.UniswapV3Pool[] memory uniswapV3Pools = config.uniswapV3Pools;
        uint16 initialHealthFactorTarget = config.initialHealthFactorTarget;
        uint16 initialSlippageTolerance = config.initialSlippageTolerance;
        uint16 initialManagerDailyInvocationLimit = config.initialManagerDailyInvocationLimit;

        vm.startBroadcast();
        // Deploy the implementation contract
        AavePM aavePMImplementation = new AavePM();

        // Deploy the module contracts and add them to the contractAddresses array
        TokenSwapsModule tokenSwapsModule = new TokenSwapsModule();
        contractAddresses = addContractAddress(
            contractAddresses, IAavePM.ContractAddress("tokenSwapsModule", address(tokenSwapsModule))
        );
        AaveFunctionsModule aaveFunctionsModule = new AaveFunctionsModule();
        contractAddresses = addContractAddress(
            contractAddresses, IAavePM.ContractAddress("aaveFunctionsModule", address(aaveFunctionsModule))
        );

        // Encode the initializer function
        bytes memory initData = abi.encodeWithSelector(
            AavePM.initialize.selector,
            msg.sender,
            contractAddresses,
            tokenAddresses,
            uniswapV3Pools,
            initialHealthFactorTarget,
            initialSlippageTolerance,
            initialManagerDailyInvocationLimit
        );

        // Deploy the proxy pointing to the implementation
        ERC1967Proxy proxy = new ERC1967Proxy(address(aavePMImplementation), initData);
        vm.stopBroadcast();
        return (AavePM(payable(address(proxy))), helperConfig, contractAddresses);
    }

    function addContractAddress(
        IAavePM.ContractAddress[] memory originalArray,
        IAavePM.ContractAddress memory newElement
    ) internal pure returns (IAavePM.ContractAddress[] memory) {
        uint256 originalLength = originalArray.length;
        uint256 newLength = originalLength + 1;

        // Create a new memory array with the new length
        IAavePM.ContractAddress[] memory newArray = new IAavePM.ContractAddress[](newLength);

        // Copy all elements from the original array to the new array
        for (uint256 i = 0; i < originalLength; i++) {
            newArray[i] = originalArray[i];
        }

        // Add the new element to the new array
        newArray[originalLength] = newElement;

        return newArray;
    }
}
