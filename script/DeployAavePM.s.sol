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

        address aave = config.aave;
        address uniswapV3Router = config.uniswapV3Router;
        address uniswapV3WstETHETHPoolAddress = config.uniswapV3WstETHETHPoolAddress;
        uint24 uniswapV3WstETHETHPoolFee = config.uniswapV3WstETHETHPoolFee;
        IAavePM.TokenAddress[] memory tokenAddresses = config.tokenAddresses;
        uint256 initialHealthFactorTarget = config.initialHealthFactorTarget;

        vm.startBroadcast();
        // Deploy the implementation contract
        AavePM aavePMImplementation = new AavePM();

        // Encode the initializer function
        bytes memory initData = abi.encodeWithSelector(
            AavePM.initialize.selector,
            msg.sender,
            aave,
            uniswapV3Router,
            uniswapV3WstETHETHPoolAddress,
            uniswapV3WstETHETHPoolFee,
            tokenAddresses,
            initialHealthFactorTarget
        );

        // Deploy the proxy pointing to the implementation
        ERC1967Proxy proxy = new ERC1967Proxy(address(aavePMImplementation), initData);
        vm.stopBroadcast();
        return (AavePM(payable(address(proxy))), helperConfig);
    }
}
