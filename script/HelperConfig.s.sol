// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IAavePM} from "../src/interfaces/IAavePM.sol";

contract HelperConfig is Script {
    function test() public {} // Added to remove this whole contract from coverage report.

    address public aavePoolAddress;
    address public aaveOracleAddress;
    address public uniswapV3RouterAddress;
    address public uniswapV3WstETHETHPoolAddress;
    uint24 public uniswapV3WstETHETHPoolFee;
    address public uniswapV3USDCETHPoolAddress;
    uint24 public uniswapV3USDCETHPoolFee;
    address public wethAddress;
    address public wstETHAddress;
    address public usdcAddress;
    address public awstETHAddress;

    struct NetworkConfig {
        IAavePM.ContractAddress[] contractAddresses;
        IAavePM.TokenAddress[] tokenAddresses;
        IAavePM.UniswapV3Pool[] uniswapV3Pools;
        uint16 initialHealthFactorTarget;
        uint16 initialSlippageTolerance;
    }

    function getChainVariables() public {
        uint256 chainId = block.chainid;

        if (chainId == 1) {
            // Mainnet
            aavePoolAddress = vm.envAddress("MAINNET_ADDRESS_AAVE_POOL");
            aaveOracleAddress = vm.envAddress("MAINNET_ADDRESS_AAVE_ORACLE");
            uniswapV3RouterAddress = vm.envAddress("MAINNET_ADDRESS_UNISWAP_V3_ROUTER");
            uniswapV3WstETHETHPoolAddress = vm.envAddress("MAINNET_ADDRESS_UNISWAP_V3_WSTETH_ETH_POOL");
            uniswapV3WstETHETHPoolFee = uint24(vm.envUint("MAINNET_FEE_UNISWAP_V3_WSTETH_ETH_POOL"));
            uniswapV3USDCETHPoolAddress = vm.envAddress("MAINNET_ADDRESS_UNISWAP_V3_USDC_ETH_POOL");
            uniswapV3USDCETHPoolFee = uint24(vm.envUint("MAINNET_FEE_UNISWAP_V3_USDC_ETH_POOL"));
            wethAddress = vm.envAddress("MAINNET_ADDRESS_WETH");
            wstETHAddress = vm.envAddress("MAINNET_ADDRESS_WSTETH");
            usdcAddress = vm.envAddress("MAINNET_ADDRESS_USDC");
            awstETHAddress = vm.envAddress("MAINNET_ADDRESS_AWSTETH");
        } else if (chainId == 8453) {
            // Base
            aavePoolAddress = vm.envAddress("BASE_ADDRESS_AAVE_POOL");
            aaveOracleAddress = vm.envAddress("BASE_ADDRESS_AAVE_ORACLE");
            uniswapV3RouterAddress = vm.envAddress("BASE_ADDRESS_UNISWAP_V3_ROUTER");
            uniswapV3WstETHETHPoolAddress = vm.envAddress("BASE_ADDRESS_UNISWAP_V3_WSTETH_ETH_POOL");
            uniswapV3WstETHETHPoolFee = uint24(vm.envUint("BASE_FEE_UNISWAP_V3_WSTETH_ETH_POOL"));
            uniswapV3USDCETHPoolAddress = vm.envAddress("BASE_ADDRESS_UNISWAP_V3_USDC_ETH_POOL");
            uniswapV3USDCETHPoolFee = uint24(vm.envUint("BASE_FEE_UNISWAP_V3_USDC_ETH_POOL"));
            wethAddress = vm.envAddress("BASE_ADDRESS_WETH");
            wstETHAddress = vm.envAddress("BASE_ADDRESS_WSTETH");
            usdcAddress = vm.envAddress("BASE_ADDRESS_USDC");
            awstETHAddress = vm.envAddress("BASE_ADDRESS_AWSTETH");
        } else {
            revert(string(abi.encodePacked("Chain not supported: ", Strings.toString(block.chainid))));
        }
    }

    function getActiveNetworkConfig() public returns (NetworkConfig memory) {
        NetworkConfig memory activeNetworkConfig;

        getChainVariables();

        // Contract addresses
        IAavePM.ContractAddress[] memory contractAddresses = new IAavePM.ContractAddress[](3);
        contractAddresses[0] = IAavePM.ContractAddress("aavePool", aavePoolAddress);
        contractAddresses[1] = IAavePM.ContractAddress("aaveOracle", aaveOracleAddress);
        contractAddresses[2] = IAavePM.ContractAddress("uniswapV3Router", uniswapV3RouterAddress);

        // Token addresses
        IAavePM.TokenAddress[] memory tokenAddresses = new IAavePM.TokenAddress[](4);
        tokenAddresses[0] = IAavePM.TokenAddress("WETH", wethAddress);
        tokenAddresses[1] = IAavePM.TokenAddress("wstETH", wstETHAddress);
        tokenAddresses[2] = IAavePM.TokenAddress("USDC", usdcAddress);
        tokenAddresses[3] = IAavePM.TokenAddress("awstETH", awstETHAddress);

        // UniswapV3 pools
        IAavePM.UniswapV3Pool[] memory uniswapV3Pools = new IAavePM.UniswapV3Pool[](2);
        uniswapV3Pools[0] =
            IAavePM.UniswapV3Pool("wstETH/ETH", uniswapV3WstETHETHPoolAddress, uniswapV3WstETHETHPoolFee);
        uniswapV3Pools[1] = IAavePM.UniswapV3Pool("USDC/ETH", uniswapV3USDCETHPoolAddress, uniswapV3USDCETHPoolFee);

        activeNetworkConfig = NetworkConfig({
            contractAddresses: contractAddresses,
            tokenAddresses: tokenAddresses,
            uniswapV3Pools: uniswapV3Pools,
            initialHealthFactorTarget: uint16(vm.envUint("INITIAL_HEALTH_FACTOR_TARGET")),
            initialSlippageTolerance: uint16(vm.envUint("INITIAL_SLIPPAGE_TOLERANCE"))
        });

        return activeNetworkConfig;
    }
}
