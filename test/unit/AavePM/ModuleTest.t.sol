// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {IAaveFunctionsModule} from "src/interfaces/IAaveFunctionsModule.sol";
import {AaveFunctionsModule} from "src/modules/AaveFunctionsModule.sol";

import {IBorrowAndWithdrawUSDCModule} from "src/interfaces/IBorrowAndWithdrawUSDCModule.sol";
import {BorrowAndWithdrawUSDCModule} from "src/modules/BorrowAndWithdrawUSDCModule.sol";

import {IRebalanceModule} from "src/interfaces/IRebalanceModule.sol";
import {RebalanceModule} from "src/modules/RebalanceModule.sol";

import {IReinvestModule} from "src/interfaces/IReinvestModule.sol";
import {ReinvestModule} from "src/modules/ReinvestModule.sol";

import {ITokenSwapsModule} from "src/interfaces/ITokenSwapsModule.sol";
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

    function test_CheckAavePMProxyAddressFail() public {
        AaveFunctionsModule aaveFunctionsModule = new AaveFunctionsModule(address(this));

        vm.expectRevert(IAaveFunctionsModule.AaveFunctionsModule__InvalidAavePMProxyAddress.selector);
        aaveFunctionsModule.aaveSupply(makeAddr("test"), makeAddr("test"), 0);

        vm.expectRevert(IAaveFunctionsModule.AaveFunctionsModule__InvalidAavePMProxyAddress.selector);
        aaveFunctionsModule.aaveWithdrawCollateral(makeAddr("test"), makeAddr("test"), 0);

        vm.expectRevert(IAaveFunctionsModule.AaveFunctionsModule__InvalidAavePMProxyAddress.selector);
        aaveFunctionsModule.aaveBorrow(makeAddr("test"), makeAddr("test"), 0);

        vm.expectRevert(IAaveFunctionsModule.AaveFunctionsModule__InvalidAavePMProxyAddress.selector);
        aaveFunctionsModule.aaveRepayDebt(makeAddr("test"), makeAddr("test"), 0);

        vm.expectRevert(IAaveFunctionsModule.AaveFunctionsModule__InvalidAavePMProxyAddress.selector);
        aaveFunctionsModule.convertExistingBalanceToWstETHAndSupplyToAave();
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

    function test_CheckAavePMProxyAddressFail() public {
        BorrowAndWithdrawUSDCModule borrowAndWithdrawUSDCModule = new BorrowAndWithdrawUSDCModule(address(this));

        vm.expectRevert(IBorrowAndWithdrawUSDCModule.BorrowAndWithdrawUSDCModule__InvalidAavePMProxyAddress.selector);
        borrowAndWithdrawUSDCModule.borrowAndWithdrawUSDC(0, makeAddr("test"));
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

    function test_CheckAavePMProxyAddressFail() public {
        RebalanceModule rebalanceModule = new RebalanceModule(address(this));

        vm.expectRevert(IRebalanceModule.RebalanceModule__InvalidAavePMProxyAddress.selector);
        rebalanceModule.rebalance();
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

    function test_CheckAavePMProxyAddressFail() public {
        ReinvestModule reinvestModule = new ReinvestModule(address(this));

        vm.expectRevert(IReinvestModule.ReinvestModule__InvalidAavePMProxyAddress.selector);
        reinvestModule.reinvest();
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

    function test_CheckAavePMProxyAddressFail() public {
        TokenSwapsModule tokenSwapsModule = new TokenSwapsModule(address(this));

        vm.expectRevert(ITokenSwapsModule.TokenSwapsModule__InvalidAavePMProxyAddress.selector);
        tokenSwapsModule.swapTokens("USDC/ETH", "USDC", "ETH");

        vm.expectRevert(ITokenSwapsModule.TokenSwapsModule__InvalidAavePMProxyAddress.selector);
        tokenSwapsModule.wrapETHToWETH();
    }
}
