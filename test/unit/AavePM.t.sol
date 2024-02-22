// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AavePM} from "../../src/AavePM.sol";
import {DeployAavePM} from "../../script/DeployAavePM.s.sol";

// ================================================================
// │                 COMMON SETUP AND CONSTRUCTOR                 │
// ================================================================
contract AavePMTestSetup is Test {
    AavePM aavePM;
    uint256 constant GAS_PRICE = 1;
    uint256 constant SEND_VALUE = 1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;

    // Create users
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address attacker = makeAddr("attacker");

    function setUp() external {
        DeployAavePM deployAavePM = new DeployAavePM();
        aavePM = deployAavePM.run(owner);
        vm.deal(owner, STARTING_BALANCE);
        vm.deal(user1, STARTING_BALANCE);
        vm.deal(attacker, STARTING_BALANCE);
    }
}

contract AavePMConstructorTest is AavePMTestSetup {
    function test_Constructor() public {
        console.log("aavePM.getCreator(): ", aavePM.getCreator());
        console.log("msg.sender", msg.sender);
        console.log("owner", owner);
        console.log("aavePM.owner()", aavePM.owner());
        assertEq(aavePM.getCreator(), msg.sender);
    }
}

// ================================================================
// │                        DEPOSIT TESTS                         │
// ================================================================
