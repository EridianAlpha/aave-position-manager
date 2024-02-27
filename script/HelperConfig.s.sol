// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address aave;
        address uniswapV3Router;
        address wstETH;
        address USDC;
        uint256 initialHealthFactorTarget;
        uint256 initialHealthFactorMinimum;
    }

    constructor() {
        if (block.chainid == 1) {
            activeNetworkConfig = NetworkConfig({
                aave: address(0),
                uniswapV3Router: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
                wstETH: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                USDC: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                initialHealthFactorTarget: 2,
                initialHealthFactorMinimum: 2
            });
        } else if (block.chainid == 31337) {
            // Anvil local network
            // Using Mainnet addresses for testing on a fork
            activeNetworkConfig = NetworkConfig({
                aave: address(0),
                uniswapV3Router: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
                wstETH: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                USDC: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                initialHealthFactorTarget: 2,
                initialHealthFactorMinimum: 2
            });
        }
    }
}
