// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// TODO: Decide if this is needed or just use AccessControl with an owner role
//import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// TODO: Decide if/where reentrancy guard is needed
// import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AavePM - Aave Position Manager
 * @author EridianAlpha
 * @notice A contract to manage positions on Aave.
 */
contract AavePM is AccessControl {
    // ================================================================
    // │                            ERRORS                            │
    // ================================================================
    error AavePM__FunctionDoesNotExist();
    error AavePM__RescueETHFailed();

    // ================================================================
    // │                             TYPES                            │
    // ================================================================

    // ================================================================
    // │                        STATE VARIABLES                       │
    // ================================================================
    address immutable i_creator;
    address private manager;
    address private aave;

    // Roles
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

    uint256 healthFactorTarget;

    // ================================================================
    // │                            EVENTS                            │
    // ================================================================
    event RescueETH(address indexed to, uint256 amount);
    event AaveUpdated(address indexed previousAaveAddress, address indexed newAaveAddress);

    // ================================================================
    // │                           MODIFIERS                          │
    // ================================================================

    // ================================================================
    // │                           FUNCTIONS                          │
    // ================================================================
    constructor(address owner) {
        i_creator = msg.sender;
        _grantRole(OWNER_ROLE, owner);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);

        _grantRole(MANAGER_ROLE, owner);
        _setRoleAdmin(MANAGER_ROLE, OWNER_ROLE);

        _grantRole(WITHDRAWER_ROLE, owner);
        _setRoleAdmin(WITHDRAWER_ROLE, OWNER_ROLE);
    }

    receive() external payable {}

    fallback() external payable {
        revert AavePM__FunctionDoesNotExist();
    }

    // ================================================================
    // │                     FUNCTIONS - EXTERNAL                     │
    // ================================================================
    /**
     * @notice Update the Aave contract address.
     * @dev Only the contract owner can call this function.
     *      Emits an AaveUpdated event.
     * @param _aave The new Aave contract address.
     */
    function updateAave(address _aave) external onlyRole(OWNER_ROLE) {
        emit AaveUpdated(aave, _aave);
        aave = _aave;
    }

    /**
     * @notice Rescue ETH from the contract. Overloaded to allow rescuing
     *         all or a specific amount.
     * @dev This function is intended for emergency use.
     *      In normal operation, the contract shouldn't hold ETH.
     *      It can be called without an argument to rescue the entire balance
     *      or with an amount in WEI to rescue a specific amount.
     *      Only the contract owner can call this function.
     *      The use of nonReentrant isn't required due to the owner-only restriction.
     *      Throws `AavePM__RescueETHFailed` if the ETH transfer fails.
     *      Emits a RescueETH event.
     * @param rescueAddress The address to send the rescued ETH to.
     */
    function rescueETH(address rescueAddress) external onlyRole(WITHDRAWER_ROLE) {
        // ***** TRANSFER ETH *****
        emit RescueETH(rescueAddress, getRescueETHBalance());
        (bool callSuccess,) = rescueAddress.call{value: getRescueETHBalance()}("");
        if (!callSuccess) revert AavePM__RescueETHFailed();
    }

    /**
     * @notice Rescue a specific amount of ETH from the contract.
     * @dev This function is an overload of rescueETH().
     *      This variant allows specifying the amount of ETH to rescue in WEI.
     *      Throws `AavePM__RescueETHFailed` if the ETH transfer fails.
     *      Emits a RescueETH event.
     * @param rescueAddress The address to send the rescued ETH to.
     * @param ethAmount The amount of ETH to rescue, specified in WEI.
     */
    function rescueETH(address rescueAddress, uint256 ethAmount) external onlyRole(WITHDRAWER_ROLE) {
        // ***** TRANSFER ETH *****
        emit RescueETH(rescueAddress, ethAmount);
        (bool callSuccess,) = rescueAddress.call{value: ethAmount}("");
        if (!callSuccess) revert AavePM__RescueETHFailed();
    }

    // ================================================================
    // │               FUNCTIONS - PRIVATE AND INTERNAL VIEW          │
    // ================================================================

    // ================================================================
    // │               FUNCTIONS - PUBLIC AND EXTERNAL VIEW           │
    // ================================================================
    /**
     * @notice Getter function to get the i_creator address.
     * @dev Public function to allow anyone to view the contract creator.
     * @return address of the creator.
     */
    function getCreator() public view returns (address) {
        return i_creator;
    }

    /**
     * @notice Getter function to get the Aave address.
     * @dev Public function to allow anyone to view the Aave contract address.
     * @return address of the manager.
     */
    function getAave() public view returns (address) {
        return aave;
    }

    /**
     * @notice Getter function to get the contract's ETH balance.
     * @dev Public function to allow anyone to view the contract's ETH balance.
     * @return uint256 of the contract's ETH balance.
     */
    function getRescueETHBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
