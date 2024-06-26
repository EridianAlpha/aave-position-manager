// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/Test.sol";

import {AavePMTestSetup} from "test/unit/AavePM/TestSetupTest.t.sol";

import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
import {IAaveFunctionsModule} from "src/interfaces/IAaveFunctionsModule.sol";

// ================================================================
// │                         GETTER TESTS                         │
// ================================================================
contract AavePMGetterTests is AavePMTestSetup {
    function test_GetCreator() public {
        assertEq(aavePM.getCreator(), contractCreator);
    }

    function test_GetEventBlockNumbers() public {
        uint256 initialEventBlockNumbersLength = aavePM.getEventBlockNumbers().length;

        // Increase the block number to ensure a new event block is stored
        vm.roll(block.number + 1);

        // Trigger an event by updating the Health Factor Target
        vm.startPrank(manager1);
        aavePM.updateHealthFactorTarget(HEALTH_FACTOR_TARGET_MINIMUM);
        vm.stopPrank();

        uint256 endEventBlockNumbersLength = aavePM.getEventBlockNumbers().length;

        // Check the event block numbers are now one greater than the initial length.
        assertEq(endEventBlockNumbersLength, initialEventBlockNumbersLength + 1);
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

    function test_GetWithdrawnUSDCTotal() public {
        // Send ETH from manager1 to the contract
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply ETH to Aave
        aavePM.aaveSupplyFromContractBalance();

        // Withdraw USDC from Aave
        aavePM.aaveBorrowAndWithdrawUSDC(USDC_BORROW_AMOUNT, owner1);
        vm.stopPrank();

        assertEq(aavePM.getWithdrawnUSDCTotal(), USDC_BORROW_AMOUNT);
    }

    function test_GetReinvestedDebtTotal() public {
        // Send ETH from manager1 to the contract
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply ETH to Aave
        aavePM.aaveSupplyFromContractBalance();

        // Reinvest
        (uint256 reinvestedDebt) = aavePM.reinvest();
        vm.stopPrank();

        assertEq(aavePM.getReinvestedDebtTotal(), reinvestedDebt);
    }

    function test_GetTotalCollateralDelta() public {
        // Not a great test, but since it's a calculation that's based on the passage of time,
        // so on a mainnet fork it can't easily be tested in a unit test.
        (uint256 totalCollateralDelta, bool isPositive) = aavePM.getTotalCollateralDelta();
        assertEq(totalCollateralDelta, 0);
        assertTrue(isPositive);
    }

    function test_GetSuppliedCollateralTotal() public {
        // Send ETH from manager1 to the contract
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply ETH to Aave
        uint256 suppliedCollateral = aavePM.aaveSupplyFromContractBalance();

        assertEq(aavePM.getSuppliedCollateralTotal(), suppliedCollateral);
    }

    function test_GetMaxBorrowAndWithdrawUSDCAmount() public {
        // Check initial maxBorrowAndWithdrawUSDCAmount is 0
        assertEq(aavePM.getMaxBorrowAndWithdrawUSDCAmount(), 0);

        // Send ETH from manager1 to the contract
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply ETH to Aave
        aavePM.aaveSupplyFromContractBalance();

        // Check that the maxBorrowAndWithdrawUSDCAmount is greater than 0
        assert(aavePM.getMaxBorrowAndWithdrawUSDCAmount() > 0);
    }

    function test_GetReinvestableAmount() public {
        // Check initial reinvestable amount is 0.
        assertEq(aavePM.getReinvestableAmount(), 0);

        // Send ETH from manager1 to the contract
        vm.startPrank(manager1);
        sendEth(address(aavePM), SEND_VALUE);

        // Supply ETH to Aave
        aavePM.aaveSupplyFromContractBalance();

        uint256 reinvestableAmount = aavePM.getReinvestableAmount();

        (uint256 totalCollateralBase, uint256 totalDebtBase,, uint256 currentLiquidationThreshold,,) =
            IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(address((aavePM)));

        uint256 reinvestableAmountCalc = abi.decode(
            delegateCallHelper(
                "aaveFunctionsModule",
                abi.encodeWithSelector(
                    IAaveFunctionsModule.calculateMaxBorrowUSDC.selector,
                    totalCollateralBase,
                    totalDebtBase,
                    currentLiquidationThreshold,
                    aavePM.getHealthFactorTarget()
                )
            ),
            (uint256)
        );

        assertEq(reinvestableAmount, reinvestableAmountCalc / 1e2);
        vm.stopPrank();
    }
}
