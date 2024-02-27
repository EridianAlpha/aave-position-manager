// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice This contract is used to test uups upgrade to an invalid contract
/// @dev The contact is not a valid upgradeable contract so the test should fail
contract InvalidUpgrade {
    // ================================================================
    // │                        STATE VARIABLES                       │
    // ================================================================
    // Addresses
    address private s_creator;
    address private s_aave;

    // Roles
    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 private constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // Values
    uint256 private version;
    uint256 private s_healthFactorTarget;
    uint256 private s_healthFactorMinimum;
}
