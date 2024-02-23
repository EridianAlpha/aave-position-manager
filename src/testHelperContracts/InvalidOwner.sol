// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../AavePM.sol";

/**
 * This contract is used to test the .call functions failing in AavePM.sol
 * The test is found in AavePMTest.t.sol:
 * - "AavePMRescueEthTest"
 *
 * The reason this contract causes the .call to fail is because it doesn't have a receive()
 * or fallback() function so the ETH can't be accepted
 */
contract InvalidOwner {
    AavePM aavePMContract;

    constructor(address aavePMContractAddress) {
        aavePMContract = AavePM(payable(aavePMContractAddress));
    }

    function aavePMRescueAllETH() public payable {
        aavePMContract.rescueETH();
    }

    function aavePMRescueETH() public payable {
        aavePMContract.rescueETH(address(aavePMContract).balance / 2);
    }
}
