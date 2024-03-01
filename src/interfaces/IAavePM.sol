// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title AavePM Interface
/// @notice This interface defines the essential structures and functions for the AavePM contract.
interface IAavePM {
    // ================================================================
    // │                            ERRORS                            │
    // ================================================================
    error AavePM__FunctionDoesNotExist();
    error AavePM__RescueEthFailed();
    error AavePM__RescueAddressNotAnOwner();
    error AavePM__HealthFactorUnchanged();
    error AavePM__HealthFactorBelowMinimum();

    // ================================================================
    // │                           STRUCTS                            │
    // ================================================================
    struct ContractAddress {
        string identifier;
        address contractAddress;
    }

    struct TokenAddress {
        string identifier;
        address tokenAddress;
    }

    struct UniswapV3Pool {
        // string identifier;
        address poolAddress;
        uint24 fee;
    }
    // ================================================================
    // │                            EVENTS                            │
    // ================================================================

    event EthRescued(address indexed to, uint256 amount);
    event AaveUpdated(address indexed previousAaveAddress, address indexed newAaveAddress);
    event UniswapV3RouterUpdated(
        address indexed previousUniswapV3RouterAddress, address indexed newUniswapV3RouterAddress
    );
    event WETH9Updated(address indexed previousWETH9Address, address indexed newWETH9Address);
    event WstETHUpdated(address indexed previousWstETHAddress, address indexed newWstETHAddress);
    event USDCUpdated(address indexed previousUSDCAddress, address indexed newUSDCAddress);
    event HealthFactorTargetUpdated(uint256 previousHealthFactorTarget, uint256 newHealthFactorTarget);

    // ================================================================
    // │                    FUNCTIONS - INITIALIZER                   │
    // ================================================================
    function initialize(
        address owner,
        address aave,
        address uniswapV3Router,
        address uniswapV3WstETHETHPoolAddress,
        uint24 uniswapV3WstETHETHPoolFee,
        // address WETH9,
        // address wstETH,
        // address USDC,
        TokenAddress[] memory tokenAddresses,
        uint256 initialHealthFactorTarget
    ) external;

    // ================================================================
    // │                     FUNCTIONS - UPDATES                     │
    // ================================================================
    function updateAave(address _aave) external;
    function updateUniswapV3Router(address _uniswapV3Router) external;
    function updateWETH9(address _WETH9) external;
    function updateWstETH(address _wstETH) external;
    function updateUSDC(address _USDC) external;
    function updateHealthFactorTarget(uint256 _healthFactorTarget) external;

    // ================================================================
    // │                        FUNCTIONS - ETH                       │
    // ================================================================
    function receiveEth() external payable; //TODO: Remove for production. Only used in development for testing.
    function rescueEth(address rescueAddress) external;

    // ================================================================
    // │                     FUNCTIONS - TOKEN SWAPS                  │
    // ================================================================
    function swapETHToWstETH() external returns (uint256 amountOut);

    // ================================================================
    // │                       FUNCTIONS - GETTERS                    │
    // ================================================================
    function getCreator() external view returns (address);
    function getVersion() external pure returns (string memory);
    function getOwnerRole() external pure returns (bytes32);
    function getManagerRole() external pure returns (bytes32);
    function getAave() external view returns (address);
    function getUniswapV3Router() external view returns (address);
    function getWETH9() external view returns (address);
    function getWstETH() external view returns (address);
    function getUSDC() external view returns (address);
    function getHealthFactorTarget() external view returns (uint256);
    function getHealthFactorMinimum() external view returns (uint256);
    function getRescueEthBalance() external view returns (uint256);
}
