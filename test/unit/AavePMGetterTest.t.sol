// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

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

    // TODO: Fix these tests
    // function test_GetContractBalanceWstETH() public {
    //     vm.startPrank(manager1);
    //     // Send some ETH to the contract and wrap it to WETH
    //     (bool success,) = address(aavePM).call{value: SEND_VALUE}("");
    //     require(success, "Failed to send ETH to AavePM contract");
    //     aavePM.wrapETHToWETH();

    //     // Call the swapTokens function to get wstETH
    //     aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");

    //     // Check the wstETH balance of the contract
    //     assertEq(aavePM.getContractBalance("wstETH"), wstETH.balanceOf(address(aavePM)));
    //     vm.stopPrank();
    // }
}
