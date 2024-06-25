// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAavePM} from "./IAavePM.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/// @title TokenSwapsModule interface
/// @notice This interface defines the essential structures and functions for the TokenSwapsModule contract.
interface ITokenSwapsModule {
    error TokenSwapsModule__InvalidAavePMProxyAddress();

    function VERSION() external pure returns (string memory version);
    function aavePMProxyAddress() external view returns (address aavePMProxyAddress);

    function swapTokens(
        string memory _uniswapV3PoolIdentifier,
        string memory _tokenInIdentifier,
        string memory _tokenOutIdentifier
    ) external returns (string memory tokenOutIdentifier, uint256 amountOut);

    function wrapETHToWETH() external payable;
}
