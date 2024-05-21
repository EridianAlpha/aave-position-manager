// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AaveFunctions} from "./AaveFunctions.sol";
import {TokenSwaps} from "./TokenSwaps.sol";

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
import {IPriceOracle} from "@aave/aave-v3-core/contracts/interfaces/IPriceOracle.sol";

import {IAavePM} from "./interfaces/IAavePM.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {IERC20Extended} from "./interfaces/IERC20Extended.sol";

/// @title AavePM - Aave Position Manager
/// @author EridianAlpha
/// @notice A contract to manage positions on Aave.
contract AavePM is IAavePM, AaveFunctions, TokenSwaps, Initializable, AccessControlUpgradeable, UUPSUpgradeable {
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

    /// @notice The divisor for the Aave Health Factor.
    /// @dev The Aave Health Factor is a value with 18 decimal places.
    ///      This divisor is used to scale the Health Factor to 2 decimal places.
    //       Used to convert e.g. 2000003260332359246 into 200.
    uint256 constant AAVE_HEALTH_FACTOR_DIVISOR = 1e16;

    // ================================================================
    // │                           MODIFIERS                          │
    // ================================================================
    // No modifiers are defined in the contract.

    // ================================================================
    // │           FUNCTIONS - CONSTRUCTOR, RECEIVE, FALLBACK         │
    // ================================================================

    /// @notice Constructor implemented but unused.
    /// @dev Contract is upgradeable and therefore the constructor is not used.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice // TODO: Add comment
    receive() external payable {}

    /// @notice // TODO: Add comment
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

        // Grant the contract the MANAGER_ROLE to allow it to execute its own functions.
        _grantRole(MANAGER_ROLE, address(this));

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

    function wrapETHToWETH() internal {
        IWETH9(s_tokenAddresses["WETH"]).deposit{value: address(this).balance}();
    }

    function unwrapWETHToETH() internal {
        IWETH9(s_tokenAddresses["WETH"]).withdraw(getContractBalance("WETH"));
    }

    // ================================================================
    // │                   FUNCTIONS - AAVE FLASH LOAN                │
    // ================================================================

    /// @notice Flash loan callback function.
    /// @dev This function is called by the Aave pool contract after the flash loan is executed.
    ///      It is used to repay the flash loan and execute the operation.
    ///      The function is called by the Aave pool contract and is not intended to be called directly.
    /// @param asset The address of the asset being flash loaned.
    /// @param amount The amount of the asset being flash loaned.
    /// @param premium The fee charged for the flash loan.
    /// @param initiator The address of the contract that initiated the flash loan.
    /// @return bool True if the operation was successful.
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata /* params */
    ) external returns (bool) {
        // Only allow the AavePM contract to initiate the flashloan and execute this function.
        if (initiator != address(this)) revert AavePM__FlashLoanInitiatorUnauthorized();

        address wstETHAddress = s_tokenAddresses["wstETH"];
        address aavePoolAddress = s_contractAddresses["aavePool"];

        uint256 repaymentAmountTotalUSDC = amount + premium;

        // Use the flash loan USDC to repay the debt.
        _aaveRepayDebt(aavePoolAddress, s_tokenAddresses["USDC"], amount);

        // Now the HF is higher, withdraw the corresponding amount of wstETH from collateral.
        // TODO: Use Uniswap price as that's where the swap will happen.
        uint256 wstETHPrice = IPriceOracle(s_contractAddresses["aaveOracle"]).getAssetPrice(wstETHAddress);

        // Calculate the amount of wstETH to withdraw.
        // TODO: Why 1e20 ?
        uint256 wstETHToWithdraw = (repaymentAmountTotalUSDC * 1e20) / wstETHPrice;

        // TODO: Calculate the slippage allowance - currently using 1005 (0.5%) slippage allowance
        uint256 wstETHToWithdrawSlippageAllowance = (wstETHToWithdraw * 1005) / 1000;

        // Withdraw the wstETH from Aave.
        _aaveWithdrawCollateral(aavePoolAddress, wstETHAddress, wstETHToWithdrawSlippageAllowance);

        // Convert the wstETH to USDC.
        _swapTokens("wstETH/ETH", "wstETH", "ETH");
        _swapTokens("USDC/ETH", "ETH", "USDC");
        TransferHelper.safeApprove(asset, aavePoolAddress, repaymentAmountTotalUSDC);
        return true;
    }

    // ================================================================
    // │                   FUNCTIONS - CALCULATIONS                   │
    // ================================================================

    function calculateMaxBorrowUSDC(
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 currentLiquidationThreshold,
        uint16 healthFactorTarget
    ) private pure returns (uint256 maxBorrowUSDC) {
        /* 
        *   Calculate the maximum amount of USDC that can be borrowed.
        *       - Minus totalDebtBase from totalCollateralBase to get the actual collateral not including reinvested debt.
        *       - At the end, minus totalDebtBase to get the remaining amount to borrow to reach the target health factor.
        *       - currentLiquidationThreshold is a percentage with 4 decimal places e.g. 8250 = 82.5%.
        *       - healthFactorTarget is a value with 2 decimal places e.g. 200 = 2.00.
        *       - totalCollateralBase is in USD base unit with 8 decimals to the dollar e.g. 100000000 = $1.00.
        *       - totalDebtBase is in USD base unit with 8 decimals to the dollar e.g. 100000000 = $1.00.
        *       - 1e2 used as healthFactorTarget has 2 decimal places.
        *
        *                   ((totalCollateralBase - totalDebtBase) * currentLiquidationThreshold ) 
        *  maxBorrowUSDC = ------------------------------------------------------------------------
        *                          ((healthFactorTarget * 1e2) - currentLiquidationThreshold)      
        */
        maxBorrowUSDC = (
            ((totalCollateralBase - totalDebtBase) * currentLiquidationThreshold)
                / ((healthFactorTarget * 1e2) - currentLiquidationThreshold)
        );
    }

    // ================================================================
    // │            FUNCTIONS - REBALANCE, DEPOSIT, WITHDRAW          │
    // ================================================================

    /// @notice Rebalance the Aave position.
    /// @dev Caller must have `MANAGER_ROLE`.
    ///      The function rebalances the Aave position by converting any ETH to WETH, then WETH to wstETH.
    ///      It then deposits the wstETH into Aave.
    ///      If the health factor is below the target, it repays debt to increase the health factor.
    ///      If the health factor is above the target, it borrows more USDC and reinvests.
    function rebalance() public onlyRole(MANAGER_ROLE) {
        // Convert any existing tokens and supply to Aave.
        if (getContractBalance("ETH") > 0) wrapETHToWETH();
        if (getContractBalance("WETH") > 0) _swapTokens("wstETH/ETH", "ETH", "wstETH");
        if (getContractBalance("wstETH") > 0) {
            _aaveSupply(s_contractAddresses["aavePool"], s_tokenAddresses["wstETH"], getContractBalance("wstETH"));
        }

        // Get the current Aave account data.
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            ,
            uint256 currentLiquidationThreshold,
            ,
            uint256 initialHealthFactor
        ) = getAaveAccountData();

        // Scale the initial health factor to 2 decimal places.
        uint256 initialHealthFactorScaled = initialHealthFactor / AAVE_HEALTH_FACTOR_DIVISOR;

        // Get the current health factor target.
        uint16 healthFactorTarget = getHealthFactorTarget();

        // Calculate the maximum amount of USDC that can be borrowed.
        uint256 maxBorrowUSDC =
            calculateMaxBorrowUSDC(totalCollateralBase, totalDebtBase, currentLiquidationThreshold, healthFactorTarget);

        // TODO: Calculate this elsewhere.
        uint16 healthFactorTargetRange = 10;

        // Get data from state
        address aavePoolAddress = s_contractAddresses["aavePool"];
        address wstETHAddress = s_tokenAddresses["wstETH"];
        address usdcAddress = s_tokenAddresses["USDC"];

        if (initialHealthFactorScaled < (healthFactorTarget - healthFactorTargetRange)) {
            // If the health factor is below the target, repay debt to increase the health factor.

            // Calculate the repayment amount required to reach the target health factor.
            uint256 repaymentAmountUSDC = totalDebtBase - maxBorrowUSDC;

            // Take out a flash loan for the USDC amount needed to repay and rebalance the health factor.
            // flashLoanSimple `amount` input parameter is decimals to the dollar, so divide by 1e2 to get the correct amount
            IPool(aavePoolAddress).flashLoanSimple(address(this), usdcAddress, repaymentAmountUSDC / 1e2, bytes(""), 0);

            // Deposit any remaining dust to Aave.
            // TODO: Set a lower limit for dust so it doesn't cost more in gas to deposit than the amount.
            if (getContractBalance("wstETH") > 0) {
                _aaveSupply(aavePoolAddress, wstETHAddress, getContractBalance("wstETH"));
            }
            if (getContractBalance("USDC") > 0) {
                _aaveRepayDebt(aavePoolAddress, usdcAddress, getContractBalance("USDC"));
            }
        } else if (initialHealthFactorScaled > healthFactorTarget + healthFactorTargetRange) {
            // If the health factor is above the target, borrow more USDC and reinvest.

            // Calculate the additional amount to borrow to reach the target health factor.
            uint256 additionalBorrowUSDC = maxBorrowUSDC - totalDebtBase;

            // _aaveBorrow input parameter is decimals to the dollar, so divide by 1e2 to get the correct amount.
            uint256 borrowAmountUSDC = additionalBorrowUSDC / 1e2;
            _aaveBorrow(aavePoolAddress, usdcAddress, borrowAmountUSDC);

            // Swap borrowed USDC ➜ WETH ➜ wstETH then supply to Aave.
            _swapTokens("USDC/ETH", "USDC", "ETH");
            _swapTokens("wstETH/ETH", "ETH", "wstETH");
            _aaveSupply(aavePoolAddress, wstETHAddress, getContractBalance("wstETH"));
        }

        // Safety check to ensure the health factor is above the minimum target.
        // TODO: Improve check.
        (,,,,, uint256 endHealthFactor) = getAaveAccountData();
        uint256 endHealthFactorScaled = endHealthFactor / AAVE_HEALTH_FACTOR_DIVISOR;
        if (endHealthFactorScaled < (HEALTH_FACTOR_TARGET_MINIMUM - 1)) revert AavePM__HealthFactorBelowMinimum();
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

    /// @notice Getter function to get the Slippage Tolerance.
    /// @dev Public function to allow anyone to view the Slippage Tolerance value.
    /// @return slippageTolerance The Slippage Tolerance value.
    function getSlippageTolerance() public view returns (uint16 slippageTolerance) {
        return s_slippageTolerance;
    }

    /// @notice Getter function to get the Aave user account data.
    /// @dev Public function to allow anyone to view the Aave user account data.
    /// @return totalCollateralBase The total collateral in the user's account.
    /// @return totalDebtBase The total debt in the user's account.
    /// @return availableBorrowsBase The available borrows in the user's account.
    /// @return currentLiquidationThreshold The current liquidation threshold in the user's account.
    /// @return ltv The loan-to-value ratio in the user's account.
    /// @return healthFactor The health factor in the user's account.
    function getAaveAccountData()
        public
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        (totalCollateralBase, totalDebtBase, availableBorrowsBase, currentLiquidationThreshold, ltv, healthFactor) =
            IPool(s_contractAddresses["aavePool"]).getUserAccountData(address(this));
    }
}
