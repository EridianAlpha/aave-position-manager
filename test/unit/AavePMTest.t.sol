// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AavePM} from "../../src/AavePM.sol";
import {IAavePM} from "../../src/interfaces/IAavePM.sol";

import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {InvalidOwner} from "../../src/testHelperContracts/InvalidOwner.sol";
import {InvalidUpgrade} from "../../src/testHelperContracts/InvalidUpgrade.sol";
import {AavePMUpgradeExample} from "../../src/testHelperContracts/AavePMUpgradeExample.sol";

import {DeployAavePM} from "../../script/DeployAavePM.s.sol";

// ================================================================
// │                 COMMON SETUP AND CONSTRUCTOR                 │
// ================================================================
contract AavePMTestSetup is Test {
    AavePM aavePM;
    HelperConfig helperConfig;

    address aave;
    address uniswapV3Router;
    address wstETH;
    address USDC;
    uint256 initialHealthFactorTarget;
    uint256 initialHealthFactorMinimum;

    string constant INITIAL_VERSION = "0.0.1";
    string constant UPGRADE_EXAMPLE_VERSION = "0.0.2";
    uint256 constant GAS_PRICE = 1;
    uint256 constant SEND_VALUE = 1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant INITIAL_HEALTH_FACTOR_MINIMUM = 2;

    // Create users
    address owner1 = makeAddr("owner1");
    address manager1 = makeAddr("manager1");
    address attacker1 = makeAddr("attacker1");

    function setUp() external {
        DeployAavePM deployAavePM = new DeployAavePM();

        (aavePM, helperConfig) = deployAavePM.run();
        (aave, uniswapV3Router, wstETH, USDC, initialHealthFactorTarget, initialHealthFactorMinimum) =
            helperConfig.activeNetworkConfig();

        aavePM.grantRole(aavePM.getOwnerRole(), owner1);
        aavePM.grantRole(aavePM.getManagerRole(), owner1);

        vm.deal(owner1, STARTING_BALANCE);
        vm.deal(manager1, STARTING_BALANCE);
        vm.deal(attacker1, STARTING_BALANCE);
    }
}

contract AavePMConstructorTests is AavePMTestSetup {
    function test_Constructor() public {
        assertEq(aavePM.getCreator(), msg.sender);

        assert(aavePM.hasRole(aavePM.getOwnerRole(), owner1));
        assert(aavePM.getRoleAdmin(aavePM.getOwnerRole()) == aavePM.getOwnerRole());

        assert(aavePM.hasRole(aavePM.getManagerRole(), owner1));
        assert(aavePM.getRoleAdmin(aavePM.getManagerRole()) == aavePM.getOwnerRole());
    }
}

// ================================================================
// │                        UPGRADE TESTS                         │
// ================================================================
contract AavePMUpgradeTests is AavePMTestSetup {
    function test_UpgradeV1ToV2() public {
        // Deploy new contract
        AavePMUpgradeExample aavePMUpgradeExample = new AavePMUpgradeExample();

        // Check version before upgrade
        assertEq(keccak256(abi.encodePacked(aavePM.getVersion())), keccak256(abi.encodePacked(INITIAL_VERSION)));

        // Upgrade
        vm.prank(owner1);
        aavePM.upgradeToAndCall(address(aavePMUpgradeExample), "");
        assertEq(keccak256(abi.encodePacked(aavePM.getVersion())), keccak256(abi.encodePacked(UPGRADE_EXAMPLE_VERSION)));
    }

    function test_DowngradeV2ToV1() public {
        // Deploy V1 and V2 implementation contract
        AavePM aavePMImplementationV1 = new AavePM();
        AavePMUpgradeExample aavePMUpgradeExample = new AavePMUpgradeExample();

        // Upgrade
        vm.prank(owner1);
        aavePM.upgradeToAndCall(address(aavePMUpgradeExample), "");

        // Check version before downgrade
        assertEq(keccak256(abi.encodePacked(aavePM.getVersion())), keccak256(abi.encodePacked(UPGRADE_EXAMPLE_VERSION)));

        // Downgrade
        vm.prank(owner1);
        aavePM.upgradeToAndCall(address(aavePMImplementationV1), "");
        assertEq(keccak256(abi.encodePacked(aavePM.getVersion())), keccak256(abi.encodePacked(INITIAL_VERSION)));
    }

    function test_InvalidUpgrade() public {
        // Deploy InvalidUpgrade contract
        InvalidUpgrade invalidUpgrade = new InvalidUpgrade();

        bytes memory encodedRevert =
            abi.encodeWithSelector(ERC1967Utils.ERC1967InvalidImplementation.selector, address(invalidUpgrade));

        // Check revert on upgrade
        vm.expectRevert(encodedRevert);
        vm.prank(owner1);
        aavePM.upgradeToAndCall(address(invalidUpgrade), "");
    }
}

