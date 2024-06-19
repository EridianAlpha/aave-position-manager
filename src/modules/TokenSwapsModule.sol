// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ================================================================
// │                           IMPORTS                            │
// ================================================================

// Aave Imports
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// Uniswap Imports
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

// Interface Imports
import {IWETH9} from "../interfaces/IWETH9.sol";
import {IAavePM} from "../interfaces/IAavePM.sol";
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {ITokenSwapsModule} from "../interfaces/ITokenSwapsModule.sol";

// ================================================================
// │                  TokenSwapsModule CONTRACT                   │
// ================================================================

/// @notice // TODO: Add comment
contract TokenSwapsModule is ITokenSwapsModule {
    // ================================================================
    // │                         MODULE SETUP                         │
    // ================================================================

    /// @notice The version of the contract.
    /// @dev Contract is upgradeable so the version is a constant set on each implementation contract.
    string internal constant VERSION = "0.0.1";

    /// @notice Getter function to get the contract version.
    /// @dev Public function to allow anyone to view the contract version.
    /// @return version The contract version.
    function getVersion() public pure returns (string memory version) {
        return VERSION;
    }

    address public immutable aavePMProxyAddress;

    constructor(address _aavePMProxyAddress) {
        aavePMProxyAddress = _aavePMProxyAddress;
    }

    modifier onlyAavePM() {
        if (address(this) != aavePMProxyAddress) revert TokenSwapsModule__InvalidAavePMProxyAddress();
        _;
    }

    // ================================================================
    // │                       MODULE FUNCTIONS                       │
    // ================================================================

    /// @notice Swaps the contract's entire specified token balance using a UniswapV3 pool.
    /// @dev Calculates the minimum amount that should be received based on the current pool's price ratio and a predefined slippage tolerance.
    ///      Reverts if there are no tokens in the contract or if the transaction doesn't meet the `amountOutMinimum` criteria due to price movements.
    /// @param _uniswapV3PoolIdentifier The identifier of the UniswapV3 pool to use for the swap.
    /// @param _tokenInIdentifier The identifier of the token to swap.
    /// @param _tokenOutIdentifier The identifier of the token to receive from the swap.
    /// @return tokenOutIdentifier The identifier of the token received from the swap.
    /// @return amountOut The amount tokens received from the swap.
    function swapTokens(
        string memory _uniswapV3PoolIdentifier,
        string memory _tokenInIdentifier,
        string memory _tokenOutIdentifier
    ) public onlyAavePM returns (string memory tokenOutIdentifier, uint256 amountOut) {
        IAavePM aavePM = IAavePM(address(this));
        (address uniswapV3PoolAddress, uint24 uniswapV3PoolFee) = aavePM.getUniswapV3Pool(_uniswapV3PoolIdentifier);

        // If the input is ETH, wrap any ETH to WETH.
        if (_isIdentifierETH(_tokenInIdentifier) && aavePM.getContractBalance("ETH") > 0) {
            wrapETHToWETH();
        }

        // If ETH is input or output, convert the identifier to WETH.
        _tokenInIdentifier = _isIdentifierETH(_tokenInIdentifier) ? "WETH" : _tokenInIdentifier;
        _tokenOutIdentifier = _isIdentifierETH(_tokenOutIdentifier) ? "WETH" : _tokenOutIdentifier;

        // Get the token addresses from the identifiers.
        address tokenInAddress = aavePM.getTokenAddress(_tokenInIdentifier);
        address tokenOutAddress = aavePM.getTokenAddress(_tokenOutIdentifier);
        uint256 currentBalance = aavePM.getContractBalance(_tokenInIdentifier);

        // Prepare the swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenInAddress,
            tokenOut: tokenOutAddress,
            fee: uniswapV3PoolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: currentBalance,
            amountOutMinimum: uniswapV3CalculateMinOut(
                aavePM, currentBalance, uniswapV3PoolAddress, tokenInAddress, tokenOutAddress
            ),
            sqrtPriceLimitX96: 0 // TODO: Calculate price limit
        });

        // Approve the swapRouter to spend the tokenIn and swap the tokens.
        return (_tokenOutIdentifier, approveAndExecuteSwap(aavePM, params, currentBalance));
    }

    /// @notice // TODO: Add comment
    function approveAndExecuteSwap(
        IAavePM aavePM,
        ISwapRouter.ExactInputSingleParams memory params,
        uint256 currentBalance
    ) private returns (uint256 amountOut) {
        ISwapRouter swapRouter = ISwapRouter(aavePM.getContractAddress("uniswapV3Router"));

        TransferHelper.safeApprove(params.tokenIn, address(swapRouter), currentBalance);
        amountOut = swapRouter.exactInputSingle(params);
        return amountOut;
    }

    /// @notice // TODO: Add comment
    function wrapETHToWETH() public payable onlyAavePM {
        IWETH9(IAavePM(address(this)).getTokenAddress("WETH")).deposit{value: address(this).balance}();
    }

    // ================================================================
    // │                   FUNCTIONS - CALCULATIONS                   │
    // ================================================================

    /// @notice // TODO: Add comment
    function uniswapV3CalculateMinOut(
        IAavePM aavePM,
        uint256 _currentBalance,
        address _uniswapV3PoolAddress,
        address tokenInAddress,
        address tokenOutAddress
    ) private view returns (uint256 minOut) {
        IUniswapV3Pool pool = IUniswapV3Pool(_uniswapV3PoolAddress);

        // sqrtRatioX96 calculates the price of token1 in units of token0 (token1/token0)
        // so only token0 decimals are needed to calculate minOut.
        uint256 _token0Decimals =
            IERC20Extended(tokenInAddress == pool.token0() ? tokenInAddress : tokenOutAddress).decimals();

        // Fetch current ratio from the pool.
        (uint160 sqrtRatioX96,,,,,,) = pool.slot0();

        // Calculate the current ratio.
        uint256 currentRatio = uint256(sqrtRatioX96) * (uint256(sqrtRatioX96)) * (10 ** _token0Decimals) >> (96 * 2);

        uint256 expectedOut = (_currentBalance * (10 ** _token0Decimals)) / currentRatio;
        uint256 slippageTolerance = expectedOut / aavePM.getSlippageTolerance();
        return minOut = expectedOut - slippageTolerance;
    }

    /// @notice // TODO: Add comment
    function _isIdentifierETH(string memory identifier) private pure returns (bool) {
        return (keccak256(abi.encodePacked(identifier)) == keccak256(abi.encodePacked("ETH"))) ? true : false;
    }
}
