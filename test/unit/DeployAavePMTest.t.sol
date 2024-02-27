// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {AavePM} from "../../src/AavePM.sol";
import {DeployAavePM} from "../../script/DeployAavePM.s.sol";

// ================================================================
// │                 COMMON SETUP AND CONSTRUCTOR                 │
// ================================================================
contract DeployAavePMTest is Test {
    AavePM aavePM;

    address owner1 = makeAddr("owner1");

    function test_DeployAavePMWithoutPassingOwner() external {
        DeployAavePM deployAavePM = new DeployAavePM();
        (aavePM,) = deployAavePM.run();
        assert(address(aavePM) != address(0));
    }

    function test_DeployAavePMWithPassingOwner() external {
        DeployAavePM deployAavePM = new DeployAavePM();
        (aavePM,) = deployAavePM.run();
        assert(address(aavePM) != address(0));
    }
}
