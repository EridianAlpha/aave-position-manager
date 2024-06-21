// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ================================================================
// │                           IMPORTS                            │
// ================================================================

// Interface Imports
import {IAavePM} from "./interfaces/IAavePM.sol";

// ================================================================
// │                   FUNCTION CHECKS CONTRACT                   │
// ================================================================

/// @title Function Checks for the Aave Position Manager
/// @author EridianAlpha
/// @notice This contract contains the functions used inside AavePM modifiers.
contract FunctionChecks {
    /// @notice Check if the caller has the `OWNER_ROLE`.
    /// @dev This function checks if the caller has the `OWNER_ROLE` and reverts if it does not.
    /// @param _owner The address to check if it has the `OWNER_ROLE`.
    function _checkOwner(address _owner) internal view {
        if (!IAavePM(address(this)).hasRole(keccak256("OWNER_ROLE"), _owner)) {
            revert IAavePM.AavePM__AddressNotAnOwner();
        }
    }

    /// @notice Check if manager invocations are within the daily limit.
    /// @dev This function checks if the manager invocations are within the daily limit and reverts if the limit is reached.
    /// @param managerInvocations The array of manager invocations.
    function _checkManagerInvocationLimit(uint64[] memory managerInvocations) internal view {
        // If the array is smaller than getManagerDailyInvocationLimit, return
        if (managerInvocations.length < IAavePM(address(this)).getManagerDailyInvocationLimit()) return;

        // Check if all invocations are in the past 24 hours, starting by assuming they all are
        bool allInvocationsInPast24Hours = true;

        // If any are not in the past 24 hours, set allInvocationsInPast24Hours to false and revert
        for (uint256 i = 0; i < managerInvocations.length; i++) {
            if (managerInvocations[i] < (block.timestamp - 24 hours)) allInvocationsInPast24Hours = false;
        }
        if (allInvocationsInPast24Hours) revert IAavePM.AavePM__ManagerDailyInvocationLimitReached();
    }
}
