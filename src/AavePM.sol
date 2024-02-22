// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AavePM
 *  @author EridianAlpha
 *  @notice A contract to manage positions on Aave.
 */
contract AavePM is Ownable, ReentrancyGuard {
    // ================================================================
    // │                            ERRORS                            │
    // ================================================================
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

    fallback() external payable {}

    // ================================================================
    // │                     FUNCTIONS - EXTERNAL                     │
    // ================================================================
    /**
     *  @notice Function to rescue ETH in the contract.
     *  @dev This is a rescue function as in normal operation, the contract shouldn't
     *       contain any ETH since it should be automatically converted to wstETH.
     *  @dev nonReentrant isn't required, since only the owner can call this function.
     */
    function rescueETH() external onlyOwner nonReentrant {
        // ***** TRANSFER FUNDS *****
        (bool callSuccess,) = owner().call{value: getRescueETHBalance()}("");
        if (!callSuccess) revert AavePM__RescueETHFailed();
    }

    function rescueETH(uint256 ethAmount) external onlyOwner nonReentrant {
        // ***** TRANSFER FUNDS *****
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
     *  @notice Getter function to get the i_creator address.
     *  @dev Public function to allow anyone to view the contract creator.
     *  @return address of the creator.
     */
    function getCreator() public view returns (address) {
        return i_creator;
    }

    function getRescueETHBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
