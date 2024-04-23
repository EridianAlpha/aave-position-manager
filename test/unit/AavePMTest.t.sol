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
import {InvalidOwner} from "../testHelperContracts/InvalidOwner.sol";
import {InvalidUpgrade} from "../testHelperContracts/InvalidUpgrade.sol";
import {AavePMUpgradeExample} from "../testHelperContracts/AavePMUpgradeExample.sol";

import {DeployAavePM} from "../../script/DeployAavePM.s.sol";

// ================================================================
// │                 COMMON SETUP AND CONSTRUCTOR                 │
// ================================================================
contract AavePMTestSetup is Test {
    // Added to remove this whole testing file from coverage report.
    function test() public {}

    AavePM aavePM;
    HelperConfig helperConfig;

    mapping(string => address) s_contractAddresses;
    mapping(string => address) s_tokenAddresses;
    mapping(string => IAavePM.UniswapV3Pool) private s_uniswapV3Pools;
    uint16 initialHealthFactorTarget;

    string constant INITIAL_VERSION = "0.0.1";
    string constant UPGRADE_EXAMPLE_VERSION = "0.0.2";
    uint256 constant GAS_PRICE = 1;
    uint256 constant SEND_VALUE = 1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant USDC_BORROW_AMOUNT = 100;
    uint16 constant INITIAL_HEALTH_FACTOR_TARGET_MINIMUM = 200;
    uint16 constant UPDATED_HEALTH_FACTOR_TARGET_MINIMUM = 250;
    uint24 constant UPDATED_UNISWAPV3_POOL_FEE = 200;

    // Create users
    address owner1 = makeAddr("owner1");
    address manager1 = makeAddr("manager1");
    address attacker1 = makeAddr("attacker1");

    // Encoded reverts
    bytes encodedRevert_AccessControlUnauthorizedAccount_Owner;

    IERC20 WETH;
    IERC20 wstETH;
    IERC20 USDC;
    IERC20 awstETH;

    function setUp() external {
        DeployAavePM deployAavePM = new DeployAavePM();

        (aavePM, helperConfig) = deployAavePM.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        IAavePM.ContractAddress[] memory contractAddresses = config.contractAddresses;
        IAavePM.TokenAddress[] memory tokenAddresses = config.tokenAddresses;
        IAavePM.UniswapV3Pool[] memory uniswapV3Pools = config.uniswapV3Pools;
        initialHealthFactorTarget = config.initialHealthFactorTarget;

        // Convert the contractAddresses array to a mapping
        for (uint256 i = 0; i < contractAddresses.length; i++) {
            s_contractAddresses[contractAddresses[i].identifier] = contractAddresses[i].contractAddress;
        }

        // Convert the tokenAddresses array to a mapping
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_tokenAddresses[tokenAddresses[i].identifier] = tokenAddresses[i].tokenAddress;
        }

        // Convert the uniswapV3Pools array to a mapping.
        for (uint256 i = 0; i < uniswapV3Pools.length; i++) {
            s_uniswapV3Pools[uniswapV3Pools[i].identifier] = IAavePM.UniswapV3Pool(
                uniswapV3Pools[i].identifier, uniswapV3Pools[i].poolAddress, uniswapV3Pools[i].fee
            );
        }

        // Add the owner1 user as the new owner and manager
        aavePM.grantRole(aavePM.getRoleHash("OWNER_ROLE"), owner1);
        aavePM.grantRole(aavePM.getRoleHash("MANAGER_ROLE"), owner1);

        // Add the manager1 user as a manager
        aavePM.grantRole(aavePM.getRoleHash("MANAGER_ROLE"), manager1);

        // Remove the test contract as a manager and then an owner
        // Order matters as you can't remove the manager role if you're not an owner
        aavePM.revokeRole(aavePM.getRoleHash("MANAGER_ROLE"), address(this));
        aavePM.revokeRole(aavePM.getRoleHash("OWNER_ROLE"), address(this));

        vm.deal(owner1, STARTING_BALANCE);
        vm.deal(manager1, STARTING_BALANCE);
        vm.deal(attacker1, STARTING_BALANCE);

        WETH = IERC20(aavePM.getTokenAddress("WETH"));
        wstETH = IERC20(aavePM.getTokenAddress("wstETH"));
        USDC = IERC20(aavePM.getTokenAddress("USDC"));
        awstETH = IERC20(aavePM.getTokenAddress("awstETH"));

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

        // Check version of the invalid contract before upgrade
        assertEq(invalidUpgrade.getVersion(), "INVALID_UPGRADE_VERSION");

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
    function test_UpdateContractAddress() public {
        address newContractAddress = makeAddr("newContractAddress");

        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        vm.prank(attacker1);
        aavePM.updateContractAddress("aavePool", newContractAddress);

        vm.expectEmit();
        emit IAavePM.ContractAddressUpdated("aavePool", aavePM.getContractAddress("aavePool"), newContractAddress);

        vm.prank(owner1);
        aavePM.updateContractAddress("aavePool", newContractAddress);
        assertEq(aavePM.getContractAddress("aavePool"), newContractAddress);
    }

    function test_UpdateTokenAddress() public {
        address newTokenAddress = makeAddr("newTokenAddress");

        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        vm.prank(attacker1);
        aavePM.updateTokenAddress("USDC", newTokenAddress);

        vm.expectEmit();
        emit IAavePM.TokenAddressUpdated("USDC", aavePM.getTokenAddress("USDC"), newTokenAddress);

        vm.prank(owner1);
        aavePM.updateTokenAddress("USDC", newTokenAddress);
        assertEq(aavePM.getTokenAddress("USDC"), newTokenAddress);
    }

    function test_UpdateUniswapV3Pool() public {
        address newUniswapV3PoolAddress = makeAddr("newUniswapV3Pool");
        uint24 newUniswapV3PoolFee = UPDATED_UNISWAPV3_POOL_FEE;

        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        vm.prank(attacker1);
        aavePM.updateUniswapV3Pool("wstETH/ETH", newUniswapV3PoolAddress, newUniswapV3PoolFee);

        vm.expectEmit();
        emit IAavePM.UniswapV3PoolUpdated("wstETH/ETH", newUniswapV3PoolAddress, newUniswapV3PoolFee);

        vm.prank(owner1);
        aavePM.updateUniswapV3Pool("wstETH/ETH", newUniswapV3PoolAddress, newUniswapV3PoolFee);

        (address returnedAddress, uint24 returnedFee) = aavePM.getUniswapV3Pool("wstETH/ETH");
        assertEq(returnedAddress, newUniswapV3PoolAddress);
        assertEq(returnedFee, newUniswapV3PoolFee);
    }

    function test_UpdateHealthFactorTarget() public {
        uint16 newHealthFactorTarget = UPDATED_HEALTH_FACTOR_TARGET_MINIMUM;
        uint16 previousHealthFactorTarget = aavePM.getHealthFactorTarget();

        vm.expectEmit();
        emit IAavePM.HealthFactorTargetUpdated(previousHealthFactorTarget, newHealthFactorTarget);

        vm.prank(owner1);
        aavePM.updateHealthFactorTarget(newHealthFactorTarget);
        assertEq(aavePM.getHealthFactorTarget(), newHealthFactorTarget);
    }

    function test_UpdateHealthFactorTargetUnchanged() public {
        uint16 previousHealthFactorTarget = aavePM.getHealthFactorTarget();

        vm.expectRevert(IAavePM.AavePM__HealthFactorUnchanged.selector);
        vm.prank(owner1);
        aavePM.updateHealthFactorTarget(previousHealthFactorTarget);
    }

    function test_UpdateHealthFactorTargetBelowMinimum() public {
        uint16 newHealthFactorTarget = aavePM.getHealthFactorTargetMinimum() - 1;

        vm.expectRevert(IAavePM.AavePM__HealthFactorBelowMinimum.selector);
        vm.prank(owner1);
        aavePM.updateHealthFactorTarget(newHealthFactorTarget);
    }
}

