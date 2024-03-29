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

    mapping(string => address) s_contractAddresses;
    mapping(string => address) s_tokenAddresses;
    address uniswapV3WstETHETHPoolAddress;
    uint24 uniswapV3WstETHETHPoolFee;
    uint256 initialHealthFactorTarget;

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

    // Encoded reverts
    bytes encodedRevert_AccessControlUnauthorizedAccount_Owner;

    function setUp() external {
        DeployAavePM deployAavePM = new DeployAavePM();

        (aavePM, helperConfig) = deployAavePM.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        IAavePM.ContractAddress[] memory contractAddresses = config.contractAddresses;
        IAavePM.TokenAddress[] memory tokenAddresses = config.tokenAddresses;
        uniswapV3WstETHETHPoolAddress = config.uniswapV3WstETHETHPoolAddress;
        uniswapV3WstETHETHPoolFee = config.uniswapV3WstETHETHPoolFee;
        initialHealthFactorTarget = config.initialHealthFactorTarget;

        // Convert the contractAddresses array to a mapping
        for (uint256 i = 0; i < contractAddresses.length; i++) {
            s_contractAddresses[contractAddresses[i].identifier] = contractAddresses[i].contractAddress;
        }

        // Convert the tokenAddresses array to a mapping
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_tokenAddresses[tokenAddresses[i].identifier] = tokenAddresses[i].tokenAddress;
        }

        // Add the owner1 user as the new owner and manager
        aavePM.grantRole(aavePM.getRoleHash("OWNER_ROLE"), owner1);
        aavePM.grantRole(aavePM.getRoleHash("MANAGER_ROLE"), owner1);

        // Remove the test contract as a manager and then an owner
        // Order matters as you can't remove the manager role if you're not an owner
        aavePM.revokeRole(aavePM.getRoleHash("MANAGER_ROLE"), address(this));
        aavePM.revokeRole(aavePM.getRoleHash("OWNER_ROLE"), address(this));

        vm.deal(owner1, STARTING_BALANCE);
        vm.deal(manager1, STARTING_BALANCE);
        vm.deal(attacker1, STARTING_BALANCE);

        encodedRevert_AccessControlUnauthorizedAccount_Owner = abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector, attacker1, aavePM.getRoleHash("OWNER_ROLE")
        );
    }
}

contract AavePMConstructorTests is AavePMTestSetup {
    function test_Constructor() public {
        assertEq(aavePM.getCreator(), msg.sender);

        assert(aavePM.hasRole(aavePM.getRoleHash("OWNER_ROLE"), owner1));
        assert(aavePM.getRoleAdmin(aavePM.getRoleHash("OWNER_ROLE")) == aavePM.getRoleHash("OWNER_ROLE"));

        assert(aavePM.hasRole(aavePM.getRoleHash("MANAGER_ROLE"), owner1));
        assert(aavePM.getRoleAdmin(aavePM.getRoleHash("MANAGER_ROLE")) == aavePM.getRoleHash("OWNER_ROLE"));
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

        bytes memory encodedRevert_ERC1967InvalidImplementation =
            abi.encodeWithSelector(ERC1967Utils.ERC1967InvalidImplementation.selector, address(invalidUpgrade));

        // Check revert on upgrade
        vm.expectRevert(encodedRevert_ERC1967InvalidImplementation);
        vm.prank(owner1);
        aavePM.upgradeToAndCall(address(invalidUpgrade), "");
    }
}

