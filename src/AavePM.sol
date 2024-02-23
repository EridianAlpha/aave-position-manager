// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AavePM - Aave Position Manager
 * @author EridianAlpha
 * @notice A contract to manage positions on Aave.
 */
contract AavePM is Ownable, ReentrancyGuard {
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
    address manager;
    address aave;

    uint256 healthFactorTarget;

    // ================================================================
    // │                            EVENTS                            │
    // ================================================================

    // ================================================================
    // │                           MODIFIERS                          │
    // ================================================================

    // ================================================================
    // │                           FUNCTIONS                          │
    // ================================================================
    constructor(address owner) Ownable(owner) {
        i_creator = msg.sender;
    }

    receive() external payable {}

    fallback() external payable {
        revert AavePM__FunctionDoesNotExist();
    }

    // ================================================================
    // │                     FUNCTIONS - EXTERNAL                     │
    // ================================================================
    /**
     * @notice Rescue ETH from the contract. Overloaded to allow rescuing all or a specific amount.
     * @dev This function is intended for emergency use. In normal operation, the contract shouldn't hold ETH.
     *      It can be called without an argument to rescue the entire balance or with an amount in WEI to rescue a specific amount.
     *      Only the contract owner can call this function. The use of nonReentrant isn't required due to the owner-only restriction.
     *      Throws `AavePM__RescueETHFailed` if the ETH transfer fails.
     */
    function rescueETH() external onlyOwner {
        // ***** TRANSFER ETH *****
        (bool callSuccess,) = owner().call{value: getRescueETHBalance()}("");
        if (!callSuccess) revert AavePM__RescueETHFailed();
    }

    /**
     * @notice Rescue a specific amount of ETH from the contract.
     * @dev This function is an overload of rescueETH(). Refer to the other overload for more details.
     *      This variant allows specifying the amount of ETH to rescue in WEI.
     *      Throws `AavePM__RescueETHFailed` if the ETH transfer fails.
     * @param ethAmount The amount of ETH to rescue, specified in WEI.
     */
    function rescueETH(uint256 ethAmount) external onlyOwner {
        // ***** TRANSFER ETH *****
        (bool callSuccess,) = owner().call{value: ethAmount}("");
        if (!callSuccess) revert AavePM__RescueETHFailed();
    }

    // Change Aave contract address

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
     * @notice Getter function to get the contract's ETH balance.
     * @dev Public function to allow anyone to view the contract's ETH balance.
     * @return uint256 of the contract's ETH balance.
     */
    function getRescueETHBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
