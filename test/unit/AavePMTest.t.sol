// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

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
    address owner1 = makeAddr("owner1");
    address manager1 = makeAddr("manager1");
    address attacker1 = makeAddr("attacker1");

    function setUp() external {
        DeployAavePM deployAavePM = new DeployAavePM();
        aavePM = deployAavePM.run(owner1);
        vm.deal(owner1, STARTING_BALANCE);
        vm.deal(manager1, STARTING_BALANCE);
        vm.deal(attacker1, STARTING_BALANCE);
    }
}

contract AavePMConstructorTests is AavePMTestSetup {
    function test_Constructor() public {
        assertEq(aavePM.getCreator(), msg.sender);

        assert(aavePM.hasRole(aavePM.OWNER_ROLE(), owner1));
        assert(aavePM.getRoleAdmin(aavePM.OWNER_ROLE()) == aavePM.OWNER_ROLE());

        assert(aavePM.hasRole(aavePM.MANAGER_ROLE(), owner1));
        assert(aavePM.getRoleAdmin(aavePM.MANAGER_ROLE()) == aavePM.OWNER_ROLE());
    }
}

// ================================================================
// │                         UPDATE TESTS                         │
// ================================================================

contract AavePMUpdateTests is AavePMTestSetup {
    event AaveUpdated(address indexed previousAaveAddress, address indexed newAaveAddress);

    function test_UpdateAave() public {
        address aaveTestAddress = makeAddr("AaveContractAddress");
        assertEq(aavePM.getAave(), address(0));

        vm.expectEmit();
        emit AaveUpdated(address(0), aaveTestAddress);

        vm.prank(owner1);
        aavePM.updateAave(aaveTestAddress);
        assertEq(aavePM.getAave(), aaveTestAddress);
    }
}

// ================================================================
// │                         GETTER TESTS                         │
// ================================================================
contract AavePMGetterTests is AavePMTestSetup {
    function test_GetCreator() public {
        assertEq(aavePM.getCreator(), msg.sender);
    }

    function test_GetAave() public {
        assertEq(aavePM.getAave(), address(0));
    }

    function test_GetRescueETHBalance() public {
        assertEq(aavePM.getRescueETHBalance(), address(aavePM).balance);
    }
}

// ================================================================
// │                       RESCUE ETH TESTS                       │
// ================================================================
contract AavePMRescueEthTest is AavePMTestSetup {
    event RescueETH(address indexed to, uint256 amount);

    bytes encodedRevert;
    uint256 balanceBefore;

    function rescueETH_SetUp() public {
        encodedRevert = abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector, attacker1, aavePM.OWNER_ROLE()
        );
        vm.prank(manager1);
        (bool callSuccess,) = address(aavePM).call{value: SEND_VALUE}("");
        require(callSuccess, "Failed to send ETH to AavePM contract");
        balanceBefore = address(aavePM).balance;
        require(balanceBefore > 0, "Balance before rescueETH is 0");
    }

    function grantOwnerRoleToInvalidOwnerContract() public returns (InvalidOwner) {
        // Deploy InvalidOwner contract
        InvalidOwner invalidOwner = new InvalidOwner(address(aavePM));

        // Transfer ownership to invalid owner1 contract
        aavePM.grantRole(aavePM.OWNER_ROLE(), address(invalidOwner));
        return invalidOwner;
    }

    function runRescueETHTest(bool rescueAll, uint256 amount) internal {
        rescueETH_SetUp();

        // Check only owner1 can call rescueETH
        vm.expectRevert(encodedRevert);
        vm.prank(attacker1);
        rescueAll ? aavePM.rescueETH(attacker1) : aavePM.rescueETH(attacker1, amount);

        // Check rescueAddress is an owner
        vm.expectRevert(AavePM.AavePM__RescueAddressNotAnOwner.selector);
        vm.prank(owner1);
        rescueAll ? aavePM.rescueETH(manager1) : aavePM.rescueETH(manager1, amount);

        // Rescue ETH
        vm.expectEmit();
        uint256 expectedBalance = rescueAll ? address(aavePM).balance : amount;
        emit RescueETH(owner1, expectedBalance);

        vm.prank(owner1);
        rescueAll ? aavePM.rescueETH(owner1) : aavePM.rescueETH(owner1, amount);

        uint256 expectedRemaining = rescueAll ? 0 : balanceBefore - amount;
        assertEq(address(aavePM).balance, expectedRemaining);
    }

    function test_RescueAllETH() public {
        runRescueETHTest(true, 0);
    }

    function test_RescueETH() public {
        runRescueETHTest(false, balanceBefore / 2);
    }

    // function test_RescueAllETH() public {
    //     rescueETH_SetUp();

    //     // Check only owner1 can call rescueETH
    //     vm.expectRevert(encodedRevert);
    //     vm.prank(attacker1);
    //     aavePM.rescueETH(attacker1);

    //     // Check rescueAddress is an owner
    //     vm.expectRevert(AavePM.AavePM__RescueAddressNotAnOwner.selector);
    //     vm.prank(owner1);
    //     aavePM.rescueETH(manager1);

    //     // Rescue the all ETH
    //     vm.expectEmit();
    //     emit RescueETH(owner1, address(aavePM).balance);

    //     vm.prank(owner1);
    //     aavePM.rescueETH(owner1);
    //     assertEq(address(aavePM).balance, 0);
    // }

    // function test_RescueETH() public {
    //     rescueETH_SetUp();

    //     // Check only owner1 can call rescueETH
    //     vm.expectRevert(encodedRevert);
    //     vm.prank(attacker1);
    //     aavePM.rescueETH(attacker1, balanceBefore / 2);

    //     // Check rescueAddress is an owner
    //     vm.expectRevert(AavePM.AavePM__RescueAddressNotAnOwner.selector);
    //     vm.prank(owner1);
    //     aavePM.rescueETH(manager1, balanceBefore / 2);

    //     // Rescue the half the ETH
    //     vm.expectEmit();
    //     emit RescueETH(owner1, balanceBefore / 2);

    //     vm.prank(owner1);
    //     aavePM.rescueETH(owner1, balanceBefore / 2);
    //     assertEq(address(aavePM).balance, balanceBefore / 2);
    // }

    function test_RescueETHCallFailureThrowsError() public {
        // This covers the edge case where the .call fails because the
        // receiving contract doesn't have a receive() or fallback() function.
        // Very unlikely on the rescue function as only the owner1 can call it,
        // but it is needed for the coverage test, and is a good check anyway.
        rescueETH_SetUp();
        vm.startPrank(owner1);
        InvalidOwner invalidOwner = grantOwnerRoleToInvalidOwnerContract();
        vm.stopPrank();

        vm.expectRevert(AavePM.AavePM__RescueETHFailed.selector);
        invalidOwner.aavePMRescueAllETH();

        vm.expectRevert(AavePM.AavePM__RescueETHFailed.selector);
        invalidOwner.aavePMRescueETH();
    }
}

// ================================================================
// │                          MISC TESTS                          │
// ================================================================
contract AavePMMiscTests is AavePMTestSetup {
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
