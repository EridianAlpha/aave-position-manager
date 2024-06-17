// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";
import {console} from "forge-std/Test.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// ================================================================
// │                          ATTACK TESTS                        │
// ================================================================

// While most of these tests are covered in other test contracts, these tests are a check on core functionality.
// Specifically, ensuring that all public functions are only accessible by the correct roles.
contract AavePMAttackTests is AavePMTestSetup {
    function test_AttackSetup() public {
        // Fund the contract, and set it up to a functioning state
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);
        aavePM.aaveSupplyFromContractBalance();
        aavePM.reinvest();
        vm.stopPrank();
    }

    // ================================================================
    // │                    FUNCTIONS - INITIALIZER                   │
    // ================================================================
    function test_AttackInitialize() public {
        test_AttackSetup();

        // Contract addresses
        IAavePM.ContractAddress[] memory contractAddresses = new IAavePM.ContractAddress[](1);
        contractAddresses[0] = IAavePM.ContractAddress("aavePool", makeAddr("test"));

        // Token addresses
        IAavePM.TokenAddress[] memory tokenAddresses = new IAavePM.TokenAddress[](1);
        tokenAddresses[0] = IAavePM.TokenAddress("WETH", makeAddr("test"));

        // UniswapV3 pools
        IAavePM.UniswapV3Pool[] memory uniswapV3Pools = new IAavePM.UniswapV3Pool[](1);
        uniswapV3Pools[0] = IAavePM.UniswapV3Pool("wstETH/ETH", makeAddr("test"), 200);

        vm.startPrank(attacker1);
        vm.expectRevert(InvalidInitialization.selector);
        aavePM.initialize(attacker1, contractAddresses, tokenAddresses, uniswapV3Pools, 250, 200, 20);
        vm.stopPrank();
    }

    // ================================================================
    // │                     FUNCTIONS - UPDATES                      │
    // ================================================================
    function test_AttackUpdateContractAddress() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        aavePM.updateContractAddress("aavePool", makeAddr("test"));
        vm.stopPrank();
    }

    function test_AttackUpdateTokenAddress() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        aavePM.updateTokenAddress("WETH", makeAddr("test"));
        vm.stopPrank();
    }

    function test_AttackUpdateUniswapV3Pool() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        aavePM.updateUniswapV3Pool("wstETH/ETH", makeAddr("test"), 200);
        vm.stopPrank();
    }

    function testFail_AttackUpdateHealthFactorTarget() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        aavePM.updateHealthFactorTarget(aavePM.getHealthFactorTargetMinimum() + HEALTH_FACTOR_TARGET_CHANGE);
        vm.stopPrank();
    }

    function testFail_AttackUpdateSlippageTolerance() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        aavePM.updateSlippageTolerance(aavePM.getSlippageToleranceMaximum() - SLIPPAGE_TOLERANCE_CHANGE);
        vm.stopPrank();
    }

    function testFail_AttackUpdateManagerDailyInvocationLimit() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        aavePM.updateManagerDailyInvocationLimit(
            aavePM.getManagerDailyInvocationLimit() + MANAGER_DAILY_INVOCATION_LIMIT_CHANGE
        );
        vm.stopPrank();
    }

    // ================================================================
    // │                   FUNCTIONS - CORE FUNCTIONS                 │
    // ================================================================
    function test_AttackRebalance() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Manager);
        aavePM.rebalance();
        vm.stopPrank();
    }

    function test_AttackReinvest() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Manager);
        aavePM.reinvest();
        vm.stopPrank();
    }

    function test_AttackDeleverage() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Manager);
        aavePM.deleverage();
        vm.stopPrank();
    }

    function test_AttackAaveSupplyFromContractBalance() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Manager);
        aavePM.aaveSupplyFromContractBalance();
        vm.stopPrank();
    }

    function test_AttackAaveRepayUSDCFromContractBalance() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Manager);
        aavePM.aaveRepayUSDCFromContractBalance();
        vm.stopPrank();
    }

    // ================================================================
    // │                FUNCTIONS - WITHDRAW FUNCTIONS                │
    // ================================================================
    function test_AttackRescueEth() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Manager);
        aavePM.rescueEth(attacker1);
        vm.stopPrank();
    }

    function test_AttackWithdrawTokensFromContractBalance() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Manager);
        aavePM.withdrawTokensFromContractBalance("USDC", attacker1);
        vm.stopPrank();
    }

    function test_AttackAaveWithdrawWstETH() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Manager);
        aavePM.aaveWithdrawWstETH(1e18, attacker1);
        vm.stopPrank();
    }

    function test_AttackAaveBorrowAndWithdrawUSDC() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Manager);
        aavePM.aaveBorrowAndWithdrawUSDC(1e6, attacker1);
        vm.stopPrank();
    }

    function test_AttackAaveClosePosition() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Manager);
        aavePM.aaveClosePosition(attacker1);
        vm.stopPrank();
    }

    // ================================================================
    // │             INHERITED FUNCTIONS - ACCESS CONTROLS            │
    // ================================================================
    function test_AttackGetRoleMembers() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        aavePM.grantRole(keccak256("OWNER_ROLE"), attacker1);

        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        aavePM.grantRole(keccak256("MANAGER_ROLE"), attacker1);
        vm.stopPrank();
    }

    function test_AttackRevokeRole() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        aavePM.revokeRole(keccak256("OWNER_ROLE"), owner1);

        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        aavePM.revokeRole(keccak256("MANAGER_ROLE"), manager1);
        vm.stopPrank();
    }

    // ================================================================
    // │                 INHERITED FUNCTIONS - UPGRADES               │
    // ================================================================
    function test_AttackUpgradeToAndCall() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Owner);
        aavePM.upgradeToAndCall(makeAddr("test"), "0x");
        vm.stopPrank();
    }

    // ================================================================
    // │             INHERITED FUNCTIONS - AAVE FLASH LOAN            │
    // ================================================================
    function test_AttackExecuteOperation() public {
        test_AttackSetup();
        vm.startPrank(attacker1);
        vm.expectRevert(IAavePM.AaveFunctions__FlashLoanMsgSenderUnauthorized.selector);
        aavePM.executeOperation(makeAddr("test"), 1e8, 1e2, owner1, "0x");
        vm.stopPrank();
    }
}
