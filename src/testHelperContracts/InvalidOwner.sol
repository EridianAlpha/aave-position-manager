// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../AavePM.sol";

/**
 * This contract is used to test the .call functions failing in AavePM.sol
 * The test is found in AavePMTest.t.sol:
 * - "test_RescueEthCallFailureThrowsError()"
 *
 * The reason this contract causes the .call to fail is because it doesn't have a receive()
 * or fallback() function so the ETH can't be accepted.
 */
contract InvalidOwner {
    AavePM aavePM;

    constructor(address aavePMAddress) {
        aavePM = AavePM(payable(aavePMAddress));
    }

    function aavePMRescueAllETH() public payable {
        aavePM.rescueEth(address(this));
    }

    function aavePMRescueEth() public payable {
        aavePM.rescueEth(address(this), address(aavePM).balance / 2);
    }
}
