// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../AavePM.sol";

/// @notice This contract is used to test the .call functions failing in AavePM.sol
/// @dev The test is found in AavePMTest.t.sol:
///      - "test_RescueEthCallFailureThrowsError()"
///      The reason this contract causes the .call to fail is because it doesn't have a receive()
///      or fallback() function so the ETH can't be accepted.
contract InvalidOwner {
    AavePM aavePM;

    constructor(address aavePMAddress) {
        aavePM = AavePM(payable(aavePMAddress));
    }

    function aavePMRescueAllETH() public payable {
        aavePM.rescueEth(address(this));
    }
}
