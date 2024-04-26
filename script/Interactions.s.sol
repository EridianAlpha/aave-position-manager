// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";
import {AavePM} from "src/AavePM.sol";

contract Setup is Script {
    address public aavePMAddressProxy;
    AavePM public aavePM;

    constructor() {
        // TODO: Can all the .call functions use aavePM instead of aavePMAddressProxy?
        aavePMAddressProxy = getAavePMAddressProxy();
        aavePM = AavePM(payable(aavePMAddressProxy));
    }

    function getAavePMAddressProxy() internal view returns (address) {
        address _aavePMAddressProxy = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);
        require(_aavePMAddressProxy != address(0), "ERC1967Proxy address is invalid");
        return _aavePMAddressProxy;
    }
}

contract FundAavePM is Script, Setup {
    function run(uint256 value) public {
        vm.startBroadcast();
        (bool callSuccess,) = aavePMAddressProxy.call{value: value}("");
        if (!callSuccess) revert("Failed to send ETH to AavePM");
        vm.stopBroadcast();
    }
}

contract WrapETHToWETH is Script, Setup {
    function run() public {
        vm.startBroadcast();
        aavePM.wrapETHToWETH();
        vm.stopBroadcast();
    }
}

contract UnwrapWETHToETH is Script, Setup {
    function run() public {
        vm.startBroadcast();
        aavePM.unwrapWETHToETH();
        vm.stopBroadcast();
    }
}

contract SwapTokensAavePM is Script, Setup {
    function run(
        string memory _uniswapV3PoolIdentifier,
        string memory _tokenInIdentifier,
        string memory _tokenOutIdentifier
    ) public {
        vm.startBroadcast();
        aavePM.swapTokens(_uniswapV3PoolIdentifier, _tokenInIdentifier, _tokenOutIdentifier);
        vm.stopBroadcast();
    }
}

contract UpdateHFTAavePM is Script, Setup {
    function run(uint16 value) public {
        vm.startBroadcast();
        aavePM.updateHealthFactorTarget(value);
        vm.stopBroadcast();
    }
}

contract SupplyAavePM is Script, Setup {
    function run() public {
        vm.startBroadcast();
        aavePM.aaveSupplyWstETH();
        vm.stopBroadcast();
    }
}

contract BorrowAavePM is Script, Setup {
    function run(uint256 value) public {
        vm.startBroadcast();
        aavePM.aaveBorrowUSDC(value);
        vm.stopBroadcast();
    }
}

contract RebalanceAavePM is Script, Setup {
    function run() public {
        vm.startBroadcast();
        aavePM.rebalance();
        vm.stopBroadcast();
    }
}

contract GetContractBalanceAavePM is Script, Setup {
    function run(string memory _identifier) public returns (uint256 contractBalance) {
        vm.startBroadcast();
        contractBalance = aavePM.getContractBalance(_identifier);
        vm.stopBroadcast();
        return contractBalance;
    }
}

contract GetAaveAccountDataAavePM is Script, Setup {
    function run()
        public
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        vm.startBroadcast();
        (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor) =
            aavePM.getAaveAccountData();
        vm.stopBroadcast();
        return
            (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor);
    }
}

contract SetAaveStateAavePM is Script, Setup {
    function run(uint256 totalCollateralAwstETH, uint256 totalDebtBase) public {
        vm.startBroadcast();
        // TODO: Make 10 ether a parameter/variable
        (bool callSuccess,) = aavePMAddressProxy.call{value: 10 ether}("");
        if (!callSuccess) revert("Failed to send ETH to AavePM");
        aavePM.wrapETHToWETH();
        aavePM.swapTokens("wstETH/ETH", "ETH", "wstETH");
        aavePM.aaveSupplyWstETH();
        aavePM.aaveBorrowUSDC(totalDebtBase / 1e2);

        // Withdraw the extra collateral
        uint256 newtTotalCollateralAwstETH = aavePM.getContractBalance("awstETH");
        aavePM.aaveWithdrawWstETH(newtTotalCollateralAwstETH - totalCollateralAwstETH);

        // Send the extra tokens back to the user
        aavePM.swapTokens("wstETH/ETH", "wstETH", "ETH");
        aavePM.swapTokens("USDC/ETH", "USDC", "ETH");
        aavePM.unwrapWETHToETH();
        aavePM.rescueEth(msg.sender);
        vm.stopBroadcast();
    }
}