// ================================================================
// │                       ETH / WETH TESTS                       │
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

    function test_wrapETHToWETH() public {
        rescueEth_SetUp();

        vm.prank(manager1);
        aavePM.wrapETHToWETH();
        uint256 wethBalance = WETH.balanceOf(address(aavePM));
        assertEq(wethBalance, balanceBefore);
    }

    function test_unwrapWETHToETH() public {
        rescueEth_SetUp();

        vm.startPrank(manager1);
        aavePM.wrapETHToWETH();
        uint256 wethBalance = WETH.balanceOf(address(aavePM));
        assertEq(wethBalance, balanceBefore);

        aavePM.unwrapWETHToETH();
        assertEq(address(aavePM).balance, balanceBefore);
        vm.stopPrank();
    }
}

// ================================================================
// │                           AAVE TESTS                         │
// ================================================================
contract AavePMAaveTests is AavePMTestSetup {
    function test_SupplyWstETHToAave() public {
        vm.startPrank(manager1);
        // Send some ETH to the contract and wrap it to WETH
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success, "Failed to send ETH to AavePM contract");
        aavePM.wrapETHToWETH();

        // Swap WETH for wstETH
        aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");
        uint256 wstETHbalanceBefore = wstETH.balanceOf(address(aavePM));

        // Supply wstETH to Aave
        aavePM.aaveSupplyWstETH();

        // Check the awstETH balance of the contract
        assertEq(awstETH.balanceOf(address(aavePM)), wstETHbalanceBefore);
        vm.stopPrank();
    }

    function test_AaveMaxHealthFactor() public {
        vm.startPrank(manager1);
        // Send some ETH to the contract and wrap it to WETH
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success, "Failed to send ETH to AavePM contract");
        aavePM.wrapETHToWETH();

        // Swap WETH for wstETH
        aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");

        // Supply wstETH to Aave
        aavePM.aaveSupplyWstETH();

        (,,,,, uint256 healthFactor) = aavePM.getAaveAccountData();

        // Check the health factor is UINT256_MAX (Infinity) as nothing has been borrowed
        assertEq(healthFactor, UINT256_MAX);
        vm.stopPrank();
    }

    function test_AaveBorrowUSDC() public {
        vm.startPrank(manager1);
        // Send some ETH to the contract and wrap it to WETH
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success, "Failed to send ETH to AavePM contract");
        aavePM.wrapETHToWETH();

        // Swap WETH for wstETH
        aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");

        // Supply wstETH to Aave
        aavePM.aaveSupplyWstETH();

        // Borrow USDC
        aavePM.aaveBorrowUSDC(USDC_BORROW_AMOUNT);

        // Check the USDC balance of the contract
        assertEq(USDC.balanceOf(address(aavePM)), USDC_BORROW_AMOUNT);
        vm.stopPrank();
    }
}

