// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IAavePM} from "./interfaces/IAavePM.sol";

/// @title AavePM - Aave Position Manager
/// @author EridianAlpha
/// @notice A contract to manage positions on Aave.

contract AavePM is IAavePM, Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    // ================================================================
    // │                        STATE VARIABLES                       │
    // ================================================================
    // Addresses
    address private s_creator;
    address private s_aave;

    // Values
    uint256 private s_healthFactorTarget;
    uint256 private s_healthFactorMinimum;

    // ================================================================
    // │                           CONSTANTS                          │
    // ================================================================
    // Version
    string private constant VERSION = "0.0.1";

    // Roles
    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 private constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // ================================================================
    // │                           MODIFIERS                          │
    // ================================================================

    // ================================================================
    // │                           FUNCTIONS                          │
    // ================================================================
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    fallback() external payable {
        revert AavePM__FunctionDoesNotExist();
    }

    // ================================================================
    // │                    FUNCTIONS - INITIALIZER                   │
    // ================================================================
    function initialize(address owner, uint256 initialHealthFactorTarget) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        // version = 1;
        s_creator = msg.sender;

        _grantRole(OWNER_ROLE, owner);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);

        _grantRole(MANAGER_ROLE, owner);
        _setRoleAdmin(MANAGER_ROLE, OWNER_ROLE);

        s_healthFactorTarget = initialHealthFactorTarget;
        s_healthFactorMinimum = 2;
    }

    // ================================================================
    // │                   FUNCTIONS - UUPS UPGRADES                  │
    // ================================================================
    /// @notice Internal function to authorize an upgrade.
    /// @dev Only callable by the owner role.
    /// @param _newImplementation Address of the new contract implementation.
    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(OWNER_ROLE) {}

    // ================================================================
    // │                     FUNCTIONS - EXTERNAL                     │
    // ================================================================

    /// @notice Update the Aave contract address.
    /// @dev Only the contract owner can call this function.
    ///      Emits an AaveUpdated event.
    /// @param _aave The new Aave contract address.
    function updateAave(address _aave) external onlyRole(OWNER_ROLE) {
        emit AaveUpdated(s_aave, _aave);
        s_aave = _aave;
    }

    /// @notice Update the Health Factor target.
    /// @dev Only the contract owner can call this function.
    ///      Emits a HealthFactorTargetUpdated event.
    /// @param _healthFactorTarget The new Health Factor target.
    function updateHealthFactorTarget(uint256 _healthFactorTarget) external onlyRole(OWNER_ROLE) {
        // Should be different from the current healthFactorTarget
        if (s_healthFactorTarget == _healthFactorTarget) revert AavePM__HealthFactorUnchanged();

        // Must be greater than the s_healthFactorMinimum
        if (_healthFactorTarget < s_healthFactorMinimum) revert AavePM__HealthFactorBelowMinimum();

        emit HealthFactorTargetUpdated(s_healthFactorTarget, _healthFactorTarget);
        s_healthFactorTarget = _healthFactorTarget;
    }

    /// @notice Rescue ETH from the contract. Overloaded to allow rescuing
    ///         all or a specific amount.
    /// @dev This function is intended for emergency use.
    ///      In normal operation, the contract shouldn't hold ETH.
    ///      It can be called without an argument to rescue the entire balance
    ///      or with an amount in WEI to rescue a specific amount.
    ///      Only the contract owner can call this function.
    ///      The use of nonReentrant isn't required due to the owner-only restriction.
    ///      Throws `AavePM__RescueEthFailed` if the ETH transfer fails.
    ///      Emits a RescueEth event.
    /// @param rescueAddress The address to send the rescued ETH to.
    function rescueEth(address rescueAddress) external onlyRole(OWNER_ROLE) {
        // Check if the rescueAddress is an owner
        if (!hasRole(OWNER_ROLE, rescueAddress)) revert AavePM__RescueAddressNotAnOwner();

        // ***** TRANSFER ETH *****
        emit EthRescued(rescueAddress, getRescueEthBalance());
        (bool callSuccess,) = rescueAddress.call{value: getRescueEthBalance()}("");
        if (!callSuccess) revert AavePM__RescueEthFailed();
    }

    /// @notice Rescue a specific amount of ETH from the contract.
    /// @dev This function is an overload of rescueEth().
    ///      This variant allows specifying the amount of ETH to rescue in WEI.
    ///      Throws `AavePM__RescueEthFailed` if the ETH transfer fails.
    ///      Emits a RescueEth event.
    /// @param rescueAddress The address to send the rescued ETH to.
    ///                      Address must have the OWNER_ROLE.
    /// @param ethAmount The amount of ETH to rescue, specified in WEI.
    function rescueEth(address rescueAddress, uint256 ethAmount) external onlyRole(OWNER_ROLE) {
        // Check if the rescueAddress is an owner
        if (!hasRole(OWNER_ROLE, rescueAddress)) revert AavePM__RescueAddressNotAnOwner();

        // ***** TRANSFER ETH *****
        emit EthRescued(rescueAddress, ethAmount);
        (bool callSuccess,) = rescueAddress.call{value: ethAmount}("");
        if (!callSuccess) revert AavePM__RescueEthFailed();
    }

    // ================================================================
    // │               FUNCTIONS - PRIVATE AND INTERNAL VIEW          │
    // ================================================================

    // ================================================================
    // │               FUNCTIONS - PUBLIC AND EXTERNAL VIEW           │
    // ================================================================
    /// @notice Getter function to get the i_creator address.
    /// @dev Public function to allow anyone to view the contract creator.
    /// @return address of the creator.
    function getCreator() public view returns (address) {
        return s_creator;
    }

    function getVersion() public pure returns (string memory) {
        return VERSION;
    }

    function getOwnerRole() public pure returns (bytes32) {
        return OWNER_ROLE;
    }

    function getManagerRole() public pure returns (bytes32) {
        return MANAGER_ROLE;
    }

    /// @notice Getter function to get the Aave address.
    /// @dev Public function to allow anyone to view the Aave contract address.
    /// @return address of the Aave contract.
    function getAave() public view returns (address) {
        return s_aave;
    }

    /// @notice Getter function to get the Health Factor target.
    /// @dev Public function to allow anyone to view the Health Factor target value.
    /// @return uint256 of the Health Factor target.
    function getHealthFactorTarget() public view returns (uint256) {
        return s_healthFactorTarget;
    }

    /// @notice Getter function to get the Health Factor minimum.
    /// @dev Public function to allow anyone to view the Health Factor minimum value.
    /// @return uint256 of the Health Factor minimum.
    function getHealthFactorMinimum() public view returns (uint256) {
        return s_healthFactorMinimum;
    }

    /// @notice Getter function to get the contract's ETH balance.
    /// @dev Public function to allow anyone to view the contract's ETH balance.
    /// @return uint256 of the contract's ETH balance.
    function getRescueEthBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
