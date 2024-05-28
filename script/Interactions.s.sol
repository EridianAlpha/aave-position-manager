// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

contract Setup is Script {
    IAavePM public aavePM;

    constructor() {
        address _aavePMAddressProxy = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);
        require(_aavePMAddressProxy != address(0), "ERC1967Proxy address is invalid");
        aavePM = IAavePM(payable(_aavePMAddressProxy));
    }
}

contract FundAavePM is Script, Setup {
    function run(uint256 value) public {
        vm.startBroadcast();
        (bool callSuccess,) = address(aavePM).call{value: value}("");
        if (!callSuccess) revert("Failed to send ETH to AavePM");
        vm.stopBroadcast();
    }
}

contract UpdateHFTAavePM is Script, Setup {
    function run(uint16 value) public {
        vm.startBroadcast();
        aavePM.updateHealthFactorTarget(value);
        vm.stopBroadcast();
    }
}

contract RebalanceAavePM is Script, Setup {
    function run() public {
        vm.startBroadcast();
        aavePM.rebalance();
        vm.stopBroadcast();
    }
}

contract GetContractBalanceAavePM is Script, Setup {
    function run(string memory _identifier) public returns (uint256 contractBalance) {
        vm.startBroadcast();
        contractBalance = aavePM.getContractBalance(_identifier);
        vm.stopBroadcast();
        return contractBalance;
    }
}

contract GetAaveAccountDataAavePM is Script, Setup {
    function run()
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
        vm.startBroadcast();
        address aavePoolAddress = aavePM.getContractAddress("aavePool");
        (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor) =
            IPool(aavePoolAddress).getUserAccountData(address(aavePM));
        vm.stopBroadcast();
        return
            (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor);
    }
}
