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
    constructor() AaveFunctionsModule(address(this)) {}

    function test_GetVersion() public {
        AaveFunctionsModule aaveFunctionsModule = new AaveFunctionsModule(address(this));
        assertEq(keccak256(abi.encodePacked(aaveFunctionsModule.getVersion())), keccak256(abi.encodePacked(VERSION)));
    }

    function test_CheckAavePMProxyAddress() public {
        AaveFunctionsModule aaveFunctionsModule = new AaveFunctionsModule(address(this));
        assertEq(aaveFunctionsModule.aavePMProxyAddress(), address(this));
    }
}

contract BorrowAndWithdrawUSDCModuleTests is Test, BorrowAndWithdrawUSDCModule {
    constructor() BorrowAndWithdrawUSDCModule(address(this)) {}

    function test_GetVersion() public {
        BorrowAndWithdrawUSDCModule borrowAndWithdrawUSDCModule = new BorrowAndWithdrawUSDCModule(address(this));
        assertEq(
            keccak256(abi.encodePacked(borrowAndWithdrawUSDCModule.getVersion())), keccak256(abi.encodePacked(VERSION))
        );
    }

    function test_CheckAavePMProxyAddress() public {
        BorrowAndWithdrawUSDCModule borrowAndWithdrawUSDCModule = new BorrowAndWithdrawUSDCModule(address(this));
        assertEq(borrowAndWithdrawUSDCModule.aavePMProxyAddress(), address(this));
    }
}

contract RebalanceModuleTests is Test, RebalanceModule {
    constructor() RebalanceModule(address(this)) {}

    function test_GetVersion() public {
        RebalanceModule rebalanceModule = new RebalanceModule(address(this));
        assertEq(keccak256(abi.encodePacked(rebalanceModule.getVersion())), keccak256(abi.encodePacked(VERSION)));
    }

    function test_CheckAavePMProxyAddress() public {
        RebalanceModule rebalanceModule = new RebalanceModule(address(this));
        assertEq(rebalanceModule.aavePMProxyAddress(), address(this));
    }
}

contract ReinvestModuleTests is Test, ReinvestModule {
    constructor() ReinvestModule(address(this)) {}

    function test_GetVersion() public {
        ReinvestModule reinvestModule = new ReinvestModule(address(this));
        assertEq(keccak256(abi.encodePacked(reinvestModule.getVersion())), keccak256(abi.encodePacked(VERSION)));
    }

    function test_CheckAavePMProxyAddress() public {
        ReinvestModule reinvestModule = new ReinvestModule(address(this));
        assertEq(reinvestModule.aavePMProxyAddress(), address(this));
    }
}

contract TokenSwapsModuleTests is Test, TokenSwapsModule {
    constructor() TokenSwapsModule(address(this)) {}

    function test_GetVersion() public {
        TokenSwapsModule tokenSwapsModule = new TokenSwapsModule(address(this));
        assertEq(keccak256(abi.encodePacked(tokenSwapsModule.getVersion())), keccak256(abi.encodePacked(VERSION)));
    }

    function test_CheckAavePMProxyAddress() public {
        TokenSwapsModule tokenSwapsModule = new TokenSwapsModule(address(this));
        assertEq(tokenSwapsModule.aavePMProxyAddress(), address(this));
    }
}
