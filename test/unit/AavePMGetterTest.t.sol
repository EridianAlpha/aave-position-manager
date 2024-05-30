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
        assertEq(keccak256(abi.encodePacked(aavePM.getVersion())), keccak256(abi.encodePacked(VERSION)));
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
        assertEq(aavePM.getHealthFactorTarget(), s_healthFactorTarget);
    }

    function test_getHealthFactorTargetMinimum() public {
        assertEq(aavePM.getHealthFactorTargetMinimum(), HEALTH_FACTOR_TARGET_MINIMUM);
    }

    function test_GetSlippageTolerance() public {
        assertEq(aavePM.getSlippageTolerance(), s_slippageTolerance);
    }

    function test_GetContractBalanceETH() public {
        assertEq(aavePM.getContractBalance("ETH"), address(aavePM).balance);
    }

    function test_getRoleMembers() public {
        address[] memory managers = aavePM.getRoleMembers("MANAGER_ROLE");
        assertEq(managers.length, 3);

        bool isManager1Present = false;
        bool isOwner1Present = false;
        bool isAavePMPresent = false;

        for (uint256 i = 0; i < managers.length; i++) {
            if (managers[i] == manager1) {
                isManager1Present = true;
            }
            if (managers[i] == owner1) {
                isOwner1Present = true;
            }
            if (managers[i] == address(aavePM)) {
                isAavePMPresent = true;
            }
        }

        require(isManager1Present, "Manager1 is not present in the MANAGER_ROLE");
        require(isOwner1Present, "Owner1 is not present in the MANAGER_ROLE");
        require(isAavePMPresent, "AavePM is not present in the MANAGER_ROLE");

        address[] memory owners = aavePM.getRoleMembers("OWNER_ROLE");
        assertEq(owners.length, 1);
        assertEq(owners[0], owner1);
    }

    // TODO: Fix these tests
    // function test_GetContractBalanceWstETH() public {
    //     vm.startPrank(manager1);
    //     // Send some ETH to the contract and wrap it to WETH
    //     sendEth(address(aavePM), SEND_VALUE);
    //     aavePM.wrapETHToWETH();

    //     // Call the swapTokens function to get wstETH
    //     aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");

    //     // Check the wstETH balance of the contract
    //     assertEq(aavePM.getContractBalance("wstETH"), wstETH.balanceOf(address(aavePM)));
    //     vm.stopPrank();
    // }
}
