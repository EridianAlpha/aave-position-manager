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

/// @notice // TODO: Add comment
contract FunctionChecks {
    /// @notice // TODO: Add comment
    function _checkOwner(address _owner) internal view {
        if (!IAavePM(address(this)).hasRole(keccak256("OWNER_ROLE"), _owner)) {
            revert IAavePM.AavePM__AddressNotAnOwner();
        }
    }

    /// @notice // TODO: Add comment
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
