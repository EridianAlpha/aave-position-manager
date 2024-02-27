// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AavePM} from "../src/AavePM.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployAavePM is Script {
    function run() public returns (AavePM) {
        address proxyAddress = deployContract(msg.sender);
        AavePM proxy = AavePM(payable(proxyAddress));
        return proxy;
    }

    function run(address owner) public returns (AavePM) {
        address proxyAddress = deployContract(owner);
        AavePM proxy = AavePM(payable(proxyAddress));
        return proxy;
    }

    function deployContract(address owner) internal returns (address) {
        uint256 initialHealthFactorTarget = 2;

        vm.startBroadcast();
        // Deploy the implementation contract
        AavePM aavePMImplementation = new AavePM();

        // Encode the initializer function
        bytes memory initData = abi.encodeWithSelector(AavePM.initialize.selector, owner, initialHealthFactorTarget);

        // Deploy the proxy pointing to the implementation
        ERC1967Proxy proxy = new ERC1967Proxy(address(aavePMImplementation), initData);
        vm.stopBroadcast();
        return address(proxy);
    }
}
