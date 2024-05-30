// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";

// ================================================================
// │                           AAVE TESTS                         │
// ================================================================
contract AavePMAaveTests is AavePMTestSetup {
    function flashLoanSetup() public view returns (address, uint256, uint256, bytes memory) {
        address asset = getTokenAddress("USDC");
        uint256 amount = 100;
        uint256 premium = 2;
        bytes memory params = abi.encode(asset, amount, premium);
        return (asset, amount, premium, params);
    }

    function test_FlashLoanRevertIfMsgSenderNotAavePool() public {
        (address asset, uint256 amount, uint256 premium, bytes memory params) = flashLoanSetup();

        vm.startPrank(manager1);
        vm.expectRevert(IAavePM.AaveFunctions__FlashLoanMsgSenderUnauthorized.selector);
        aavePM.executeOperation(asset, amount, premium, attacker1, params);
        vm.stopPrank();
    }

    function test_FlashLoanRevertIfInitiatorNotAavePM() public {
        (address asset, uint256 amount, uint256 premium, bytes memory params) = flashLoanSetup();

        vm.startPrank(s_contractAddresses["aavePool"]);
        vm.expectRevert(IAavePM.AaveFunctions__FlashLoanInitiatorUnauthorized.selector);
        aavePM.executeOperation(asset, amount, premium, attacker1, params);
    }
}
