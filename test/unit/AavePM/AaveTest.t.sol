// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/Test.sol";

import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";
import {IAavePM} from "src/interfaces/IAavePM.sol";
import {IAaveFunctionsModule} from "src/interfaces/IAaveFunctionsModule.sol";

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

    function test_Exposed_GetTotalCollateralDelta() public {
        // Send ETH from manager1 to the contract
        vm.startPrank(manager1);
        sendEth(address(this), SEND_VALUE);
        vm.stopPrank();

        // TODO: These are all magic numbers, but I'm not sure where else to put them while keeping the tests understandable.

        // Collateral $1000, reinvested collateral debt $0, supplied collateral $500
        (uint256 delta1, bool isPositive1) = abi.decode(
            _delegateCallHelper(
                "aaveFunctionsModule",
                abi.encodeWithSelector(
                    IAaveFunctionsModule.getTotalCollateralDelta.selector, 1000 * 1e8, 0 * 1e6, 500 * 1e6
                )
            ),
            (uint256, bool)
        );
        assertEq(delta1, 500 * 1e6);
        assertTrue(isPositive1);

        // Collateral $1000, reinvested collateral $0, supplied collateral $1500
        (uint256 delta2, bool isPositive2) = abi.decode(
            _delegateCallHelper(
                "aaveFunctionsModule",
                abi.encodeWithSelector(IAaveFunctionsModule.getTotalCollateralDelta.selector, 1000 * 1e8, 0, 1000 * 1e6)
            ),
            (uint256, bool)
        );
        assertEq(delta2, 0);
        assertTrue(isPositive2);

        // Collateral $1000, reinvested collateral $0, supplied collateral $1500
        (uint256 delta3, bool isPositive3) = abi.decode(
            _delegateCallHelper(
                "aaveFunctionsModule",
                abi.encodeWithSelector(IAaveFunctionsModule.getTotalCollateralDelta.selector, 1000 * 1e8, 0, 1500 * 1e6)
            ),
            (uint256, bool)
        );
        assertEq(delta3, 500 * 1e6);
        assertFalse(isPositive3);

        // Collateral $1000, reinvested collateral $200, supplied collateral $300
        (uint256 delta4, bool isPositive4) = abi.decode(
            _delegateCallHelper(
                "aaveFunctionsModule",
                abi.encodeWithSelector(
                    IAaveFunctionsModule.getTotalCollateralDelta.selector, 1000 * 1e8, 200 * 1e6, 300 * 1e6
                )
            ),
            (uint256, bool)
        );
        assertEq(delta4, 500 * 1e6);
        assertTrue(isPositive4);

        // Collateral $1000, reinvested collateral $200, supplied collateral $1000
        (uint256 delta5, bool isPositive5) = abi.decode(
            _delegateCallHelper(
                "aaveFunctionsModule",
                abi.encodeWithSelector(
                    IAaveFunctionsModule.getTotalCollateralDelta.selector, 1000 * 1e8, 200 * 1e6, 1000 * 1e6
                )
            ),
            (uint256, bool)
        );
        assertEq(delta5, 200 * 1e6);
        assertFalse(isPositive5);
    }
}
