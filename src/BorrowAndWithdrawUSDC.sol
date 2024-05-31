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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ================================================================
// │                       ?? CONTRACT                     │
// ================================================================

/// @notice // TODO: Add comment
contract BorrowAndWithdrawUSDC is TokenSwaps, AaveFunctions {
    /// @notice // TODO: Add comment
    function _borrowAndWithdrawUSDC(uint256 borrowAmountUSDC, address _owner) internal {
        IAavePM aavePM = IAavePM(address(this));

        // Get data from state
        address aavePoolAddress = aavePM.getContractAddress("aavePool");
        address usdcAddress = aavePM.getTokenAddress("USDC");

        _aaveBorrow(aavePoolAddress, usdcAddress, borrowAmountUSDC);
        // TODO: Check the borrowed amount is the same as the requested amount.

        // TODO: Add check to make sure the borrow didn't move the HF below the target.
        IERC20(usdcAddress).transfer(_owner, borrowAmountUSDC);
    }
}
