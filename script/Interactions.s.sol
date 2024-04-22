// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";
import {AavePM} from "src/AavePM.sol";

contract Setup is Script {
    address public aavePMAddressProxy;

    constructor() {
        aavePMAddressProxy = getAavePMAddressProxy();
    }

    function getAavePMAddressProxy() internal view returns (address) {
        address _aavePMAddressProxy = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);
        require(_aavePMAddressProxy != address(0), "ERC1967Proxy address is invalid");
        return _aavePMAddressProxy;
    }
}

contract FundAavePM is Script, Setup {
    uint256 SEND_VALUE = 0.1 ether;

    function fundAavePM(address aavePMAddressProxy) public {
        vm.startBroadcast();
        (bool callSuccess,) = aavePMAddressProxy.call{value: SEND_VALUE}("");
        if (!callSuccess) revert("Failed to send ether to AavePM");
        vm.stopBroadcast();
    }

    function run() public {
        fundAavePM(aavePMAddressProxy);
    }
}
