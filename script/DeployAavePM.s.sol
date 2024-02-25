// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {AavePM} from "../src/AavePM.sol";
import "forge-std/console.sol";

contract DeployAavePM is Script {
    // Overload the run function to allow owner address to be optional
    // when running the deployment script, even though it is required
    // in the contract constructor.
    function run() public returns (AavePM) {
        return deployContract(msg.sender);
    }

    function run(address owner) public returns (AavePM) {
        return deployContract(owner);
    }

    function deployContract(address owner) public returns (AavePM) {
        uint256 initialHealthFactorTarget = 2;

        vm.startBroadcast();
        AavePM aavePM = new AavePM(owner, initialHealthFactorTarget);
        vm.stopBroadcast();
        return aavePM;
    }
}
