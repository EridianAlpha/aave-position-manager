// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

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
        uint16 newHealthFactorTarget = INCREASED_HEALTH_FACTOR_TARGET;
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
