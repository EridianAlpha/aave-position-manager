// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ================================================================
// │                           IMPORTS                            │
// ================================================================

// Inherited Contract Imports
import {TokenSwaps} from "./TokenSwaps.sol";
import {AaveFunctions} from "./AaveFunctions.sol";

// Aave Imports
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// Interface Imports
import {IAavePM} from "./interfaces/IAavePM.sol";

// ================================================================
// │                   FUNCTION CHECKS CONTRACT                   │
// ================================================================

/// @notice // TODO: Add comment
contract FunctionChecks {
    /// @notice // TODO: Add comment
    function _checkOwner(address _owner) internal view {
        IAavePM aavePM = IAavePM(address(this));
        if (!aavePM.hasRole(keccak256("OWNER_ROLE"), _owner)) revert IAavePM.AavePM__AddressNotAnOwner();
    }

    /// @notice // TODO: Add comment
    function _checkManagerInvocationLimit(uint64[] memory managerInvocations) internal view {
        IAavePM aavePM = IAavePM(address(this));

        // If the array is smaller than getManagerDailyInvocationLimit, return
        if (managerInvocations.length < aavePM.getManagerDailyInvocationLimit()) return;

        uint256 cutoff = block.timestamp - 24 hours;

        // Check if all invocations are in the past 24 hours, starting by assuming they all are
        bool allInvocationsInPast24Hours = true;

        // If any are not in the past 24 hours, set allInvocationsInPast24Hours to false and revert
        for (uint256 i = 0; i < managerInvocations.length; i++) {
            if (managerInvocations[i] < cutoff) allInvocationsInPast24Hours = false;
        }
        if (allInvocationsInPast24Hours) revert IAavePM.AavePM__ManagerDailyInvocationLimitReached();
    }
}
