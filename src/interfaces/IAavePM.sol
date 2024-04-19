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
    event ContractAddressUpdated(
        string indexed identifier, address indexed previousContractAddress, address indexed newContractAddress
    );
    event TokenAddressUpdated(
        string indexed identifier, address indexed previousTokenAddress, address indexed newTokenAddress
    );
    event HealthFactorTargetUpdated(uint256 previousHealthFactorTarget, uint256 newHealthFactorTarget);

    // ================================================================
    // │                    FUNCTIONS - INITIALIZER                   │
    // ================================================================
    function initialize(
        address owner,
        ContractAddress[] memory contractAddresses,
        TokenAddress[] memory tokenAddresses,
        address uniswapV3WstETHETHPoolAddress,
        uint24 uniswapV3WstETHETHPoolFee,
        uint256 initialHealthFactorTarget
    ) external;

    // ================================================================
    // │                     FUNCTIONS - UPDATES                     │
    // ================================================================
    function updateContractAddress(string memory identifier, address _newContractAddress) external;
    function updateTokenAddress(string memory identifier, address _newTokenAddress) external;
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
    function getRoleHash(string memory) external pure returns (bytes32);
    function getContractAddress(string memory) external view returns (address);
    function getTokenAddress(string memory) external view returns (address);
    function getHealthFactorTarget() external view returns (uint256);
    function getHealthFactorMinimum() external view returns (uint256);
    function getRescueEthBalance() external view returns (uint256);
}
