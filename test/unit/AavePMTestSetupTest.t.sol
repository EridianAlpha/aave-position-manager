// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AavePM} from "src/AavePM.sol";
import {IAavePM} from "src/interfaces/IAavePM.sol";

import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployAavePM} from "script/DeployAavePM.s.sol";

contract AavePMTestSetup is Test, AavePM {
    // Added to remove this whole testing file from coverage report.
    function test() public {}

    AavePM aavePM;
    HelperConfig helperConfig;

    uint256 internal constant GAS_PRICE = 1;
    uint256 internal constant STARTING_BALANCE = 10 ether;
    uint256 internal constant SEND_VALUE = 1 ether;
    uint256 internal constant USDC_BORROW_AMOUNT = 100;
    uint24 internal constant UNISWAPV3_POOL_FEE_CHANGE = 100;
    uint16 internal constant HEALTH_FACTOR_TARGET_CHANGE = 100;
    uint16 internal constant SLIPPAGE_TOLERANCE_CHANGE = 100;
    uint16 internal constant REBALANCED_HEALTH_FACTOR_TOLERANCE = 1;
    string internal constant UPGRADE_EXAMPLE_VERSION = "9.9.9";

    // Create users
    address owner1 = makeAddr("owner1");
    address manager1 = makeAddr("manager1");
    address attacker1 = makeAddr("attacker1");

    // Encoded reverts
    bytes encodedRevert_AccessControlUnauthorizedAccount_Owner;
    bytes encodedRevert_AccessControlUnauthorizedAccount_Manager;

    IERC20 WETH;
    IERC20 wstETH;
    IERC20 USDC;
    IERC20 awstETH;

    mapping(string => address) s_contractAddresses;
    mapping(string => address) s_tokenAddresses;
    mapping(string => IAavePM.UniswapV3Pool) private s_uniswapV3Pools;
    uint16 initialHealthFactorTarget;
    uint16 initialSlippageTolerance;

    function setUp() external {
        DeployAavePM deployAavePM = new DeployAavePM();

        (aavePM, helperConfig) = deployAavePM.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        IAavePM.ContractAddress[] memory contractAddresses = config.contractAddresses;
        IAavePM.TokenAddress[] memory tokenAddresses = config.tokenAddresses;
        IAavePM.UniswapV3Pool[] memory uniswapV3Pools = config.uniswapV3Pools;
        initialHealthFactorTarget = config.initialHealthFactorTarget;
        initialSlippageTolerance = config.initialSlippageTolerance;

        // Convert the contractAddresses array to a mapping
        for (uint256 i = 0; i < contractAddresses.length; i++) {
            s_contractAddresses[contractAddresses[i].identifier] = contractAddresses[i].contractAddress;
        }

        // Convert the tokenAddresses array to a mapping
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_tokenAddresses[tokenAddresses[i].identifier] = tokenAddresses[i].tokenAddress;
        }

        // Convert the uniswapV3Pools array to a mapping.
        for (uint256 i = 0; i < uniswapV3Pools.length; i++) {
            s_uniswapV3Pools[uniswapV3Pools[i].identifier] = IAavePM.UniswapV3Pool(
                uniswapV3Pools[i].identifier, uniswapV3Pools[i].poolAddress, uniswapV3Pools[i].fee
            );
        }

        // Add the owner1 user as the new owner and manager
        aavePM.grantRole(keccak256("OWNER_ROLE"), owner1);
        aavePM.grantRole(keccak256("MANAGER_ROLE"), owner1);

        // Add the manager1 user as a manager
        aavePM.grantRole(keccak256("MANAGER_ROLE"), manager1);

        // Remove the test contract as a manager and then an owner
        // Order matters as you can't remove the manager role if you're not an owner
        aavePM.revokeRole(keccak256("MANAGER_ROLE"), address(this));
        aavePM.revokeRole(keccak256("OWNER_ROLE"), address(this));

        vm.deal(owner1, STARTING_BALANCE);
        vm.deal(manager1, STARTING_BALANCE);
        vm.deal(attacker1, STARTING_BALANCE);

        WETH = IERC20(aavePM.getTokenAddress("WETH"));
        wstETH = IERC20(aavePM.getTokenAddress("wstETH"));
        USDC = IERC20(aavePM.getTokenAddress("USDC"));
        awstETH = IERC20(aavePM.getTokenAddress("awstETH"));

        encodedRevert_AccessControlUnauthorizedAccount_Owner = abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector, attacker1, keccak256("OWNER_ROLE")
        );

        encodedRevert_AccessControlUnauthorizedAccount_Manager = abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector, attacker1, keccak256("MANAGER_ROLE")
        );
    }
}