// ================================================================
// │                       TOKEN SWAP TESTS                       │
// ================================================================
contract AavePMTokenSwapTests is AavePMTestSetup {
    function test_SwapFailsNotEnoughTokens() public {
        bytes memory encodedRevert_NotEnoughTokensForSwap =
            abi.encodeWithSelector(IAavePM.AavePM__NotEnoughTokensForSwap.selector, "wstETH");

        vm.expectRevert(encodedRevert_NotEnoughTokensForSwap);
        vm.prank(manager1);
        aavePM.swapTokens("wstETH/ETH", "wstETH", "WETH");
    }

    function test_SwapETHToWstETH() public {
        vm.startPrank(manager1);
        // Send some ETH to the contract and wrap it to WETH
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success, "Failed to send ETH to AavePM contract");
        aavePM.wrapETHToWETH();

        // Call the swapTokens function
        (string memory tokenOutIdentifier, uint256 amountOut) = aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");

        // Check the wstETH balance of the contract
        uint256 wstETHbalance = wstETH.balanceOf(address(aavePM));

        assertEq(tokenOutIdentifier, "wstETH");
        assertEq(amountOut, wstETHbalance);
        vm.stopPrank();
    }

    function test_SwapWstETHToWETH() public {
        vm.startPrank(manager1);
        // Send some ETH to the contract and wrap it to WETH
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success, "Failed to send ETH to AavePM contract");
        aavePM.wrapETHToWETH();

        // Call the swapTokens function to get wstETH
        aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");

        // Call the swapTokens function again to convert wstETH back to WETH
        (string memory tokenOutIdentifier, uint256 amountOut) = aavePM.swapTokens("wstETH/ETH", "wstETH", "WETH");

        // Check the WETH balance of the contract
        uint256 WETHbalance = WETH.balanceOf(address(aavePM));

        assertEq(tokenOutIdentifier, "WETH");
        assertEq(amountOut, WETHbalance);
        vm.stopPrank();
    }

    function test_SwapETHToUSDC() public {
        vm.startPrank(manager1);
        // Send some ETH to the contract and wrap it to WETH
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success, "Failed to send ETH to AavePM contract");
        aavePM.wrapETHToWETH();

        // Call the swapTokens function to convert ETH to USDC
        (string memory tokenOutIdentifier, uint256 amountOut) = aavePM.swapTokens("USDC/ETH", "ETH", "USDC");

        // Check the USDC balance of the contract
        uint256 USDCbalance = USDC.balanceOf(address(aavePM));

        assertEq(tokenOutIdentifier, "USDC");
        assertEq(amountOut, USDCbalance);
        vm.stopPrank();
    }

    function test_SwapUSDCToWETH() public {
        vm.startPrank(manager1);
        // Send some ETH to the contract and wrap it to WETH
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success, "Failed to send ETH to AavePM contract");
        aavePM.wrapETHToWETH();

        // Call the swapTokens function to convert ETH to USDC
        aavePM.swapTokens("USDC/ETH", "ETH", "USDC");

        // Call the swapTokens function again to convert USDC back to WETH
        (string memory tokenOutIdentifier, uint256 amountOut) = aavePM.swapTokens("USDC/ETH", "USDC", "WETH");

        // Check the WETH balance of the contract
        uint256 WETHbalance = WETH.balanceOf(address(aavePM));

        assertEq(tokenOutIdentifier, "WETH");
        assertEq(amountOut, WETHbalance);
        vm.stopPrank();
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
        assertEq(aavePM.getContractAddress("aavePool"), s_contractAddresses["aavePool"]);
    }

    function test_GetUniswapV3Router() public {
        assertEq(aavePM.getContractAddress("uniswapV3Router"), s_contractAddresses["uniswapV3Router"]);
    }

    function test_GetWETH() public {
        assertEq(aavePM.getTokenAddress("WETH"), s_tokenAddresses["WETH"]);
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

    function test_getHealthFactorTargetMinimum() public {
        assertEq(aavePM.getHealthFactorTargetMinimum(), INITIAL_HEALTH_FACTOR_TARGET_MINIMUM);
    }

    function test_GetContractBalanceETH() public {
        assertEq(aavePM.getContractBalance("ETH"), address(aavePM).balance);
    }

    function test_GetContractBalanceWstETH() public {
        vm.startPrank(manager1);
        // Send some ETH to the contract and wrap it to WETH
        (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
        require(success, "Failed to send ETH to AavePM contract");
        aavePM.wrapETHToWETH();

        // Call the swapTokens function to get wstETH
        aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");

        // Check the wstETH balance of the contract
        assertEq(aavePM.getContractBalance("wstETH"), wstETH.balanceOf(address(aavePM)));
        vm.stopPrank();
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
