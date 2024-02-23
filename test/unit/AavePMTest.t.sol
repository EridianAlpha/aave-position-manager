// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {AavePM} from "../../src/AavePM.sol";
import {InvalidOwner} from "../../src/testHelperContracts/InvalidOwner.sol";

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
        assertEq(aavePM.getCreator(), msg.sender);
    }
}

// ================================================================
// │                        DEPOSIT TESTS                         │
// ================================================================

// ================================================================
// │                         GETTER TESTS                         │
// ================================================================
contract AavePMGetterTest is AavePMTestSetup {
    function test_GetCreator() public {
        assertEq(aavePM.getCreator(), msg.sender);
    }

    function test_GetRescueETHBalance() public {
        assertEq(aavePM.getRescueETHBalance(), address(aavePM).balance);
    }
}

// ================================================================
// │                       RESCUE ETH TESTS                       │
// ================================================================
contract AavePMRescueEthTest is AavePMTestSetup {
    uint256 balanceBefore;
    bytes encodedRevert = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1);

    function rescueETH_SetUp() public {
        vm.prank(user1);
        (bool callSuccess,) = address(aavePM).call{value: SEND_VALUE}("");
        assert(callSuccess);
        balanceBefore = address(aavePM).balance;
        assert(balanceBefore > 0);
    }

    function transferOwnershipToInvalidOwnerContract() public returns (InvalidOwner) {
        // Deploy invalid owner contract
        InvalidOwner invalidOwner = new InvalidOwner(address(aavePM));

        // Transfer ownership to invalid owner contract
        vm.prank(owner);
        aavePM.transferOwnership(address(invalidOwner));

        return invalidOwner;
    }

    function test_RescueAllETH() public {
        rescueETH_SetUp();

        // Check only owner can call rescueETH
        vm.expectRevert(encodedRevert);
        vm.prank(user1);
        aavePM.rescueETH();

        // Rescue the all ETH
        vm.prank(owner);
        aavePM.rescueETH();
        assertEq(address(aavePM).balance, 0);
    }

    function test_RescueETH() public {
        rescueETH_SetUp();

        // Check only owner can call rescueETH
        vm.expectRevert(encodedRevert);
        vm.prank(user1);
        aavePM.rescueETH(balanceBefore / 2);

        // Rescue the half the ETH
        vm.prank(owner);
        aavePM.rescueETH(balanceBefore / 2);
        assertEq(address(aavePM).balance, balanceBefore / 2);
    }

    function test_RescueETHCallFailureThrowsError() public {
        // This covers the edge case where the .call fails because the
        // receiving contract doesn't have a receive() or fallback() function.
        // Very unlikely on the rescue function as only the owner can call it,
        // but it is needed for the coverage test, and is a good check anyway.

        rescueETH_SetUp();
        InvalidOwner invalidOwner = transferOwnershipToInvalidOwnerContract();

        vm.expectRevert(AavePM.AavePM__RescueETHFailed.selector);
        invalidOwner.aavePMRescueAllETH();

        vm.expectRevert(AavePM.AavePM__RescueETHFailed.selector);
        invalidOwner.aavePMRescueETH();
    }
}

// ================================================================
// │                          MISC TESTS                          │
// ================================================================
contract AavePMMiscTest is AavePMTestSetup {
    function test_CoverageForReceiveFunction() public {
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success);
        assertEq(address(aavePM).balance, SEND_VALUE);
    }

    function test_CoverageForFallbackFunction() public {
        vm.expectRevert(AavePM.AavePM__RescueETHFailed.selector);
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("123");
        require(!success);
    }
}
