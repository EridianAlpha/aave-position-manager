// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

import {AavePM} from "src/AavePM.sol";

import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// Import Modules
import {RebalanceModule} from "src/modules/RebalanceModule.sol";
import {ReinvestModule} from "src/modules/ReinvestModule.sol";
import {TokenSwapsModule} from "src/modules/TokenSwapsModule.sol";
import {AaveFunctionsModule} from "src/modules/AaveFunctionsModule.sol";
import {BorrowAndWithdrawUSDCModule} from "src/modules/BorrowAndWithdrawUSDCModule.sol";

// ================================================================
// │                             SETUP                            │
// ================================================================
contract Interactions is Script {
    // TODO: Write tests for this contract and remove the test function.
    function test() public {} // Added to remove this whole contract from coverage report.

    AavePM public aavePM;

    function interactionsSetup() public {
        address _aavePMAddressProxy;

        try vm.envAddress("DEPLOYED_CONTRACT_ADDRESS") returns (address addr) {
            if (addr != address(0)) {
                _aavePMAddressProxy = addr;
            } else {
                _aavePMAddressProxy = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);
            }
        } catch {
            _aavePMAddressProxy = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);
        }

        require(_aavePMAddressProxy != address(0), "ERC1967Proxy address is invalid");
        aavePM = AavePM(payable(_aavePMAddressProxy));
    }

    // ================================================================
    // │                             FUND                             │
    // ================================================================
    function fundAavePM(uint256 value) public {
        interactionsSetup();
        vm.startBroadcast();
        (bool callSuccess,) = address(aavePM).call{value: value}("");
        if (!callSuccess) revert("Failed to send ETH to AavePM");
        vm.stopBroadcast();
    }

    // ================================================================
    // │                            UPGRADE                           │
    // ================================================================
    function upgradeAavePM() public {
        interactionsSetup();
        vm.startBroadcast();
        AavePM newAavePM = new AavePM();
        aavePM.upgradeToAndCall(address(newAavePM), "");

        // Deploy updated modules
        aavePM.updateContractAddress("tokenSwapsModule", address(new TokenSwapsModule(address(aavePM))));
        aavePM.updateContractAddress("aaveFunctionsModule", address(new AaveFunctionsModule(address(aavePM))));
        aavePM.updateContractAddress(
            "borrowAndWithdrawUSDCModule", address(new BorrowAndWithdrawUSDCModule(address(aavePM)))
        );
        aavePM.updateContractAddress("rebalanceModule", address(new RebalanceModule(address(aavePM))));
        aavePM.updateContractAddress("reinvestModule", address(new ReinvestModule(address(aavePM))));
        vm.stopBroadcast();
    }

    // ================================================================
    // │                     FUNCTIONS - UPDATES                      │
    // ================================================================
    function updateHFTAavePM(uint16 value) public {
        interactionsSetup();
        vm.startBroadcast();
        aavePM.updateHealthFactorTarget(value);
        vm.stopBroadcast();
    }

    function updateSTAavePM(uint16 value) public {
        interactionsSetup();
        vm.startBroadcast();
        aavePM.updateSlippageTolerance(value);
        vm.stopBroadcast();
    }

    // ================================================================
    // │            FUNCTIONS - REBALANCE, DEPOSIT, WITHDRAW          │
    // ================================================================
    function rebalanceAavePM() public {
        interactionsSetup();
        vm.startBroadcast();
        aavePM.rebalance();
        vm.stopBroadcast();
    }

    function reinvestAavePM() public {
        interactionsSetup();
        vm.startBroadcast();
        aavePM.reinvest();
        vm.stopBroadcast();
    }

    function aaveSupplyAavePM() public {
        interactionsSetup();
        vm.startBroadcast();
        aavePM.aaveSupplyFromContractBalance();
        vm.stopBroadcast();
    }

    function aaveRepayAavePM() public {
        interactionsSetup();
        vm.startBroadcast();
        aavePM.aaveRepayUSDCFromContractBalance();
        vm.stopBroadcast();
    }

    function aaveDeleverageAavePM() public {
        interactionsSetup();
        vm.startBroadcast();
        aavePM.deleverage();
        vm.stopBroadcast();
    }

    function aaveClosePositionAavePM(address _owner) public {
        interactionsSetup();
        vm.startBroadcast();
        aavePM.aaveClosePosition(_owner);
        vm.stopBroadcast();
    }

    function rescueETHAavePM(address _owner) public {
        interactionsSetup();
        vm.startBroadcast();
        aavePM.rescueEth(_owner);
        vm.stopBroadcast();
    }

    function withdrawTokenAavePM(string memory _identifier, address _owner) public {
        interactionsSetup();
        vm.startBroadcast();
        aavePM.withdrawTokensFromContractBalance(_identifier, _owner);
        vm.stopBroadcast();
    }

    function withdrawWstETHAavePM(uint256 value, address _owner) public {
        interactionsSetup();
        vm.startBroadcast();
        aavePM.aaveWithdrawWstETH(value, _owner);
        vm.stopBroadcast();
    }

    function borrowAndWithdrawUSDCAavePM(uint256 value, address _owner) public {
        interactionsSetup();
        vm.startBroadcast();
        aavePM.aaveBorrowAndWithdrawUSDC(value, _owner);
        vm.stopBroadcast();
    }

    // ================================================================
    // │                       FUNCTIONS - GETTERS                    │
    // ================================================================
    function getContractBalanceAavePM(string memory _identifier) public returns (uint256 contractBalance) {
        interactionsSetup();
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
        interactionsSetup();
        vm.startBroadcast();
        address aavePoolAddress = aavePM.getContractAddress("aavePool");
        (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor) =
            IPool(aavePoolAddress).getUserAccountData(address(aavePM));
        vm.stopBroadcast();
        return
            (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor);
    }
}
