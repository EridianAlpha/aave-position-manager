// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ERC20Extended Interface
/// @notice This interface extends the ERC20 interface with the decimals function.
interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}
