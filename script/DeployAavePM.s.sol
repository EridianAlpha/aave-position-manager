// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AavePM} from "src/AavePM.sol";
import {IAavePM} from "src/interfaces/IAavePM.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

// Import Modules
import {RebalanceModule} from "src/modules/RebalanceModule.sol";
import {ReinvestModule} from "src/modules/ReinvestModule.sol";
import {TokenSwapsModule} from "src/modules/TokenSwapsModule.sol";
import {AaveFunctionsModule} from "src/modules/AaveFunctionsModule.sol";
import {BorrowAndWithdrawUSDCModule} from "src/modules/BorrowAndWithdrawUSDCModule.sol";

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

        // Deploy the module contracts
        IAavePM.ContractAddress[] memory newAddresses = new IAavePM.ContractAddress[](5);
        newAddresses[0] = IAavePM.ContractAddress("tokenSwapsModule", address(new TokenSwapsModule()));
        newAddresses[1] = IAavePM.ContractAddress("aaveFunctionsModule", address(new AaveFunctionsModule()));
        newAddresses[2] =
            IAavePM.ContractAddress("borrowAndWithdrawUSDCModule", address(new BorrowAndWithdrawUSDCModule()));
        newAddresses[3] = IAavePM.ContractAddress("rebalanceModule", address(new RebalanceModule()));
        newAddresses[4] = IAavePM.ContractAddress("reinvestModule", address(new ReinvestModule()));

        // Add the new module contract addresses to the contractAddresses array
        contractAddresses = addContractAddresses(contractAddresses, newAddresses);

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

    function addContractAddresses(
        IAavePM.ContractAddress[] memory originalArray,
        IAavePM.ContractAddress[] memory newElements
    ) internal pure returns (IAavePM.ContractAddress[] memory) {
        uint256 originalLength = originalArray.length;
        uint256 newElementsLength = newElements.length;
        uint256 newLength = originalLength + newElementsLength;

        // Create a new memory array with the new length
        IAavePM.ContractAddress[] memory newArray = new IAavePM.ContractAddress[](newLength);

        // Copy all elements from the original array to the new array
        for (uint256 i = 0; i < originalLength; i++) {
            newArray[i] = originalArray[i];
        }

        // Add the new elements to the new array
        for (uint256 j = 0; j < newElementsLength; j++) {
            newArray[originalLength + j] = newElements[j];
        }

        return newArray;
    }
}
