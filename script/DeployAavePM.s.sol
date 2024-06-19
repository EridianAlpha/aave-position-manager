// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AavePM} from "src/AavePM.sol";
import {IAavePM} from "src/interfaces/IAavePM.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

// Import Modules
import {RebalanceModule} from "src/modules/RebalanceModule.sol";
import {ReinvestModule} from "src/modules/ReinvestModule.sol";
import {TokenSwapsModule} from "src/modules/TokenSwapsModule.sol";
import {AaveFunctionsModule} from "src/modules/AaveFunctionsModule.sol";
import {BorrowAndWithdrawUSDCModule} from "src/modules/BorrowAndWithdrawUSDCModule.sol";

contract DeployAavePM is Script {
    function run() public returns (AavePM, HelperConfig, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        IAavePM.ContractAddress[] memory contractAddresses = config.contractAddresses;
        IAavePM.TokenAddress[] memory tokenAddresses = config.tokenAddresses;
        IAavePM.UniswapV3Pool[] memory uniswapV3Pools = config.uniswapV3Pools;
        uint16 initialHealthFactorTarget = config.initialHealthFactorTarget;
        uint16 initialSlippageTolerance = config.initialSlippageTolerance;
        uint16 initialManagerDailyInvocationLimit = config.initialManagerDailyInvocationLimit;

        // Specify the sender as msg.sender is needed for the test setup to work
        // but that does not change anything for real deployments
        vm.startBroadcast(msg.sender);

        // Deploy the implementation contract
        AavePM aavePMImplementation = new AavePM();

        // Encode the initializer function
        bytes memory initData = abi.encodeWithSelector(
            AavePM.initialize.selector,
            msg.sender,
            contractAddresses,
            tokenAddresses,
            uniswapV3Pools,
            initialHealthFactorTarget,
            initialSlippageTolerance,
            initialManagerDailyInvocationLimit
        );

        // Deploy the proxy pointing to the implementation
        ERC1967Proxy proxy = new ERC1967Proxy(address(aavePMImplementation), initData);
        AavePM aavePM = AavePM(payable(address(proxy)));

        // Deploy the module contracts and pass in the proxy address now it is deployed
        // so that only the proxy address can use the modules
        aavePM.updateContractAddress("tokenSwapsModule", address(new TokenSwapsModule(address(aavePM))));
        aavePM.updateContractAddress("aaveFunctionsModule", address(new AaveFunctionsModule(address(aavePM))));
        aavePM.updateContractAddress(
            "borrowAndWithdrawUSDCModule", address(new BorrowAndWithdrawUSDCModule(address(aavePM)))
        );
        aavePM.updateContractAddress("rebalanceModule", address(new RebalanceModule(address(aavePM))));
        aavePM.updateContractAddress("reinvestModule", address(new ReinvestModule(address(aavePM))));

        vm.stopBroadcast();
        return (aavePM, helperConfig, msg.sender);
    }
}
