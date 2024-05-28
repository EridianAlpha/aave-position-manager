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
        (, uint24 initialFee) = aavePM.getUniswapV3Pool("wstETH/ETH");
        address newUniswapV3PoolAddress = makeAddr("newUniswapV3Pool");
        uint24 newUniswapV3PoolFee = initialFee + UNISWAPV3_POOL_FEE_CHANGE;

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

    function test_IncreaseHealthFactorTarget() public {
        uint16 previousHealthFactorTarget = aavePM.getHealthFactorTarget();
        uint16 newHealthFactorTarget = previousHealthFactorTarget + HEALTH_FACTOR_TARGET_CHANGE;

        vm.expectEmit();
        emit IAavePM.HealthFactorTargetUpdated(previousHealthFactorTarget, newHealthFactorTarget);

        vm.prank(manager1);
        aavePM.updateHealthFactorTarget(newHealthFactorTarget);
        assertEq(aavePM.getHealthFactorTarget(), newHealthFactorTarget);
    }

    function test_UpdateHealthFactorTargetUnchanged() public {
        uint16 previousHealthFactorTarget = aavePM.getHealthFactorTarget();

        vm.expectRevert(IAavePM.AavePM__HealthFactorUnchanged.selector);
        vm.prank(manager1);
        aavePM.updateHealthFactorTarget(previousHealthFactorTarget);
    }

    function test_UpdateHealthFactorTargetBelowMinimum() public {
        uint16 newHealthFactorTarget = aavePM.getHealthFactorTargetMinimum() - 1;

        vm.expectRevert(IAavePM.AavePM__HealthFactorBelowMinimum.selector);
        vm.prank(manager1);
        aavePM.updateHealthFactorTarget(newHealthFactorTarget);
    }

    function test_IncreaseSlippageTolerance() public {
        uint16 previousSlippageTolerance = aavePM.getSlippageTolerance();

        // Calculation is 100 / slippageTolerance so subtracting from the previous value
        // will increase the slippage tolerance.
        uint16 newSlippageTolerance = previousSlippageTolerance - SLIPPAGE_TOLERANCE_CHANGE;

        vm.expectEmit();
        emit IAavePM.SlippageToleranceUpdated(previousSlippageTolerance, newSlippageTolerance);

        vm.prank(manager1);
        aavePM.updateSlippageTolerance(newSlippageTolerance);
        assertEq(aavePM.getSlippageTolerance(), newSlippageTolerance);
    }

    function test_UpdateSlippageToleranceUnchanged() public {
        uint16 previousSlippageTolerance = aavePM.getSlippageTolerance();

        vm.expectRevert(IAavePM.AavePM__SlippageToleranceUnchanged.selector);
        vm.prank(manager1);
        aavePM.updateSlippageTolerance(previousSlippageTolerance);
    }

    function test_UpdateSlippageToleranceAboveMaximum() public {
        // Calculation is 100 / slippageToleranceMaximum,
        // so subtract from the maximum to get the out of bounds value.
        uint16 newSlippageTolerance = aavePM.getSlippageToleranceMaximum() - 1;

        vm.expectRevert(IAavePM.AavePM__SlippageToleranceAboveMaximum.selector);
        vm.prank(manager1);
        aavePM.updateSlippageTolerance(newSlippageTolerance);
    }
}
