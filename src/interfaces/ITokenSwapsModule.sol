// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAavePM} from "./IAavePM.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/// @notice // TODO: Add comment
interface ITokenSwapsModule {
    function swapTokens(
        string memory _uniswapV3PoolIdentifier,
        string memory _tokenInIdentifier,
        string memory _tokenOutIdentifier
    ) external returns (string memory tokenOutIdentifier, uint256 amountOut);

    function approveAndExecuteSwap(
        IAavePM aavePM,
        ISwapRouter.ExactInputSingleParams memory params,
        uint256 currentBalance
    ) external returns (uint256 amountOut);

    function uniswapV3CalculateMinOut(
        IAavePM aavePM,
        uint256 _currentBalance,
        address _uniswapV3PoolAddress,
        address tokenInAddress,
        address tokenOutAddress
    ) external view returns (uint256 minOut);

    function _isIdentifierETH(string memory identifier) external pure returns (bool);
}