// ================================================================
// │                         UPDATE TESTS                         │
// ================================================================
contract AavePMUpdateTests is AavePMTestSetup {
    function test_UpdateAave() public {
        address aaveTestAddress = makeAddr("AaveContractAddress");
        assertEq(aavePM.getAave(), address(0));

        vm.expectEmit();
        emit IAavePM.AaveUpdated(address(0), aaveTestAddress);

        vm.prank(owner1);
        aavePM.updateAave(aaveTestAddress);
        assertEq(aavePM.getAave(), aaveTestAddress);
    }

    function test_UpdateHealthFactorTarget() public {
        uint256 newHealthFactorTarget = 3;
        uint256 previousHealthFactorTarget = aavePM.getHealthFactorTarget();

        vm.expectEmit();
        emit IAavePM.HealthFactorTargetUpdated(previousHealthFactorTarget, newHealthFactorTarget);

        vm.prank(owner1);
        aavePM.updateHealthFactorTarget(newHealthFactorTarget);
        assertEq(aavePM.getHealthFactorTarget(), newHealthFactorTarget);
    }

    function test_UpdateHealthFactorTargetUnchanged() public {
        uint256 previousHealthFactorTarget = aavePM.getHealthFactorTarget();

        vm.expectRevert(IAavePM.AavePM__HealthFactorUnchanged.selector);
        vm.prank(owner1);
        aavePM.updateHealthFactorTarget(previousHealthFactorTarget);
    }

    function test_UpdateHealthFactorTargetBelowMinimum() public {
        uint256 newHealthFactorTarget = aavePM.getHealthFactorMinimum() - 1;

        vm.expectRevert(IAavePM.AavePM__HealthFactorBelowMinimum.selector);
        vm.prank(owner1);
        aavePM.updateHealthFactorTarget(newHealthFactorTarget);
    }
}

// ================================================================
// │                       RESCUE ETH TESTS                       │
// ================================================================
contract AavePMRescueEthTest is AavePMTestSetup {
    bytes encodedRevert;
    uint256 balanceBefore;

    function rescueEth_SetUp() public {
        encodedRevert = abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector, attacker1, aavePM.getOwnerRole()
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
        aavePM.grantRole(aavePM.getOwnerRole(), address(invalidOwner));
        return invalidOwner;
    }

    function test_RescueAllETH() public {
        rescueEth_SetUp();

        // Check only owner1 can call rescueEth
        vm.expectRevert(encodedRevert);
        vm.prank(attacker1);
        aavePM.rescueEth(attacker1);

        // Check rescueAddress is an owner
        vm.expectRevert(IAavePM.AavePM__RescueAddressNotAnOwner.selector);
        vm.prank(owner1);
        aavePM.rescueEth(manager1);

        // Rescue ETH
        vm.expectEmit();
        uint256 expectedBalance = address(aavePM).balance;
        emit IAavePM.EthRescued(owner1, expectedBalance);

        vm.prank(owner1);
        aavePM.rescueEth(owner1);

        uint256 expectedRemaining = 0;
        assertEq(address(aavePM).balance, expectedRemaining);
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

        vm.expectRevert(IAavePM.AavePM__RescueEthFailed.selector);
        invalidOwner.aavePMRescueAllETH();
    }
}

// ================================================================
// │                       TOKEN SWAP TESTS                       │
// ================================================================
contract AavePMTokenSwapTests is AavePMTestSetup {
    function test_ConvertETHToWstETH() public {
        IERC20 token = IERC20(aavePM.getWstETH());

        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success, "Failed to send ETH to AavePM contract");

        // Call the convertETHToWstETH function
        uint256 amountOut = aavePM.convertETHToWstETH();

        // Check the wstETH balance of the contract
        uint256 wstETHbalance = token.balanceOf(address(aavePM));

        assertEq(amountOut, wstETHbalance);
    }
}

// ================================================================
// │                         GETTER TESTS                         │
// ================================================================
contract AavePMGetterTests is AavePMTestSetup {
    function test_GetCreator() public {
        assertEq(aavePM.getCreator(), msg.sender);
    }

    function test_GetVersion() public {
        assertEq(keccak256(abi.encodePacked(aavePM.getVersion())), keccak256(abi.encodePacked(INITIAL_VERSION)));
    }

    function test_GetOwnerRole() public {
        assertEq(aavePM.getOwnerRole(), keccak256("OWNER_ROLE"));
    }

    function test_GetManagerRole() public {
        assertEq(aavePM.getManagerRole(), keccak256("MANAGER_ROLE"));
    }

    function test_GetAave() public {
        assertEq(aavePM.getAave(), aave);
    }

    function test_GetWstETH() public {
        assertEq(aavePM.getWstETH(), wstETH);
    }

    function test_GetUSDC() public {
        assertEq(aavePM.getUSDC(), USDC);
    }

    function test_GetHealthFactorTarget() public {
        assertEq(aavePM.getHealthFactorTarget(), initialHealthFactorTarget);
    }

    function test_getHealthFactorMinimum() public {
        assertEq(aavePM.getHealthFactorMinimum(), INITIAL_HEALTH_FACTOR_MINIMUM);
    }

    function test_GetRescueEthBalance() public {
        assertEq(aavePM.getRescueEthBalance(), address(aavePM).balance);
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
        vm.expectRevert(IAavePM.AavePM__RescueEthFailed.selector);
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("123");
        require(!success);
    }
}
