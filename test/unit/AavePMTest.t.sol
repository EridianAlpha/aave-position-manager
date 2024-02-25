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
    uint256 constant INITIAL_HEALTH_FACTOR_TARGET = 2;
    uint256 constant INITIAL_HEALTH_FACTOR_MINIMUM = 2;

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
    event HealthFactorTargetUpdated(uint256 previousHealthFactorTarget, uint256 newHealthFactorTarget);

    function test_UpdateAave() public {
        address aaveTestAddress = makeAddr("AaveContractAddress");
        assertEq(aavePM.getAave(), address(0));

        vm.expectEmit();
        emit AaveUpdated(address(0), aaveTestAddress);

        vm.prank(owner1);
        aavePM.updateAave(aaveTestAddress);
        assertEq(aavePM.getAave(), aaveTestAddress);
    }

    function test_UpdateHealthFactorTarget() public {
        uint256 newHealthFactorTarget = 3;
        uint256 previousHealthFactorTarget = aavePM.getHealthFactorTarget();

        vm.expectEmit();
        emit AavePM.HealthFactorTargetUpdated(previousHealthFactorTarget, newHealthFactorTarget);

        vm.prank(owner1);
        aavePM.updateHealthFactorTarget(newHealthFactorTarget);
        assertEq(aavePM.getHealthFactorTarget(), newHealthFactorTarget);
    }

    function test_UpdateHealthFactorTargetUnchanged() public {
        uint256 previousHealthFactorTarget = aavePM.getHealthFactorTarget();

        vm.expectRevert(AavePM.AavePM__HealthFactorUnchanged.selector);
        vm.prank(owner1);
        aavePM.updateHealthFactorTarget(previousHealthFactorTarget);
    }

    function test_UpdateHealthFactorTargetBelowMinimum() public {
        uint256 newHealthFactorTarget = aavePM.getHealthFactorMinimum() - 1;

        vm.expectRevert(AavePM.AavePM__HealthFactorBelowMinimum.selector);
        vm.prank(owner1);
        aavePM.updateHealthFactorTarget(newHealthFactorTarget);
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

    function test_GetHealthFactorTarget() public {
        assertEq(aavePM.getHealthFactorTarget(), INITIAL_HEALTH_FACTOR_TARGET);
    }

    function test_getHealthFactorMinimum() public {
        assertEq(aavePM.getHealthFactorMinimum(), INITIAL_HEALTH_FACTOR_MINIMUM);
    }

    function test_GetRescueEthBalance() public {
        assertEq(aavePM.getRescueEthBalance(), address(aavePM).balance);
    }
}

// ================================================================
// │                       RESCUE ETH TESTS                       │
// ================================================================
contract AavePMRescueEthTest is AavePMTestSetup {
    event EthRescued(address indexed to, uint256 amount);

    bytes encodedRevert;
    uint256 balanceBefore;

    function rescueEth_SetUp() public {
        encodedRevert = abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector, attacker1, aavePM.OWNER_ROLE()
        );
        vm.prank(manager1);
        (bool callSuccess,) = address(aavePM).call{value: SEND_VALUE}("");
        require(callSuccess, "Failed to send ETH to AavePM contract");
        balanceBefore = address(aavePM).balance;
        require(balanceBefore > 0, "Balance before rescueEth is 0");
    }

    function grantOwnerRoleToInvalidOwnerContract() public returns (InvalidOwner) {
        // Deploy InvalidOwner contract
        InvalidOwner invalidOwner = new InvalidOwner(address(aavePM));

        // Transfer ownership to invalid owner1 contract
        aavePM.grantRole(aavePM.OWNER_ROLE(), address(invalidOwner));
        return invalidOwner;
    }

    function runRescueEthTest(bool rescueAll, uint256 amount) internal {
        rescueEth_SetUp();

        // Check only owner1 can call rescueEth
        vm.expectRevert(encodedRevert);
        vm.prank(attacker1);
        rescueAll ? aavePM.rescueEth(attacker1) : aavePM.rescueEth(attacker1, amount);

        // Check rescueAddress is an owner
        vm.expectRevert(AavePM.AavePM__RescueAddressNotAnOwner.selector);
        vm.prank(owner1);
        rescueAll ? aavePM.rescueEth(manager1) : aavePM.rescueEth(manager1, amount);

        // Rescue ETH
        vm.expectEmit();
        uint256 expectedBalance = rescueAll ? address(aavePM).balance : amount;
        emit EthRescued(owner1, expectedBalance);

        vm.prank(owner1);
        rescueAll ? aavePM.rescueEth(owner1) : aavePM.rescueEth(owner1, amount);

        uint256 expectedRemaining = rescueAll ? 0 : balanceBefore - amount;
        assertEq(address(aavePM).balance, expectedRemaining);
    }

    function test_RescueAllETH() public {
        runRescueEthTest(true, 0);
    }

    function test_RescueEth() public {
        runRescueEthTest(false, balanceBefore / 2);
    }

    function test_RescueEthCallFailureThrowsError() public {
        // This covers the edge case where the .call fails because the
        // receiving contract doesn't have a receive() or fallback() function.
        // Very unlikely on the rescue function as only the owner1 can call it,
        // but it is needed for the coverage test, and is a good check anyway.
        rescueEth_SetUp();
        vm.startPrank(owner1);
        InvalidOwner invalidOwner = grantOwnerRoleToInvalidOwnerContract();
        vm.stopPrank();

        vm.expectRevert(AavePM.AavePM__RescueEthFailed.selector);
        invalidOwner.aavePMRescueAllETH();

        vm.expectRevert(AavePM.AavePM__RescueEthFailed.selector);
        invalidOwner.aavePMRescueEth();
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
        vm.expectRevert(AavePM.AavePM__RescueEthFailed.selector);
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("123");
        require(!success);
    }
}
