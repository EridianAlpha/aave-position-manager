// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AavePM} from "../src/AavePM.sol";
import {IAavePM} from "../src/interfaces/IAavePM.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployAavePM is Script {
    function run() public returns (AavePM, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        IAavePM.ContractAddress[] memory contractAddresses = config.contractAddresses;
        IAavePM.TokenAddress[] memory tokenAddresses = config.tokenAddresses;
        IAavePM.UniswapV3Pool[] memory uniswapV3Pools = config.uniswapV3Pools;
        uint16 initialHealthFactorTarget = config.initialHealthFactorTarget;

        vm.startBroadcast();
        // Deploy the implementation contract
        AavePM aavePMImplementation = new AavePM();

        // Encode the initializer function
        bytes memory initData = abi.encodeWithSelector(
            AavePM.initialize.selector,
            msg.sender,
            contractAddresses,
            tokenAddresses,
            uniswapV3Pools,
            initialHealthFactorTarget
        );

        // Deploy the proxy pointing to the implementation
        ERC1967Proxy proxy = new ERC1967Proxy(address(aavePMImplementation), initData);
        vm.stopBroadcast();
        return (AavePM(payable(address(proxy))), helperConfig);
    }
}
