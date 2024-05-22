// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AavePM} from "src/AavePM.sol";
import {IAavePM} from "src/interfaces/IAavePM.sol";

import {HelperConfig} from "script/HelperConfig.s.sol";
import {InvalidOwner} from "test/testHelperContracts/InvalidOwner.sol";
import {InvalidUpgrade} from "test/testHelperContracts/InvalidUpgrade.sol";
import {AavePMUpgradeExample} from "test/testHelperContracts/AavePMUpgradeExample.sol";

import {DeployAavePM} from "script/DeployAavePM.s.sol";

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

// ================================================================
// │                       TOKEN SWAP TESTS                       │
// ================================================================
contract AavePMTokenSwapTests is AavePMTestSetup {
// function test_SwapFailsNotEnoughTokens() public {
//     bytes memory encodedRevert_NotEnoughTokensForSwap =
//         abi.encodeWithSelector(IAavePM.AavePM__NotEnoughTokensForSwap.selector, "wstETH");

//     vm.expectRevert(encodedRevert_NotEnoughTokensForSwap);
//     vm.prank(manager1);
//     aavePM.swapTokens("wstETH/ETH", "wstETH", "WETH");
// }

// function test_SwapETHToWstETH() public {
//     vm.startPrank(manager1);
//     // Send some ETH to the contract and wrap it to WETH
//     (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
//     require(success, "Failed to send ETH to AavePM contract");
//     aavePM.wrapETHToWETH();

//     // Call the swapTokens function
//     (string memory tokenOutIdentifier, uint256 amountOut) = aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");

//     // Check the wstETH balance of the contract
//     uint256 wstETHbalance = wstETH.balanceOf(address(aavePM));

//     assertEq(tokenOutIdentifier, "wstETH");
//     assertEq(amountOut, wstETHbalance);
//     vm.stopPrank();
// }

// function test_SwapWstETHToWETH() public {
//     vm.startPrank(manager1);
//     // Send some ETH to the contract and wrap it to WETH
//     (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
//     require(success, "Failed to send ETH to AavePM contract");
//     aavePM.wrapETHToWETH();

//     // Call the swapTokens function to get wstETH
//     aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");

//     // Call the swapTokens function again to convert wstETH back to WETH
//     (string memory tokenOutIdentifier, uint256 amountOut) = aavePM.swapTokens("wstETH/ETH", "wstETH", "WETH");

//     // Check the WETH balance of the contract
//     uint256 WETHbalance = WETH.balanceOf(address(aavePM));

//     assertEq(tokenOutIdentifier, "WETH");
//     assertEq(amountOut, WETHbalance);
//     vm.stopPrank();
// }

// function test_SwapETHToUSDC() public {
//     vm.startPrank(manager1);
//     // Send some ETH to the contract and wrap it to WETH
//     (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
//     require(success, "Failed to send ETH to AavePM contract");
//     aavePM.wrapETHToWETH();

//     // Call the swapTokens function to convert ETH to USDC
//     (string memory tokenOutIdentifier, uint256 amountOut) = aavePM.swapTokens("USDC/ETH", "ETH", "USDC");

//     // Check the USDC balance of the contract
//     uint256 USDCbalance = USDC.balanceOf(address(aavePM));

//     assertEq(tokenOutIdentifier, "USDC");
//     assertEq(amountOut, USDCbalance);
//     vm.stopPrank();
// }

// function test_SwapUSDCToWETH() public {
//     vm.startPrank(manager1);
//     // Send some ETH to the contract and wrap it to WETH
//     (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
//     require(success, "Failed to send ETH to AavePM contract");
//     aavePM.wrapETHToWETH();

//     // Call the swapTokens function to convert ETH to USDC
//     aavePM.swapTokens("USDC/ETH", "ETH", "USDC");

//     // Call the swapTokens function again to convert USDC back to WETH
//     (string memory tokenOutIdentifier, uint256 amountOut) = aavePM.swapTokens("USDC/ETH", "USDC", "WETH");

//     // Check the WETH balance of the contract
//     uint256 WETHbalance = WETH.balanceOf(address(aavePM));

//     assertEq(tokenOutIdentifier, "WETH");
//     assertEq(amountOut, WETHbalance);
//     vm.stopPrank();
// }
}
