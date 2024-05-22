// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

// ================================================================
// │                           AAVE TESTS                         │
// ================================================================
// TODO: Fix these tests
// contract AavePMAaveTests is AavePMTestSetup {
//     function test_SupplyWstETHToAave() public {
//         vm.startPrank(manager1);
//         // Send some ETH to the contract and wrap it to WETH
//         (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
//         require(success, "Failed to send ETH to AavePM contract");
//         aavePM.wrapETHToWETH();

//         // Swap WETH for wstETH
//         aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");
//         uint256 wstETHbalanceBefore = wstETH.balanceOf(address(aavePM));

//         // Supply wstETH to Aave
//         // TODO: Use external function to supply the collateral
//         aavePM.aaveSupplyWstETH();

//         // Check the awstETH balance of the contract
//         assertEq(awstETH.balanceOf(address(aavePM)), wstETHbalanceBefore);
//         vm.stopPrank();
//     }

//     function test_AaveMaxHealthFactor() public {
//         vm.startPrank(manager1);
//         // Send some ETH to the contract and wrap it to WETH
//         (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
//         require(success, "Failed to send ETH to AavePM contract");
//         aavePM.wrapETHToWETH();

//         // Swap WETH for wstETH
//         aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");

//         // Supply wstETH to Aave
//         aavePM.aaveSupplyWstETH();

//         (,,,,, uint256 healthFactor) = aavePM.getAaveAccountData();

//         // Check the health factor is UINT256_MAX (Infinity) as nothing has been borrowed
//         assertEq(healthFactor, UINT256_MAX);
//         vm.stopPrank();
//     }

//     function test_AaveBorrowUSDC() public {
//         vm.startPrank(manager1);
//         // Send some ETH to the contract and wrap it to WETH
//         (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
//         require(success, "Failed to send ETH to AavePM contract");
//         aavePM.wrapETHToWETH();

//         // Swap WETH for wstETH
//         aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");

//         // Supply wstETH to Aave
//         aavePM.aaveSupplyWstETH();

//         // Borrow USDC
//         aavePM.aaveBorrowUSDC(USDC_BORROW_AMOUNT);

//         // Check the USDC balance of the contract
//         assertEq(USDC.balanceOf(address(aavePM)), USDC_BORROW_AMOUNT);
//         vm.stopPrank();
//     }
// }
