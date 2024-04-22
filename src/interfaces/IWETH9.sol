// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IWETH9 Interface
/// @notice This interface enables the wrapping and unwrapping of ETH to WETH.
interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}
