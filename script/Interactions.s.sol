// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

import {AavePM} from "src/AavePM.sol";

import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// ================================================================
// │                             SETUP                            │
// ================================================================
contract Interactions is Script {
    // TODO: Write tests for this contract and remove the test function.
    function test() public {} // Added to remove this whole contract from coverage report.

    AavePM public aavePM;

    function setup() public {
        address _aavePMAddressProxy = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);
        require(_aavePMAddressProxy != address(0), "ERC1967Proxy address is invalid");
        aavePM = AavePM(payable(_aavePMAddressProxy));
    }

    // ================================================================
    // │                             FUND                             │
    // ================================================================
    function fundAavePM(uint256 value) public {
        setup();
        vm.startBroadcast();
        (bool callSuccess,) = address(aavePM).call{value: value}("");
        if (!callSuccess) revert("Failed to send ETH to AavePM");
        vm.stopBroadcast();
    }

    // ================================================================
    // │                            UPGRADE                           │
    // ================================================================
    function upgradeAavePM() public {
        setup();
        vm.startBroadcast();
        AavePM newAavePM = new AavePM();
        aavePM.upgradeToAndCall(address(newAavePM), "");
        // TODO: Add module deployments here.
        vm.stopBroadcast();
    }

    // ================================================================
    // │                     FUNCTIONS - UPDATES                      │
    // ================================================================
    function updateHFTAavePM(uint16 value) public {
        setup();
        vm.startBroadcast();
        aavePM.updateHealthFactorTarget(value);
        vm.stopBroadcast();
    }

    function updateSTAavePM(uint16 value) public {
        setup();
        vm.startBroadcast();
        aavePM.updateSlippageTolerance(value);
        vm.stopBroadcast();
    }

    // ================================================================
    // │            FUNCTIONS - REBALANCE, DEPOSIT, WITHDRAW          │
    // ================================================================
    function rebalanceAavePM() public {
        setup();
        vm.startBroadcast();
        aavePM.rebalance();
        vm.stopBroadcast();
    }

    function reinvestAavePM() public {
        setup();
        vm.startBroadcast();
        aavePM.reinvest();
        vm.stopBroadcast();
    }

    function aaveSupplyAavePM() public {
        setup();
        vm.startBroadcast();
        aavePM.aaveSupplyFromContractBalance();
        vm.stopBroadcast();
    }

    function aaveRepayAavePM() public {
        setup();
        vm.startBroadcast();
        aavePM.aaveRepayUSDCFromContractBalance();
        vm.stopBroadcast();
    }

    function aaveDeleverageAavePM() public {
        setup();
        vm.startBroadcast();
        aavePM.deleverage();
        vm.stopBroadcast();
    }

    function aaveClosePositionAavePM() public {
        setup();
        vm.startBroadcast();
        aavePM.aaveClosePosition(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        vm.stopBroadcast();
    }

    function rescueETHAavePM() public {
        setup();
        vm.startBroadcast();
        aavePM.rescueEth(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        vm.stopBroadcast();
    }

    function withdrawTokenAavePM(string memory _identifier) public {
        setup();
        vm.startBroadcast();
        aavePM.withdrawTokensFromContractBalance(_identifier, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        vm.stopBroadcast();
    }

    function withdrawWstETHAavePM(uint256 value) public {
        setup();
        vm.startBroadcast();
        // TODO: Change this hardcoded Anvil address to an input parameter.
        aavePM.aaveWithdrawWstETH(value, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        vm.stopBroadcast();
    }

    function borrowAndWithdrawUSDCAavePM(uint256 value) public {
        setup();
        vm.startBroadcast();
        // TODO: Change this hardcoded Anvil address to an input parameter.
        aavePM.aaveBorrowAndWithdrawUSDC(value, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        vm.stopBroadcast();
    }

    // ================================================================
    // │                       FUNCTIONS - GETTERS                    │
    // ================================================================
    function getContractBalanceAavePM(string memory _identifier) public returns (uint256 contractBalance) {
        setup();
        vm.startBroadcast();
        contractBalance = aavePM.getContractBalance(_identifier);
        vm.stopBroadcast();
        return contractBalance;
    }

    function getAaveAccountDataAavePM()
        public
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        setup();
        vm.startBroadcast();
        address aavePoolAddress = aavePM.getContractAddress("aavePool");
        (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor) =
            IPool(aavePoolAddress).getUserAccountData(address(aavePM));
        vm.stopBroadcast();
        return
            (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor);
    }
}
