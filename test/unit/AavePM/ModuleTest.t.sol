// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {AaveFunctionsModule} from "src/modules/AaveFunctionsModule.sol";
import {BorrowAndWithdrawUSDCModule} from "src/modules/BorrowAndWithdrawUSDCModule.sol";
import {RebalanceModule} from "src/modules/RebalanceModule.sol";
import {ReinvestModule} from "src/modules/ReinvestModule.sol";
import {TokenSwapsModule} from "src/modules/TokenSwapsModule.sol";

// ================================================================
// │                        MODULE TESTS                          │
// ================================================================
contract AaveFunctionsModuleTests is Test, AaveFunctionsModule {
    AaveFunctionsModule aaveFunctionsModule = new AaveFunctionsModule();

    function test_GetVersion() public {
        assertEq(keccak256(abi.encodePacked(aaveFunctionsModule.getVersion())), keccak256(abi.encodePacked(VERSION)));
    }
}

contract BorrowAndWithdrawUSDCModuleTests is Test, BorrowAndWithdrawUSDCModule {
    BorrowAndWithdrawUSDCModule borrowAndWithdrawUSDCModule = new BorrowAndWithdrawUSDCModule();

    function test_GetVersion() public {
        assertEq(
            keccak256(abi.encodePacked(borrowAndWithdrawUSDCModule.getVersion())), keccak256(abi.encodePacked(VERSION))
        );
    }
}

contract RebalanceModuleTests is Test, RebalanceModule {
    RebalanceModule rebalanceModule = new RebalanceModule();

    function test_GetVersion() public {
        assertEq(keccak256(abi.encodePacked(rebalanceModule.getVersion())), keccak256(abi.encodePacked(VERSION)));
    }
}

contract ReinvestModuleTests is Test, ReinvestModule {
    ReinvestModule reinvestModule = new ReinvestModule();

    function test_GetVersion() public {
        assertEq(keccak256(abi.encodePacked(reinvestModule.getVersion())), keccak256(abi.encodePacked(VERSION)));
    }
}

contract TokenSwapsModuleTests is Test, TokenSwapsModule {
    TokenSwapsModule tokenSwapsModule = new TokenSwapsModule();

    function test_GetVersion() public {
        assertEq(keccak256(abi.encodePacked(tokenSwapsModule.getVersion())), keccak256(abi.encodePacked(VERSION)));
    }
}
