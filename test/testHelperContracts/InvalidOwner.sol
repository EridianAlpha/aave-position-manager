// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../src/AavePM.sol";

/// @notice This contract is used to test the .call functions failing in AavePM.sol
/// @dev The test is found in AavePMTest.t.sol:
///      - "test_RescueEthCallFailureThrowsError()"
///      This contract causes the .call to fail as it doesn't have a receive()
///      or fallback() function so the ETH can't be accepted.
contract InvalidOwner {}
