// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IAavePM} from "../src/interfaces/IAavePM.sol";

contract HelperConfig is Script {
    address public aaveAddress;
    address public uniswapV3RouterAddress;
    address public uniswapV3WstETHETHPoolAddress;
    address public wethAddress;
    address public wstETHAddress;
    address public usdcAddress;

    struct NetworkConfig {
        IAavePM.ContractAddress[] contractAddresses;
        IAavePM.TokenAddress[] tokenAddresses;
        IAavePM.UniswapV3Pool uniswapV3WstETHETHPool;
        uint256 initialHealthFactorTarget;
    }

    function getChainVariables() public {
        uint256 chainId = block.chainid;

        if (chainId == 1) {
            // Mainnet
            aaveAddress = vm.envAddress("MAINNET_ADDRESS_AAVE");
            uniswapV3RouterAddress = vm.envAddress("MAINNET_ADDRESS_UNISWAP_V3_ROUTER");
            uniswapV3WstETHETHPoolAddress = vm.envAddress("MAINNET_ADDRESS_UNISWAP_V3_WSTETH_ETH_POOL");
            wethAddress = vm.envAddress("MAINNET_ADDRESS_WETH");
            wstETHAddress = vm.envAddress("MAINNET_ADDRESS_WSTETH");
            usdcAddress = vm.envAddress("MAINNET_ADDRESS_USDC");
        } else if (chainId == 8453) {
            // Base
            aaveAddress = vm.envAddress("BASE_ADDRESS_AAVE");
            uniswapV3RouterAddress = vm.envAddress("BASE_ADDRESS_UNISWAP_V3_ROUTER");
            uniswapV3WstETHETHPoolAddress = vm.envAddress("BASE_ADDRESS_UNISWAP_V3_WSTETH_ETH_POOL");
            wethAddress = vm.envAddress("BASE_ADDRESS_WETH");
            wstETHAddress = vm.envAddress("BASE_ADDRESS_WSTETH");
            usdcAddress = vm.envAddress("BASE_ADDRESS_USDC");
        } else {
            revert(string(abi.encodePacked("Chain not supported: ", Strings.toString(block.chainid))));
        }
    }

    function getActiveNetworkConfig() public returns (NetworkConfig memory) {
        NetworkConfig memory activeNetworkConfig;

        getChainVariables();

        // Contract addresses
        IAavePM.ContractAddress[] memory contractAddresses = new IAavePM.ContractAddress[](2);
        contractAddresses[0] = IAavePM.ContractAddress("aave", aaveAddress);
        contractAddresses[1] = IAavePM.ContractAddress("uniswapV3Router", uniswapV3RouterAddress);

        // Token addresses
        IAavePM.TokenAddress[] memory tokenAddresses = new IAavePM.TokenAddress[](3);
        tokenAddresses[0] = IAavePM.TokenAddress("WETH9", wethAddress);
        tokenAddresses[1] = IAavePM.TokenAddress("wstETH", wstETHAddress);
        tokenAddresses[2] = IAavePM.TokenAddress("USDC", usdcAddress);

        activeNetworkConfig = NetworkConfig({
            contractAddresses: contractAddresses,
            tokenAddresses: tokenAddresses,
            uniswapV3WstETHETHPool: IAavePM.UniswapV3Pool({
                poolAddress: uniswapV3WstETHETHPoolAddress,
                fee: uint24(vm.envUint("INITIAL_UNISWAP_V3_WSTETH_POOL_FEE"))
            }),
            initialHealthFactorTarget: vm.envUint("INITIAL_HEALTH_FACTOR_TARGET")
        });

        return activeNetworkConfig;
    }
}