// ================================================================
// │                         UPDATE TESTS                         │
// ================================================================
contract AavePMUpdateTests is AavePMTestSetup {
    function test_UpdateAave() public {
        address newAave = makeAddr("newAaveAddress");

        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        vm.prank(attacker1);
        aavePM.updateAave(newAave);

        vm.expectEmit();
        emit IAavePM.AaveUpdated(aavePM.getContractAddress("aave"), newAave);

        vm.prank(owner1);
        aavePM.updateAave(newAave);
        assertEq(aavePM.getContractAddress("aave"), newAave);
    }

    function test_UpdateUniswapV3Router() public {
        address newUniswapV3Router = makeAddr("newUniswapV3RouterAddress");

        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        vm.prank(attacker1);
        aavePM.updateUniswapV3Router(newUniswapV3Router);

        vm.expectEmit();
        emit IAavePM.UniswapV3RouterUpdated(aavePM.getContractAddress("uniswapV3Router"), newUniswapV3Router);

        vm.prank(owner1);
        aavePM.updateUniswapV3Router(newUniswapV3Router);
        assertEq(aavePM.getContractAddress("uniswapV3Router"), newUniswapV3Router);
    }

    function test_UpdateWETH9() public {
        address newWETH9 = makeAddr("newWETH9Address");

        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        vm.prank(attacker1);
        aavePM.updateWETH9(newWETH9);

        vm.expectEmit();
        emit IAavePM.WETH9Updated(aavePM.getTokenAddress("WETH9"), newWETH9);

        vm.prank(owner1);
        aavePM.updateWETH9(newWETH9);
        assertEq(aavePM.getTokenAddress("WETH9"), newWETH9);
    }

    function test_UpdateWstETH() public {
        address newWstETH = makeAddr("newWstETHAddress");

        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        vm.prank(attacker1);
        aavePM.updateWstETH(newWstETH);

        vm.expectEmit();
        emit IAavePM.WstETHUpdated(aavePM.getTokenAddress("wstETH"), newWstETH);

        vm.prank(owner1);
        aavePM.updateWstETH(newWstETH);
        assertEq(aavePM.getTokenAddress("wstETH"), newWstETH);
    }

    function test_UpdateUSDC() public {
        address newUSDC = makeAddr("newUSDCAddress");

        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        vm.prank(attacker1);
        aavePM.updateUSDC(newUSDC);

        vm.expectEmit();
        emit IAavePM.USDCUpdated(aavePM.getTokenAddress("USDC"), newUSDC);

        vm.prank(owner1);
        aavePM.updateUSDC(newUSDC);
        assertEq(aavePM.getTokenAddress("USDC"), newUSDC);
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
    uint256 balanceBefore;

    function rescueEth_SetUp() public {
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
        aavePM.grantRole(aavePM.getRoleHash("OWNER_ROLE"), address(invalidOwner));
        return invalidOwner;
    }

    function test_RescueAllETH() public {
        rescueEth_SetUp();

        // Check only owner1 can call rescueEth
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
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
    function test_SwapETHToWstETH() public {
        IERC20 token = IERC20(aavePM.getTokenAddress("wstETH"));

        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success, "Failed to send ETH to AavePM contract");

        // Call the swapETHToWstETH function
        vm.prank(owner1);
        uint256 amountOut = aavePM.swapETHToWstETH();

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
        assertEq(aavePM.getRoleHash("OWNER_ROLE"), keccak256("OWNER_ROLE"));
    }

    function test_GetManagerRole() public {
        assertEq(aavePM.getRoleHash("MANAGER_ROLE"), keccak256("MANAGER_ROLE"));
    }

    function test_GetAave() public {
        assertEq(aavePM.getContractAddress("aave"), s_contractAddresses["aave"]);
    }

    function test_GetUniswapV3Router() public {
        assertEq(aavePM.getContractAddress("uniswapV3Router"), s_contractAddresses["uniswapV3Router"]);
    }

    function test_GetWETH9() public {
        assertEq(aavePM.getTokenAddress("WETH9"), s_tokenAddresses["WETH9"]);
    }

    function test_GetWstETH() public {
        assertEq(aavePM.getTokenAddress("wstETH"), s_tokenAddresses["wstETH"]);
    }

    function test_GetUSDC() public {
        assertEq(aavePM.getTokenAddress("USDC"), s_tokenAddresses["USDC"]);
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
