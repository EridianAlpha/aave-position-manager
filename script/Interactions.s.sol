// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";
import {AavePM} from "src/AavePM.sol";

contract Setup is Script {
    address public aavePMAddressProxy;
    AavePM public aavePM;

    constructor() {
        // TODO: Can all the .call functions use aavePM instead of aavePMAddressProxy?
        aavePMAddressProxy = getAavePMAddressProxy();
        aavePM = AavePM(payable(aavePMAddressProxy));
    }

    function getAavePMAddressProxy() internal view returns (address) {
        address _aavePMAddressProxy = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);
        require(_aavePMAddressProxy != address(0), "ERC1967Proxy address is invalid");
        return _aavePMAddressProxy;
    }
}

contract FundAavePM is Script, Setup {
    function run(uint256 value) public {
        vm.startBroadcast();
        (bool callSuccess,) = aavePMAddressProxy.call{value: value}("");
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
