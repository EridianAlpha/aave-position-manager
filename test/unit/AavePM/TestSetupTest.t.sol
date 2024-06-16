// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

import {AavePM} from "src/AavePM.sol";
import {IAavePM} from "src/interfaces/IAavePM.sol";

import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployAavePM} from "script/DeployAavePM.s.sol";
import {HelperFunctions} from "script/HelperFunctions.s.sol";

contract AavePMTestSetup is Test, HelperFunctions, AavePM {
    // Added to remove this whole testing file from coverage report.
    function test() public override {}

    AavePM aavePM;
    HelperConfig helperConfig;

    uint256 internal constant GAS_PRICE = 1;
    uint256 internal constant STARTING_BALANCE = 10 ether;
    uint256 internal constant SEND_VALUE = 1 ether;
    uint256 internal constant USDC_BORROW_AMOUNT = 100000000; // 100 USDC in 1e6 scale
    uint24 internal constant UNISWAPV3_POOL_FEE_CHANGE = 100;
    uint16 internal constant HEALTH_FACTOR_TARGET_CHANGE = 20;
    uint16 internal constant SLIPPAGE_TOLERANCE_CHANGE = 100;
    uint16 internal constant HEALTH_FACTOR_TOLERANCE = 2;
    string internal constant UPGRADE_EXAMPLE_VERSION = "9.9.9";

    // Create users
    address defaultFoundryCaller = address(uint160(uint256(keccak256("foundry default caller"))));
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

    function setUp() external {
        DeployAavePM deployAavePM = new DeployAavePM();

        // Stores the module addresses that are deployed and not contained in config
        IAavePM.ContractAddress[] memory contractAddresses;

        (aavePM, helperConfig, contractAddresses) = deployAavePM.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        // Call the _initialize function to set up this test contract,
        // initialized with the same config as the AavePM contract
        _initializeState(
            defaultFoundryCaller,
            contractAddresses,
            config.tokenAddresses,
            config.uniswapV3Pools,
            config.initialHealthFactorTarget,
            config.initialSlippageTolerance,
            config.initialManagerDailyInvocationLimit
        );

        // For this test contract, set manager1 as a manager, and address(this) as an owner and manager
        grantRole(keccak256("MANAGER_ROLE"), manager1);
        grantRole(keccak256("OWNER_ROLE"), owner1);
        grantRole(keccak256("MANAGER_ROLE"), address(this));
        grantRole(keccak256("OWNER_ROLE"), address(this));

        // Add the owner1 user as the new owner and manager for the AavePM contract
        aavePM.grantRole(keccak256("OWNER_ROLE"), owner1);
        aavePM.grantRole(keccak256("MANAGER_ROLE"), owner1);

        // Add the manager1 user as a manager for the AavePM contract
        aavePM.grantRole(keccak256("MANAGER_ROLE"), manager1);

        // Remove the test contract as a manager and then an owner for the AavePM contract
        // Order matters as you can't remove the manager role if you're not an owner
        aavePM.revokeRole(keccak256("MANAGER_ROLE"), address(this));
        aavePM.revokeRole(keccak256("OWNER_ROLE"), address(this));

        // Set the starting balance of this contract (which is the AavePMTestSetup contract) to zero
        // Then it can explicitly be sent funds when needed for testing
        vm.deal(address(this), 0);

        // Give all the users some starting balance
        vm.deal(owner1, STARTING_BALANCE);
        vm.deal(manager1, STARTING_BALANCE);
        vm.deal(attacker1, STARTING_BALANCE);

        WETH = IERC20(aavePM.getTokenAddress("WETH"));
        USDC = IERC20(aavePM.getTokenAddress("USDC"));
        wstETH = IERC20(aavePM.getTokenAddress("wstETH"));
        awstETH = IERC20(aavePM.getTokenAddress("awstETH"));

        encodedRevert_AccessControlUnauthorizedAccount_Owner = abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector, attacker1, keccak256("OWNER_ROLE")
        );

        encodedRevert_AccessControlUnauthorizedAccount_Manager = abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector, attacker1, keccak256("MANAGER_ROLE")
        );
    }

    function checkEndHealthFactor(address _address) public view {
        (,,,,, uint256 endHealthFactor) = IPool(aavePM.getContractAddress("aavePool")).getUserAccountData(_address);
        uint256 endHealthFactorScaled = endHealthFactor / 1e16;

        require(endHealthFactorScaled <= (aavePM.getHealthFactorTarget() + HEALTH_FACTOR_TOLERANCE));
        require(endHealthFactorScaled >= (aavePM.getHealthFactorTarget() - HEALTH_FACTOR_TOLERANCE));
    }
}
