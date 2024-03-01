// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {IAavePM} from "../src/interfaces/IAavePM.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        IAavePM.ContractAddress[] contractAddresses;
        IAavePM.TokenAddress[] tokenAddresses;
        address uniswapV3WstETHETHPoolAddress;
        uint24 uniswapV3WstETHETHPoolFee;
        uint256 initialHealthFactorTarget;
    }

    function getActiveNetworkConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory activeNetworkConfig;

        // Contract addresses
        IAavePM.ContractAddress[] memory contractAddresses = new IAavePM.ContractAddress[](3);
        contractAddresses[0] = IAavePM.ContractAddress("aave", address(0));
        contractAddresses[1] = IAavePM.ContractAddress("uniswapV3Router", 0xE592427A0AEce92De3Edee1F18E0157C05861564);

        // Token addresses
        IAavePM.TokenAddress[] memory tokenAddresses = new IAavePM.TokenAddress[](3);
        tokenAddresses[0] = IAavePM.TokenAddress("WETH9", 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        tokenAddresses[1] = IAavePM.TokenAddress("wstETH", 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        tokenAddresses[2] = IAavePM.TokenAddress("USDC", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        activeNetworkConfig = NetworkConfig({
            contractAddresses: contractAddresses,
            tokenAddresses: tokenAddresses,
            uniswapV3WstETHETHPoolAddress: 0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa, // 0.01%
            uniswapV3WstETHETHPoolFee: 100,
            initialHealthFactorTarget: 2
        });

        return activeNetworkConfig;
    }
}
