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
    // │                            EVENTS                            │
    // ================================================================
    event EthRescued(address indexed to, uint256 amount);
    event AaveUpdated(address indexed previousAaveAddress, address indexed newAaveAddress);
    event HealthFactorTargetUpdated(uint256 previousHealthFactorTarget, uint256 newHealthFactorTarget);

    // ================================================================
    // │                           MODIFIERS                          │
    // ================================================================

    // ================================================================
    // │                           FUNCTIONS                          │
    // ================================================================

    // ================================================================
    // │                    FUNCTIONS - INITIALIZER                   │
    // ================================================================
    function initialize(address owner, uint256 initialHealthFactorTarget) external;

    // ================================================================
    // │                     FUNCTIONS - EXTERNAL                     │
    // ================================================================
    function updateAave(address _aave) external;
    function updateHealthFactorTarget(uint256 _healthFactorTarget) external;
    function rescueEth(address rescueAddress) external;
    function rescueEth(address rescueAddress, uint256 ethAmount) external;

    // ================================================================
    // │               FUNCTIONS - PRIVATE AND INTERNAL VIEW          │
    // ================================================================

    // ================================================================
    // │               FUNCTIONS - PUBLIC AND EXTERNAL VIEW           │
    // ================================================================
    function getCreator() external view returns (address);
    function getVersion() external view returns (uint256);
    function getOwnerRole() external pure returns (bytes32);
    function getManagerRole() external pure returns (bytes32);
    function getAave() external view returns (address);
    function getHealthFactorTarget() external view returns (uint256);
    function getHealthFactorMinimum() external view returns (uint256);
    function getRescueEthBalance() external view returns (uint256);
}
