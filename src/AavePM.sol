// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import {IAavePM} from "./interfaces/IAavePM.sol";

/// @title AavePM - Aave Position Manager
/// @author EridianAlpha
/// @notice A contract to manage positions on Aave.

contract AavePM is IAavePM, Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    // ================================================================
    // │                        STATE VARIABLES                       │
    // ================================================================
    // Addresses
    address private s_creator; // Creator of the contract
    address private s_aave; // Aave contract address
    address private s_uniswapV3Router; // Uniswap V3 Router contract address
    address private s_wstETH; // Lido wrapped staked ETH contract address
    address private s_USDC; // Circle USDC contract address

    // Values
    uint256 private s_healthFactorTarget;
    uint256 private s_healthFactorMinimum;

    // ================================================================
    // │                           CONSTANTS                          │
    // ================================================================
    // Version
    string private constant VERSION = "0.0.1";

    // Roles
    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 private constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // Addresses
    address private constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Values
    uint24 private constant UNISWAPV3_WSTETH_ETH_POOL_FEE = 100; // 0.01%
    uint256 private constant UNISWAPV3_WSTETH_ETH_POOL_SLIPPAGE = 200; // 0.5%
    address private constant UNISWAPV3_WSTETH_ETH_POOL_ADDRESS = 0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa;

    // ================================================================
    // │                           MODIFIERS                          │
    // ================================================================

    // ================================================================
    // │                           FUNCTIONS                          │
    // ================================================================
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    fallback() external payable {
        revert AavePM__FunctionDoesNotExist();
    }

    // ================================================================
    // │                    FUNCTIONS - INITIALIZER                   │
    // ================================================================
    function initialize(
        address owner,
        address aave,
        address uniswapV3Router,
        address wstETH,
        address USDC,
        uint256 initialHealthFactorTarget
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        s_creator = msg.sender;

        _grantRole(OWNER_ROLE, owner);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);

        _grantRole(MANAGER_ROLE, owner);
        _setRoleAdmin(MANAGER_ROLE, OWNER_ROLE);

        s_aave = aave;
        s_uniswapV3Router = uniswapV3Router;
        s_wstETH = wstETH;
        s_USDC = USDC;

        s_healthFactorTarget = initialHealthFactorTarget;
        s_healthFactorMinimum = 2;
    }

    // ================================================================
    // │                   FUNCTIONS - UUPS UPGRADES                  │
    // ================================================================
    /// @notice Internal function to authorize an upgrade.
    /// @dev Only callable by the owner role.
    /// @param _newImplementation Address of the new contract implementation.
    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(OWNER_ROLE) {}

    // ================================================================
    // │                     FUNCTIONS - EXTERNAL                     │
    // ================================================================
    /// @notice Update the Aave contract address.
    /// @dev Only the contract owner can call this function.
    ///      Emits an AaveUpdated event.
    /// @param _aave The new Aave contract address.
    function updateAave(address _aave) external onlyRole(OWNER_ROLE) {
        emit AaveUpdated(s_aave, _aave);
        s_aave = _aave;
    }

    /// @notice Update the UniswapV3Router contract address.
    /// @dev Only the contract owner can call this function.
    ///      Emits an UniswapV3RouterUpdated event.
    /// @param _uniswapV3Router The new UniswapV3Router contract address.
    function updateUniswapV3Router(address _uniswapV3Router) external onlyRole(OWNER_ROLE) {
        emit UniswapV3RouterUpdated(s_uniswapV3Router, _uniswapV3Router);
        s_uniswapV3Router = _uniswapV3Router;
    }

    /// @notice Update the wstETH contract address.
    /// @dev Only the contract owner can call this function.
    ///      Emits an WstETHUpdated event.
    /// @param _wstETH The new wstETH contract address.
    function updateWstETH(address _wstETH) external onlyRole(OWNER_ROLE) {
        emit WstETHUpdated(s_wstETH, _wstETH);
        s_wstETH = _wstETH;
    }

    /// @notice Update the USDC contract address.
    /// @dev Only the contract owner can call this function.
    ///      Emits an USDCUpdated event.
    /// @param _USDC The new USDC contract address.
    function updateUSDC(address _USDC) external onlyRole(OWNER_ROLE) {
        emit USDCUpdated(s_USDC, _USDC);
        s_USDC = _USDC;
    }

    /// @notice Update the Health Factor target.
    /// @dev Only the contract owner can call this function.
    ///      Emits a HealthFactorTargetUpdated event.
    /// @param _healthFactorTarget The new Health Factor target.
    function updateHealthFactorTarget(uint256 _healthFactorTarget) external onlyRole(OWNER_ROLE) {
        // Should be different from the current healthFactorTarget
        if (s_healthFactorTarget == _healthFactorTarget) revert AavePM__HealthFactorUnchanged();

        // Must be greater than the s_healthFactorMinimum
        if (_healthFactorTarget < s_healthFactorMinimum) revert AavePM__HealthFactorBelowMinimum();

        emit HealthFactorTargetUpdated(s_healthFactorTarget, _healthFactorTarget);
        s_healthFactorTarget = _healthFactorTarget;
    }

    /// @notice Rescue ETH from the contract. Overloaded to allow rescuing
    ///         all or a specific amount.
    /// @dev This function is intended for emergency use.
    ///      In normal operation, the contract shouldn't hold ETH.
    ///      It can be called without an argument to rescue the entire balance
    ///      or with an amount in WEI to rescue a specific amount.
    ///      Only the contract owner can call this function.
    ///      The use of nonReentrant isn't required due to the owner-only restriction.
    ///      Throws `AavePM__RescueEthFailed` if the ETH transfer fails.
    ///      Emits a RescueEth event.
    /// @param rescueAddress The address to send the rescued ETH to.
    function rescueEth(address rescueAddress) external onlyRole(OWNER_ROLE) {
        // Check if the rescueAddress is an owner
        if (!hasRole(OWNER_ROLE, rescueAddress)) revert AavePM__RescueAddressNotAnOwner();

        // ***** TRANSFER ETH *****
        emit EthRescued(rescueAddress, getRescueEthBalance());
        (bool callSuccess,) = rescueAddress.call{value: getRescueEthBalance()}("");
        if (!callSuccess) revert AavePM__RescueEthFailed();
    }

    /// @notice Rescue a specific amount of ETH from the contract.
    /// @dev This function is an overload of rescueEth().
    ///      This variant allows specifying the amount of ETH to rescue in WEI.
    ///      Throws `AavePM__RescueEthFailed` if the ETH transfer fails.
    ///      Emits a RescueEth event.
    /// @param rescueAddress The address to send the rescued ETH to.
    ///                      Address must have the OWNER_ROLE.
    /// @param ethAmount The amount of ETH to rescue, specified in WEI.
    function rescueEth(address rescueAddress, uint256 ethAmount) external onlyRole(OWNER_ROLE) {
        // Check if the rescueAddress is an owner
        if (!hasRole(OWNER_ROLE, rescueAddress)) revert AavePM__RescueAddressNotAnOwner();

        // ***** TRANSFER ETH *****
        emit EthRescued(rescueAddress, ethAmount);
        (bool callSuccess,) = rescueAddress.call{value: ethAmount}("");
        if (!callSuccess) revert AavePM__RescueEthFailed();
    }

    // ================================================================
    // │                     FUNCTIONS - TOKEN SWAPS                  │
    // ================================================================
    // TODO: Public for testing, but could be internal in future?
    function convertETHToWstETH() public onlyRole(MANAGER_ROLE) returns (uint256 amountOut) {
        ISwapRouter swapRouter = ISwapRouter(s_uniswapV3Router);

        uint256 ethAmount = address(this).balance;
        require(ethAmount > 0, "No ETH available");

        // Calculate minimum output amount for the wstETH/ETH pool
        IUniswapV3Pool pool = IUniswapV3Pool(UNISWAPV3_WSTETH_ETH_POOL_ADDRESS);
        (uint160 sqrtRatioX96,,,,,,) = pool.slot0(); // Fetch current ratio from the pool
        uint256 currentRatio = uint256(sqrtRatioX96) * (uint256(sqrtRatioX96)) * (1e18) >> (96 * 2);
        uint256 expectedOut = (ethAmount * 1e18) / currentRatio;
        uint256 slippageTolerance = expectedOut / UNISWAPV3_WSTETH_ETH_POOL_SLIPPAGE;
        uint256 minOut = expectedOut - slippageTolerance;

        uint160 priceLimit = /* TODO: Calculate price limit */ 0;

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: WETH9,
            tokenOut: s_wstETH,
            fee: UNISWAPV3_WSTETH_ETH_POOL_FEE,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: ethAmount,
            amountOutMinimum: minOut,
            sqrtPriceLimitX96: priceLimit
        });

        amountOut = swapRouter.exactInputSingle{value: ethAmount}(params);
    }

    // ================================================================
    // │               FUNCTIONS - PRIVATE AND INTERNAL VIEW          │
    // ================================================================

    // ================================================================
    // │               FUNCTIONS - PUBLIC AND EXTERNAL VIEW           │
    // ================================================================
    /// @notice Getter function to get the i_creator address.
    /// @dev Public function to allow anyone to view the contract creator.
    /// @return address of the creator.
    function getCreator() public view returns (address) {
        return s_creator;
    }

    function getVersion() public pure returns (string memory) {
        return VERSION;
    }

    function getOwnerRole() public pure returns (bytes32) {
        return OWNER_ROLE;
    }

    function getManagerRole() public pure returns (bytes32) {
        return MANAGER_ROLE;
    }

    /// @notice Getter function to get the UniswapV3Router address.
    /// @dev Public function to allow anyone to view the UniswapV3Router contract address.
    /// @return address of the UniswapV3Router contract.
    function getUniswapV3Router() public view returns (address) {
        return s_uniswapV3Router;
    }

    /// @notice Getter function to get the Aave address.
    /// @dev Public function to allow anyone to view the Aave contract address.
    /// @return address of the Aave contract.
    function getAave() public view returns (address) {
        return s_aave;
    }

    /// @notice Getter function to get the wstETH address.
    /// @dev Public function to allow anyone to view the wstETH contract address.
    /// @return address of the wstETH contract.
    function getWstETH() public view returns (address) {
        return s_wstETH;
    }

    /// @notice Getter function to get the USDC address.
    /// @dev Public function to allow anyone to view the USDC contract address.
    /// @return address of the USDC contract.
    function getUSDC() public view returns (address) {
        return s_USDC;
    }

    /// @notice Getter function to get the Health Factor target.
    /// @dev Public function to allow anyone to view the Health Factor target value.
    /// @return uint256 of the Health Factor target.
    function getHealthFactorTarget() public view returns (uint256) {
        return s_healthFactorTarget;
    }

    /// @notice Getter function to get the Health Factor minimum.
    /// @dev Public function to allow anyone to view the Health Factor minimum value.
    /// @return uint256 of the Health Factor minimum.
    function getHealthFactorMinimum() public view returns (uint256) {
        return s_healthFactorMinimum;
    }

    /// @notice Getter function to get the contract's ETH balance.
    /// @dev Public function to allow anyone to view the contract's ETH balance.
    /// @return uint256 of the contract's ETH balance.
    function getRescueEthBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
