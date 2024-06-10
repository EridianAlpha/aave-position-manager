// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ================================================================
// │                           IMPORTS                            │
// ================================================================

// Inherited Contract Imports
import {Rebalance} from "./Rebalance.sol";
import {Reinvest} from "./Reinvest.sol";
import {BorrowAndWithdrawUSDC} from "./BorrowAndWithdrawUSDC.sol";

// OpenZeppelin Imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

// Aave Imports
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// Interface Imports
import {IAavePM} from "./interfaces/IAavePM.sol";

// ================================================================
// │                       AAVEPM CONTRACT                        │
// ================================================================

/// @title AavePM - Aave Position Manager
/// @author EridianAlpha
/// @notice A contract to manage positions on Aave.
contract AavePM is
    IAavePM,
    Rebalance,
    Reinvest,
    BorrowAndWithdrawUSDC,
    Initializable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable
{
    // ================================================================
    // │                        STATE VARIABLES                       │
    // ================================================================

    // Addresses
    address internal s_creator; // Creator of the contract
    mapping(string => address) internal s_contractAddresses;
    mapping(string => address) internal s_tokenAddresses;
    mapping(string => UniswapV3Pool) internal s_uniswapV3Pools;

    // Values
    uint16 internal s_healthFactorTarget;
    uint16 internal s_slippageTolerance;
    uint256 internal s_withdrawnUSDCTotal = 0;
    uint256 internal s_reinvestedDebtTotal = 0;
    uint256 internal s_suppliedCollateralTotal = 0;

    // ================================================================
    // │                           CONSTANTS                          │
    // ================================================================

    /// @notice The version of the contract.
    /// @dev Contract is upgradeable so the version is a constant set on each implementation contract.
    string internal constant VERSION = "0.0.1";

    /// @notice The role hashes for the contract.
    /// @dev Two independent roles are defined: `OWNER_ROLE` and `MANAGER_ROLE`.
    bytes32 internal constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 internal constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice The minimum Health Factor target.
    /// @dev The value is hardcoded in the contract to prevent the position from
    ///      being liquidated cause by accidentally setting a low target.
    ///      A contract upgrade is required to change this value.
    uint16 internal constant HEALTH_FACTOR_TARGET_MINIMUM = 200; // 2.00

    /// @notice The maximum Slippage Tolerance.
    /// @dev The value is hardcoded in the contract to prevent terrible trades
    ///      from occurring due to a high slippage tolerance.
    ///      A contract upgrade is required to change this value.
    uint16 internal constant SLIPPAGE_TOLERANCE_MAXIMUM = 100; // 1.00%

    // ================================================================
    // │                           MODIFIERS                          │
    // ================================================================

    /// @notice // TODO: Add comment
    modifier checkOwner(address _owner) {
        if (!hasRole(OWNER_ROLE, _owner)) revert AavePM__AddressNotAnOwner();
        _;
    }

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
    /// @param initialSlippageTolerance The initial slippage tolerance for token swaps.
    function initialize(
        address owner,
        ContractAddress[] memory contractAddresses,
        TokenAddress[] memory tokenAddresses,
        UniswapV3Pool[] memory uniswapV3Pools,
        uint16 initialHealthFactorTarget,
        uint16 initialSlippageTolerance
    ) public initializer {
        __AccessControlEnumerable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _initializeState(
            owner,
            contractAddresses,
            tokenAddresses,
            uniswapV3Pools,
            initialHealthFactorTarget,
            initialSlippageTolerance
        );
    }

    /// @notice // TODO: Add comment. Just the state setting logic
    function _initializeState(
        address owner,
        ContractAddress[] memory contractAddresses,
        TokenAddress[] memory tokenAddresses,
        UniswapV3Pool[] memory uniswapV3Pools,
        uint16 initialHealthFactorTarget,
        uint16 initialSlippageTolerance
    ) internal {
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
    /// @dev Caller must have `MANAGER_ROLE`.
    ///      Emits a `HealthFactorTargetUpdated` event.
    /// @param _healthFactorTarget The new Health Factor target.
    function updateHealthFactorTarget(uint16 _healthFactorTarget) external onlyRole(MANAGER_ROLE) {
        // Should be different from the current s_healthFactorTarget
        if (s_healthFactorTarget == _healthFactorTarget) revert AavePM__HealthFactorUnchanged();

        // New healthFactorTarget must be greater than the HEALTH_FACTOR_TARGET_MINIMUM.
        // Failsafe to prevent the position from being liquidated due to a low target.
        if (_healthFactorTarget < HEALTH_FACTOR_TARGET_MINIMUM) revert AavePM__HealthFactorBelowMinimum();

        emit HealthFactorTargetUpdated(s_healthFactorTarget, _healthFactorTarget);
        s_healthFactorTarget = _healthFactorTarget;
    }

    /// @notice Update the Slippage Tolerance.
    /// @dev Caller must have `MANAGER_ROLE`.
    ///      Emits a `SlippageToleranceUpdated` event.
    /// @param _slippageTolerance The new Slippage Tolerance.
    function updateSlippageTolerance(uint16 _slippageTolerance) external onlyRole(MANAGER_ROLE) {
        // Should be different from the current s_slippageTolerance
        if (s_slippageTolerance == _slippageTolerance) revert AavePM__SlippageToleranceUnchanged();

        // New _slippageTolerance must be greater than the SLIPPAGE_TOLERANCE_MAXIMUM.
        // The calculation for slippage tolerance to percentage is 100 / _slippageTolerance,
        // so a higher value means a lower tolerance.
        // Failsafe to prevent terrible trades occurring due to a high slippage tolerance.
        if (_slippageTolerance < SLIPPAGE_TOLERANCE_MAXIMUM) revert AavePM__SlippageToleranceAboveMaximum();

        emit SlippageToleranceUpdated(s_slippageTolerance, _slippageTolerance);
        s_slippageTolerance = _slippageTolerance;
    }

    // ================================================================
    // │                   FUNCTIONS - CORE FUNCTIONS                 │
    // ================================================================

    /// @notice Rebalance the Aave position.
    /// @dev Caller must have `MANAGER_ROLE`.
    ///      The function rebalances the Aave position by converting any ETH to WETH, then WETH to wstETH.
    ///      It then deposits the wstETH into Aave.
    ///      If the health factor is below the target, it repays debt to increase the health factor.
    function rebalance() public onlyRole(MANAGER_ROLE) {
        // Convert any existing tokens to wstETH and supply to Aave.
        aaveSupply();

        // Perform rebalance.
        (uint256 repaymentAmountUSDC) = _rebalance();

        if (repaymentAmountUSDC > 0 && s_reinvestedDebtTotal >= repaymentAmountUSDC) {
            s_reinvestedDebtTotal -= repaymentAmountUSDC;
        } else {
            s_reinvestedDebtTotal = 0;
        }
    }

    /// @notice // TODO: Add comment
    function reinvest() public onlyRole(MANAGER_ROLE) returns (uint256 reinvestedDebt) {
        // Convert any existing tokens to wstETH and supply to Aave.
        aaveSupply();

        // Reinvest any excess debt or collateral.
        (reinvestedDebt) = _reinvest();
        if (reinvestedDebt > 0) s_reinvestedDebtTotal += reinvestedDebt;

        // TODO: Emit an event with suppliedCollateral, reinvestedDebt, reinvestedCollateral
    }

    /// @notice // TODO: Add comment
    function aaveSupply() public onlyRole(MANAGER_ROLE) returns (uint256 suppliedCollateral) {
        suppliedCollateral = _convertExistingBalanceToWstETHAndSupplyToAave();
        if (suppliedCollateral > 0) s_suppliedCollateralTotal += suppliedCollateral;
        // TODO: Add event to emit the suppliedCollateral
    }

    /// @notice // TODO: Add comment
    function aaveRepay() public onlyRole(MANAGER_ROLE) {
        uint256 usdcBalance = getContractBalance("USDC");
        if (usdcBalance == 0) revert AavePM__NoDebtToRepay();

        _aaveRepayDebt(getContractAddress("aavePool"), getTokenAddress("USDC"), usdcBalance);

        // When a debt repayment is made, s_withdrawnUSDCTotal should be updated to reflect the repayment, up to 0.
        // and any excess should be taken off the s_reinvestedDebtTotal.
        uint256 initialWithdrawnUSDCTotal = s_withdrawnUSDCTotal;
        if (initialWithdrawnUSDCTotal >= usdcBalance) {
            s_withdrawnUSDCTotal -= usdcBalance;
        } else if (initialWithdrawnUSDCTotal + s_reinvestedDebtTotal >= usdcBalance) {
            s_reinvestedDebtTotal -= (usdcBalance - initialWithdrawnUSDCTotal);
            s_withdrawnUSDCTotal = 0;
        } else {
            s_reinvestedDebtTotal = 0;
            s_withdrawnUSDCTotal = 0;
        }
    }

    // ================================================================
    // │                FUNCTIONS - WITHDRAW FUNCTIONS                │
    // ================================================================

    /// @notice Rescue all ETH from the contract.
    /// @dev This function is intended for emergency use.
    ///      In normal operation, the contract shouldn't hold ETH,
    ///      as it is used to swap for wstETH.
    ///      It is called without an argument to rescue the entire balance.
    ///      Caller must have `MANAGER_ROLE`.
    ///      The use of nonReentrant isn't required due to the `rescueAddress` check for the `OWNER_ROLE`
    ///      and it drains 100% of the ETH balance anyway.
    ///      Throws `AavePM__RescueEthFailed` if the ETH transfer fails.
    ///      Emits a `RescueEth` event.
    /// @param _rescueAddress The address to send the rescued ETH to.
    function rescueEth(address _rescueAddress) external onlyRole(MANAGER_ROLE) checkOwner(_rescueAddress) {
        // * TRANSFER ETH *
        emit EthRescued(_rescueAddress, getContractBalance("ETH"));
        (bool callSuccess,) = _rescueAddress.call{value: getContractBalance("ETH")}("");
        if (!callSuccess) revert AavePM__RescueEthFailed();
    }

    /// @notice // TODO: Add comment
    function aaveWithdrawWstETH(uint256 _amount, address _owner) public onlyRole(MANAGER_ROLE) checkOwner(_owner) {
        // TODO: Improve this function so it doesn't allow withdrawals below the target HF, not just the minimum
        //       Then this will only be used once debt has been repaid
        address aavePoolAddress = getContractAddress("aavePool");

        // Get the collateral base value before withdrawing.
        (uint256 initialCollateralBase,,,,,) = IPool(aavePoolAddress).getUserAccountData(address(this));

        address wstETHAddress = getTokenAddress("wstETH");
        _aaveWithdrawCollateral(aavePoolAddress, wstETHAddress, _amount);
        IERC20(wstETHAddress).transfer(_owner, _amount);

        // Get the collateral base value after withdrawing.
        (uint256 endCollateralBase,,,,,) = IPool(aavePoolAddress).getUserAccountData(address(this));

        uint256 initialSuppliedCollateral = getSuppliedCollateralTotal();

        if (endCollateralBase < initialCollateralBase) {
            uint256 collateralDeltaBase = initialCollateralBase - endCollateralBase;
            if (initialSuppliedCollateral >= collateralDeltaBase / 1e2) {
                s_suppliedCollateralTotal -= collateralDeltaBase / 1e2;
            } else if (initialSuppliedCollateral + s_reinvestedDebtTotal >= collateralDeltaBase / 1e2) {
                s_suppliedCollateralTotal = 0;
                s_reinvestedDebtTotal -= (collateralDeltaBase / 1e2 - initialSuppliedCollateral);
            } else {
                s_suppliedCollateralTotal = 0;
                s_reinvestedDebtTotal = 0;
            }
        }

        // Check to ensure the health factor is above the minimum target.
        _checkHealthFactorAboveMinimum();
    }

    /// @notice // TODO: Add comment
    function borrowAndWithdrawUSDC(uint256 _amount, address _owner) public onlyRole(MANAGER_ROLE) checkOwner(_owner) {
        // Check the requested borrow amount is greater than 0.
        if (_amount == 0) revert AavePM__ZeroBorrowAmount();

        // Check the available borrow and withdraw amount is greater than 0.
        uint256 maxBorrowAndWithdrawUSDCAmount = getMaxBorrowAndWithdrawUSDCAmount();
        if (maxBorrowAndWithdrawUSDCAmount == 0) revert IAavePM.AavePM__ZeroBorrowAndWithdrawUSDCAvailable();

        // Initialize a boolean as false to check if the maximum amount is withdrawn.
        bool maxWithdraw = false;

        // Ensure the requested borrow amount is less than or equal to the maximum available
        // and allows for the maximum amount of USDC to be borrowed without throwing an error.
        if (_amount >= maxBorrowAndWithdrawUSDCAmount) {
            _amount = maxBorrowAndWithdrawUSDCAmount;
            maxWithdraw = true;
        }

        // Borrow the requested amount of USDC and withdraw it to the owner.
        (uint256 repaidReinvestedDebt) = _borrowAndWithdrawUSDC(_amount, _owner);

        // Update the total withdrawn USDC amount.
        s_withdrawnUSDCTotal += _amount;

        if (!maxWithdraw) {
            // Update the total reinvested debt amount if the maximum amount is not withdrawn.
            if (s_reinvestedDebtTotal > repaidReinvestedDebt) s_reinvestedDebtTotal -= repaidReinvestedDebt;
        } else {
            // Ensures a clean reset of the reinvested debt total if the maximum amount is withdrawn.
            s_reinvestedDebtTotal = 0;
        }

        // Check to ensure the health factor is above the minimum target.
        _checkHealthFactorAboveMinimum();
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

    /// @notice Getter function to get the Slippage Tolerance.
    /// @dev Public function to allow anyone to view the Slippage Tolerance value.
    /// @return slippageTolerance The Slippage Tolerance value.
    function getSlippageTolerance() public view returns (uint16 slippageTolerance) {
        return s_slippageTolerance;
    }

    /// @notice Getter function to get the Slippage Tolerance maximum.
    /// @dev Public function to allow anyone to view the Slippage Tolerance maximum value.
    /// @return slippageToleranceMaximum The Slippage Tolerance maximum value.
    function getSlippageToleranceMaximum() public pure returns (uint16 slippageToleranceMaximum) {
        return SLIPPAGE_TOLERANCE_MAXIMUM;
    }

    /// @notice Getter function to get the balance of the provided identifier.
    /// @dev Public function to allow anyone to view the balance of the provided identifier.
    /// @param _identifier The identifier for the token address.
    /// @return contractBalance The balance of the specified token identifier.
    function getContractBalance(string memory _identifier) public view returns (uint256 contractBalance) {
        if (keccak256(abi.encodePacked(_identifier)) == keccak256(abi.encodePacked("ETH"))) {
            return contractBalance = address(this).balance;
        } else {
            return contractBalance = IERC20(s_tokenAddresses[_identifier]).balanceOf(address(this));
        }
    }

    /// @notice Getter function to get all the members of a role.
    /// @dev Public function to allow anyone to view the members of a role.
    /// @param _roleString The identifier for the role.
    /// @return members The array of addresses that are members of the role.
    function getRoleMembers(string memory _roleString) public view returns (address[] memory) {
        bytes32 _role = keccak256(abi.encodePacked(_roleString));
        uint256 count = getRoleMemberCount(_role);
        address[] memory members = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            members[i] = getRoleMember(_role, i);
        }
        return members;
    }

    /// @notice Getter function to get the total amount of USDC withdrawn.
    /// @dev Public function to allow anyone to view the total amount of USDC withdrawn.
    /// @return withdrawnUSDCTotal The total amount of USDC withdrawn.
    function getWithdrawnUSDCTotal() public view returns (uint256 withdrawnUSDCTotal) {
        return s_withdrawnUSDCTotal;
    }

    /// @notice Getter function to get the total amount of reinvested debt.
    /// @dev Public function to allow anyone to view the total amount of reinvested debt.
    /// @return reinvestedDebtTotal The total amount of reinvested debt.
    function getReinvestedDebtTotal() public view returns (uint256 reinvestedDebtTotal) {
        return s_reinvestedDebtTotal;
    }

    /// @notice Getter function to get the total collateral delta.
    /// @dev Public function to allow anyone to view the total collateral delta.
    /// @return totalCollateralDelta The total collateral delta.
    /// @return isPositive A boolean indicating if the total collateral delta is positive.
    function getTotalCollateralDelta() public view returns (uint256 totalCollateralDelta, bool isPositive) {
        (uint256 totalCollateralBase,,,,,) = IPool(getContractAddress("aavePool")).getUserAccountData(address(this));
        return _getTotalCollateralDelta(totalCollateralBase, getReinvestedDebtTotal(), getSuppliedCollateralTotal());
    }

    /// @notice Getter function to get the total amount of supplied collateral.
    /// @dev Public function to allow anyone to view the total amount of supplied collateral.
    /// @return suppliedCollateralTotal The total amount of supplied collateral.
    function getSuppliedCollateralTotal() public view returns (uint256 suppliedCollateralTotal) {
        return s_suppliedCollateralTotal;
    }

    /// @notice // TODO: Add comment
    function getMaxBorrowAndWithdrawUSDCAmount() public view returns (uint256 maxBorrowAndWithdrawUSDCAmount) {
        address aavePoolAddress = getContractAddress("aavePool");
        (uint256 totalCollateralBase, uint256 totalDebtBase,, uint256 currentLiquidationThreshold,,) =
            IPool(aavePoolAddress).getUserAccountData(address(this));

        // Get the current health factor target and reinvested debt.
        uint16 healthFactorTarget = getHealthFactorTarget();
        uint256 reinvestedDebt = getReinvestedDebtTotal();

        int256 calcMaxBorrowAndWithdrawUSDCAmount = (
            ((int256(totalCollateralBase) - (int256(reinvestedDebt) * 1e2)) * int256(currentLiquidationThreshold))
                / (int256(uint256(healthFactorTarget)) * 1e2)
        ) - (int256(totalDebtBase) - (int256(reinvestedDebt) * 1e2));

        return calcMaxBorrowAndWithdrawUSDCAmount > 0 ? uint256(calcMaxBorrowAndWithdrawUSDCAmount) / 1e2 : 0;
    }

    /// @notice // TODO: Add comment
    function getReinvestableAmount() public view returns (uint256 reinvestableAmount) {
        (uint256 totalCollateralBase, uint256 totalDebtBase,, uint256 currentLiquidationThreshold,,) =
            IPool(getContractAddress("aavePool")).getUserAccountData(address(this));

        uint256 maxBorrowUSDC = _calculateMaxBorrowUSDC(
            totalCollateralBase, totalDebtBase, currentLiquidationThreshold, getHealthFactorTarget()
        );

        // Calculate the additional amount to borrow to reach the target health factor.
        if (maxBorrowUSDC > totalDebtBase) {
            return reinvestableAmount = (maxBorrowUSDC - totalDebtBase) / 1e2;
        } else {
            return reinvestableAmount = 0;
        }
    }

    // ================================================================
    // │             INHERITED FUNCTIONS - ACCESS CONTROLS            │
    // ================================================================

    /// @notice // TODO: Add comment
    function getRoleMember(bytes32 role, uint256 index)
        public
        view
        override(IAavePM, AccessControlEnumerableUpgradeable)
        returns (address)
    {
        return AccessControlEnumerableUpgradeable.getRoleMember(role, index);
    }

    /// @notice // TODO: Add comment
    function getRoleMemberCount(bytes32 role)
        public
        view
        override(IAavePM, AccessControlEnumerableUpgradeable)
        returns (uint256)
    {
        return AccessControlEnumerableUpgradeable.getRoleMemberCount(role);
    }

    /// @notice // TODO: Add comment
    function getRoleAdmin(bytes32 role)
        public
        view
        override(IAavePM, IAccessControl, AccessControlUpgradeable)
        returns (bytes32)
    {
        return AccessControlUpgradeable.getRoleAdmin(role);
    }

    /// @notice // TODO: Add comment
    function grantRole(bytes32 role, address account)
        public
        override(IAavePM, IAccessControl, AccessControlUpgradeable)
    {
        AccessControlUpgradeable.grantRole(role, account);
    }

    /// @notice // TODO: Add comment
    function hasRole(bytes32 role, address account)
        public
        view
        override(IAavePM, IAccessControl, AccessControlUpgradeable)
        returns (bool)
    {
        return AccessControlUpgradeable.hasRole(role, account);
    }

    /// @notice // TODO: Add comment
    function renounceRole(bytes32 role, address callerConfirmation)
        public
        override(IAavePM, IAccessControl, AccessControlUpgradeable)
    {
        AccessControlUpgradeable.renounceRole(role, callerConfirmation);
    }

    /// @notice // TODO: Add comment
    function revokeRole(bytes32 role, address account)
        public
        override(IAavePM, IAccessControl, AccessControlUpgradeable)
    {
        AccessControlUpgradeable.revokeRole(role, account);
    }

    /// @notice // TODO: Add comment
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IAavePM, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return AccessControlEnumerableUpgradeable.supportsInterface(interfaceId);
    }

    // ================================================================
    // │                 INHERITED FUNCTIONS - UPGRADES               │
    // ================================================================

    /// @notice Internal function to authorize an upgrade.
    /// @dev Caller must have `OWNER_ROLE`.
    /// @param _newImplementation Address of the new contract implementation.
    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(OWNER_ROLE) {}

    /// @notice // TODO: Add comment
    function upgradeToAndCall(address newImplementation, bytes memory data)
        public
        payable
        override(IAavePM, UUPSUpgradeable)
    {
        UUPSUpgradeable.upgradeToAndCall(newImplementation, data);
    }

    // ================================================================
    // │             INHERITED FUNCTIONS - AAVE FLASH LOAN            │
    // ================================================================

    /// @notice Flash loan callback function.
    /// @dev This function is called by the Aave pool contract after the flash loan is executed.
    ///      It is used to repay the flash loan and execute the operation.
    ///      The function is called by the Aave pool contract and is not intended to be called directly.
    /// @param asset The address of the asset being flash loaned.
    /// @param amount The amount of the asset being flash loaned.
    /// @param premium The fee charged for the flash loan.
    /// @param initiator The address of the contract that initiated the flash loan.
    /// @param params The parameters for the flash loan operation.
    /// @return bool True if the operation was successful.
    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata params)
        external
        returns (bool)
    {
        return _executeOperation(asset, amount, premium, initiator, params);
    }
}
