// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

import {IAavePM} from "./interfaces/IAavePM.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {IERC20Extended} from "./interfaces/IERC20Extended.sol";

/// @title AavePM - Aave Position Manager
/// @author EridianAlpha
/// @notice A contract to manage positions on Aave.
contract AavePM is IAavePM, Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    // ================================================================
    // │                        STATE VARIABLES                       │
    // ================================================================

    // Addresses
    address private s_creator; // Creator of the contract
    mapping(string => address) private s_contractAddresses;
    mapping(string => address) private s_tokenAddresses;
    mapping(string => UniswapV3Pool) private s_uniswapV3Pools;

    // Values
    uint16 private s_healthFactorTarget;
    uint16 private s_slippageTolerance;

    // ================================================================
    // │                           CONSTANTS                          │
    // ================================================================

    /// @notice The version of the contract.
    /// @dev Contract is upgradeable so the version is a constant set on each implementation contract.
    string private constant VERSION = "0.0.1";

    /// @notice The role hashes for the contract.
    /// @dev Two independent roles are defined: `OWNER_ROLE` and `MANAGER_ROLE`.
    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 private constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice The minimum Health Factor target.
    /// @dev The value is hardcoded in the contract to prevent the position from
    ///      being liquidated cause by accidentally setting a low target.
    ///      A contract upgrade is required to change this value.
    uint16 private constant HEALTH_FACTOR_TARGET_MINIMUM = 200;

    // ================================================================
    // │                           MODIFIERS                          │
    // ================================================================

    // ================================================================
    // │           FUNCTIONS - CONSTRUCTOR, RECEIVE, FALLBACK         │
    // ================================================================

    /// @notice Constructor implemented but unused.
    /// @dev Contract is upgradeable and therefore the constructor is not used.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice // TODO
    receive() external payable {}

    /// @notice // TODO
    fallback() external payable {
        revert AavePM__FunctionDoesNotExist();
    }

    // ================================================================
    // │                    FUNCTIONS - INITIALIZER                   │
    // ================================================================

    /// @notice Initializes contract with the owner and relevant addresses and parameters for operation.
    /// @dev This function sets up all necessary state variables for the contract and can only be called once due to the `initializer` modifier.
    /// @param owner The address of the owner of the contract.
    /// @param contractAddresses An array of `ContractAddress` structures containing addresses of related contracts.
    /// @param tokenAddresses An array of `TokenAddress` structures containing addresses of relevant ERC-20 tokens.
    /// @param uniswapV3Pools An array of `UniswapV3Pool` structures containing the address and fee of the UniswapV3 pools.
    /// @param initialHealthFactorTarget The initial target health factor, used to manage risk.
    function initialize(
        address owner,
        ContractAddress[] memory contractAddresses,
        TokenAddress[] memory tokenAddresses,
        UniswapV3Pool[] memory uniswapV3Pools,
        uint16 initialHealthFactorTarget,
        uint16 initialSlippageTolerance
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        s_creator = msg.sender;

        _grantRole(OWNER_ROLE, owner);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);

        _grantRole(MANAGER_ROLE, owner);
        _setRoleAdmin(MANAGER_ROLE, OWNER_ROLE);

        // Convert the contractAddresses array to a mapping.
        for (uint256 i = 0; i < contractAddresses.length; i++) {
            s_contractAddresses[contractAddresses[i].identifier] = contractAddresses[i].contractAddress;
        }

        // Convert the tokenAddresses array to a mapping.
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_tokenAddresses[tokenAddresses[i].identifier] = tokenAddresses[i].tokenAddress;
        }

        // Convert the uniswapV3Pools array to a mapping.
        for (uint256 i = 0; i < uniswapV3Pools.length; i++) {
            s_uniswapV3Pools[uniswapV3Pools[i].identifier] =
                UniswapV3Pool(uniswapV3Pools[i].identifier, uniswapV3Pools[i].poolAddress, uniswapV3Pools[i].fee);
        }

        s_healthFactorTarget = initialHealthFactorTarget;
        s_slippageTolerance = initialSlippageTolerance;
    }

    // ================================================================
    // │                   FUNCTIONS - UUPS UPGRADES                  │
    // ================================================================

    /// @notice Internal function to authorize an upgrade.
    /// @dev Caller must have `OWNER_ROLE`.
    /// @param _newImplementation Address of the new contract implementation.
    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(OWNER_ROLE) {}

    // ================================================================
    // │                      FUNCTIONS - UPDATES                     │
    // ================================================================

    /// @notice Generic update function to set the contract address for a given identifier.
    /// @dev Caller must have `OWNER_ROLE`.
    ///      Emits a `ContractAddressUpdated` event.
    /// @param _identifier The identifier for the contract address.
    /// @param _newContractAddress The new contract address.
    function updateContractAddress(string memory _identifier, address _newContractAddress)
        external
        onlyRole(OWNER_ROLE)
    {
        emit ContractAddressUpdated(_identifier, s_contractAddresses[_identifier], _newContractAddress);
        s_contractAddresses[_identifier] = _newContractAddress;
    }

    /// @notice Generic update function to set the token address for a given identifier.
    /// @dev Caller must have `OWNER_ROLE`.
    ///      Emits a `TokenAddressUpdated` event.
    /// @param _identifier The identifier for the token address.
    /// @param _newTokenAddress The new token address.
    function updateTokenAddress(string memory _identifier, address _newTokenAddress) external onlyRole(OWNER_ROLE) {
        emit TokenAddressUpdated(_identifier, s_tokenAddresses[_identifier], _newTokenAddress);
        s_tokenAddresses[_identifier] = _newTokenAddress;
    }

    /// @notice Update UniSwapV3 pool details.
    /// @dev Caller must have `OWNER_ROLE`.
    ///      Emits a `UniswapV3PoolUpdated` event.
    function updateUniswapV3Pool(
        string memory _identifier,
        address _newUniswapV3PoolAddress,
        uint24 _newUniswapV3PoolFee
    ) external onlyRole(OWNER_ROLE) {
        emit UniswapV3PoolUpdated(_identifier, _newUniswapV3PoolAddress, _newUniswapV3PoolFee);
        s_uniswapV3Pools[_identifier] = UniswapV3Pool(_identifier, _newUniswapV3PoolAddress, _newUniswapV3PoolFee);
    }

    /// @notice Update the Health Factor target.
    /// @dev Caller must have `OWNER_ROLE`.
    ///      Emits a `HealthFactorTargetUpdated` event.
    /// @param _healthFactorTarget The new Health Factor target.
    function updateHealthFactorTarget(uint16 _healthFactorTarget) external onlyRole(OWNER_ROLE) {
        // Should be different from the current healthFactorTarget
        if (s_healthFactorTarget == _healthFactorTarget) revert AavePM__HealthFactorUnchanged();

        // New healthFactorTarget must be greater than the HEALTH_FACTOR_TARGET_MINIMUM.
        // Failsafe to prevent the position from being liquidated due to a low target.
        if (_healthFactorTarget < HEALTH_FACTOR_TARGET_MINIMUM) revert AavePM__HealthFactorBelowMinimum();

        emit HealthFactorTargetUpdated(s_healthFactorTarget, _healthFactorTarget);
        s_healthFactorTarget = _healthFactorTarget;
    }

    // ================================================================
    // │                    FUNCTIONS - ETH / WETH                    │
    // ================================================================

    /// @notice Rescue all ETH from the contract.
    /// @dev This function is intended for emergency use.
    ///      In normal operation, the contract shouldn't hold ETH,
    ///      as it is used to swap for wstETH.
    ///      It can be called without an argument to rescue the entire balance.
    ///      Caller must have `OWNER_ROLE`.
    ///      The use of nonReentrant isn't required due to the `OWNER_ROLE` restriction and it drains 100% of the ETH balance anyway.
    ///      Throws `AavePM__RescueEthFailed` if the ETH transfer fails.
    ///      Emits a `RescueEth` event.
    /// @param rescueAddress The address to send the rescued ETH to.
    function rescueEth(address rescueAddress) external onlyRole(OWNER_ROLE) {
        // Check if the rescueAddress is an owner
        if (!hasRole(OWNER_ROLE, rescueAddress)) revert AavePM__RescueAddressNotAnOwner();

        // * TRANSFER ETH *
        emit EthRescued(rescueAddress, getContractBalance("ETH"));
        (bool callSuccess,) = rescueAddress.call{value: getContractBalance("ETH")}("");
        if (!callSuccess) revert AavePM__RescueEthFailed();
    }

    function wrapETHToWETH() public payable {
        IWETH9(s_tokenAddresses["WETH"]).deposit{value: address(this).balance}();
    }

    function unwrapWETHToETH() public {
        IWETH9(s_tokenAddresses["WETH"]).withdraw(getContractBalance("WETH"));
    }

    // ================================================================
    // │                        FUNCTIONS - AAVE                      │
    // ================================================================
    function aaveSupplyWstETH() public {
        // Takes all wstETH in the contract and deposits it into Aave
        TransferHelper.safeApprove(
            s_tokenAddresses["wstETH"], address(s_contractAddresses["aave"]), getContractBalance("wstETH")
        );
        IPool(s_contractAddresses["aave"]).deposit(
            s_tokenAddresses["wstETH"], getContractBalance("wstETH"), address(this), 0
        );
    }

    function aaveBorrow() public {}

    function aaveRepay() public {}

    function aaveGetHealthFactor() public {}

    function aaveWithdraw() public {}

    // ================================================================
    // │                     FUNCTIONS - TOKEN SWAPS                  │
    // ================================================================

    /// @notice Swaps the contract's entire specified token balance using a UniswapV3 pool.
    /// @dev Caller must have `MANAGER_ROLE`.
    ///      Calculates the minimum amount that should be received based on the current pool's price ratio and a predefined slippage tolerance.
    ///      Reverts if there are no tokens in the contract or if the transaction doesn't meet the `amountOutMinimum` criteria due to price movements.
    /// @param _uniswapV3PoolIdentifier The identifier of the UniswapV3 pool to use for the swap.
    /// @param _tokenInIdentifier The identifier of the token to swap.
    /// @param _tokenOutIdentifier The identifier of the token to receive from the swap.
    /// @return tokenOutIdentifier The identifier of the token received from the swap.
    /// @return amountOut The amount tokens received from the swap.
    function swapTokens(
        string memory _uniswapV3PoolIdentifier,
        string memory _tokenInIdentifier,
        string memory _tokenOutIdentifier
    ) public onlyRole(MANAGER_ROLE) returns (string memory tokenOutIdentifier, uint256 amountOut) {
        ISwapRouter swapRouter = ISwapRouter(s_contractAddresses["uniswapV3Router"]);

        // If ETH is input or output, convert the identifier to WETH.
        _tokenInIdentifier = renameIdentifierFromETHToWETHIfNeeded(_tokenInIdentifier);
        _tokenOutIdentifier = renameIdentifierFromETHToWETHIfNeeded(_tokenOutIdentifier);

        // Check if the contract has enough tokens to swap
        uint256 currentBalance = getContractBalance(_tokenInIdentifier);
        if (currentBalance == 0) revert AavePM__NotEnoughTokensForSwap(_tokenInIdentifier);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: s_tokenAddresses[_tokenInIdentifier],
            tokenOut: s_tokenAddresses[_tokenOutIdentifier],
            fee: s_uniswapV3Pools[_uniswapV3PoolIdentifier].fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: currentBalance,
            amountOutMinimum: uniswapV3CalculateMinOut(
                currentBalance, _uniswapV3PoolIdentifier, _tokenInIdentifier, _tokenOutIdentifier
            ),
            sqrtPriceLimitX96: 0 // TODO: Calculate price limit
        });

        // Approve the swapRouter to spend the tokenIn and swap the tokens
        TransferHelper.safeApprove(s_tokenAddresses[_tokenInIdentifier], address(swapRouter), currentBalance);
        amountOut = swapRouter.exactInputSingle(params);
        return (_tokenOutIdentifier, amountOut);
    }

    // ================================================================
    // │                   FUNCTIONS - CALCULATIONS                   │
    // ================================================================

    /// @notice // TODO: Add comment
    function uniswapV3CalculateMinOut(
        uint256 _currentBalance,
        string memory _uniswapV3PoolIdentifier,
        string memory _tokenInIdentifier,
        string memory _tokenOutIdentifier
    ) public view returns (uint256 minOut) {
        IUniswapV3Pool pool = IUniswapV3Pool(s_uniswapV3Pools[_uniswapV3PoolIdentifier].poolAddress);

        // sqrtRatioX96 calculates the price of token1 in units of token0 (token1/token0)
        // so only token0 decimals are needed to calculate minOut.
        uint256 _token0Decimals = IERC20Extended(
            s_tokenAddresses[s_tokenAddresses[_tokenInIdentifier] == pool.token0()
                ? _tokenInIdentifier
                : _tokenOutIdentifier]
        ).decimals();

        // Fetch current ratio from the pool
        (uint160 sqrtRatioX96,,,,,,) = pool.slot0();

        // Calculate the current ratio
        uint256 currentRatio = uint256(sqrtRatioX96) * (uint256(sqrtRatioX96)) * (10 ** _token0Decimals) >> (96 * 2);

        uint256 expectedOut = (_currentBalance * (10 ** _token0Decimals)) / currentRatio;
        uint256 slippageTolerance = expectedOut / s_slippageTolerance;
        return minOut = expectedOut - slippageTolerance;
    }

    /// @notice // TODO: Add comment
    function renameIdentifierFromETHToWETHIfNeeded(string memory tokenIdentifier)
        private
        pure
        returns (string memory)
    {
        return (keccak256(abi.encodePacked(tokenIdentifier)) == keccak256(abi.encodePacked("ETH")))
            ? "WETH"
            : tokenIdentifier;
    }

    // ================================================================
    // │                       FUNCTIONS - GETTERS                    │
    // ================================================================

    /// @notice Getter function to get the i_creator address.
    /// @dev Public function to allow anyone to view the contract creator.
    /// @return creator The address of the creator.
    function getCreator() public view returns (address creator) {
        return s_creator;
    }

    /// @notice Getter function to get the contract version.
    /// @dev Public function to allow anyone to view the contract version.
    /// @return version The contract version.
    function getVersion() public pure returns (string memory version) {
        return VERSION;
    }

    /// @notice Getter function to get the role hash of a specified role.
    /// @dev Public function to allow anyone to generate a role hash.
    /// @return roleHash The role hash corresponding to the given role.
    function getRoleHash(string memory role) public pure returns (bytes32 roleHash) {
        return keccak256(abi.encodePacked(role));
    }

    /// @notice Generic getter function to get the contract address for a given identifier.
    /// @dev Public function to allow anyone to view the contract address for the given identifier.
    /// @param _identifier The identifier for the contract address.
    /// @return contractAddress The contract address corresponding to the given identifier.
    function getContractAddress(string memory _identifier) public view returns (address contractAddress) {
        return s_contractAddresses[_identifier];
    }

    /// @notice Generic getter function to get the token address for a given identifier.
    /// @dev Public function to allow anyone to view the token address for the given identifier.
    /// @param _identifier The identifier for the contract address.
    /// @return tokenAddress The token address corresponding to the given identifier.
    function getTokenAddress(string memory _identifier) public view returns (address tokenAddress) {
        return s_tokenAddresses[_identifier];
    }

    /// @notice Getter function to get the UniswapV3 pool address and fee.
    /// @dev Public function to allow anyone to view the UniswapV3 pool address and fee.
    /// @param _identifier The identifier for the UniswapV3 pool.
    /// @return uniswapV3PoolAddress The UniswapV3 pool address.
    /// @return uniswapV3PoolFee The UniswapV3 pool fee.
    function getUniswapV3Pool(string memory _identifier)
        public
        view
        returns (address uniswapV3PoolAddress, uint24 uniswapV3PoolFee)
    {
        return (s_uniswapV3Pools[_identifier].poolAddress, s_uniswapV3Pools[_identifier].fee);
    }

    /// @notice Getter function to get the Health Factor target.
    /// @dev Public function to allow anyone to view the Health Factor target value.
    /// @return healthFactorTarget The Health Factor target.
    function getHealthFactorTarget() public view returns (uint16 healthFactorTarget) {
        return s_healthFactorTarget;
    }

    /// @notice Getter function to get the Health Factor Target minimum.
    /// @dev Public function to allow anyone to view the Health Factor Target minimum value.
    /// @return healthFactorTargetMinimum The Health Factor Target minimum value.
    function getHealthFactorTargetMinimum() public pure returns (uint16 healthFactorTargetMinimum) {
        return HEALTH_FACTOR_TARGET_MINIMUM;
    }

    /// @notice Getter function to get the contract's balance.
    /// @dev Public function to allow anyone to view the contract's balance.
    /// @param _identifier The identifier for the token address.
    /// @return contractBalance The contract's balance of the specified token identifier.
    function getContractBalance(string memory _identifier) public view returns (uint256 contractBalance) {
        if (keccak256(abi.encodePacked(_identifier)) == keccak256(abi.encodePacked("ETH"))) {
            return contractBalance = address(this).balance;
        } else {
            return contractBalance = IERC20(s_tokenAddresses[_identifier]).balanceOf(address(this));
        }
    }
}
