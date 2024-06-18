// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAavePM} from "./IAavePM.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/// @notice // TODO: Add comment
interface ITokenSwapsModule {
    function getVersion() external pure returns (string memory version);
    function swapTokens(
        string memory _uniswapV3PoolIdentifier,
        string memory _tokenInIdentifier,
        string memory _tokenOutIdentifier
    ) external returns (string memory tokenOutIdentifier, uint256 amountOut);

    function wrapETHToWETH() external payable;
}
