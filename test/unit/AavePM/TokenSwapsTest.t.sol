    // SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";
import {console} from "forge-std/Test.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";

import {ITokenSwapsModule} from "src/interfaces/ITokenSwapsModule.sol";

// ================================================================
// │                          MISC TESTS                          │
// ================================================================
contract TokenSwapsTests is AavePMTestSetup {
    function test_Exposed_WrapETHToWETH() public {
        // Send ETH from manager1 to the contract
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE);
        vm.stopPrank();

        // Wrap the ETH to WETH
        _delegateCallHelper(
            "tokenSwapsModule", abi.encodeWithSelector(ITokenSwapsModule.wrapETHToWETH.selector, new bytes(0))
        );
    }

    function test_Exposed_WrapETHToWETHZeroETH() public {
        _delegateCallHelper(
            "tokenSwapsModule", abi.encodeWithSelector(ITokenSwapsModule.wrapETHToWETH.selector, new bytes(0))
        );
    }
}
