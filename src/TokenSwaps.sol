// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ================================================================
// │                           IMPORTS                            │
// ================================================================

// Interface Imports
import {IAavePM} from "./interfaces/IAavePM.sol";

// ================================================================
// │                    TOKENSWAPS CONTRACT                       │
// ================================================================

/// @notice This contract is used for delegating calls to the module contract // TODO: Add comment
contract TokenSwaps {
    /// @notice Details commented on module contract.
    function _swapTokens(
        string memory _uniswapV3PoolIdentifier,
        string memory _tokenInIdentifier,
        string memory _tokenOutIdentifier
    ) internal returns (string memory tokenOutIdentifier, uint256 amountOut) {
        // Call logic on tokenSwapsAddress module contract.
        (bool success, bytes memory data) = IAavePM(address(this)).getContractAddress("tokenSwapsModule").delegatecall(
            abi.encodeWithSignature(
                "swapTokens(string,string,string)", _uniswapV3PoolIdentifier, _tokenInIdentifier, _tokenOutIdentifier
            )
        );
        if (!success) revert IAavePM.AavePM__DelegateCallFailed();
        (tokenOutIdentifier, amountOut) = abi.decode(data, (string, uint256));
    }
}
