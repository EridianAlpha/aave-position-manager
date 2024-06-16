// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title AavePM Interface
/// @notice This interface defines the essential structures and functions for the AavePM contract.
interface IAavePM {
    // ================================================================
    // │                            ERRORS                            │
    // ================================================================
    error AavePM__NoDebtToRepay();
    error AavePM__RescueEthFailed();
    error AavePM__ZeroBorrowAmount();
    error AavePM__AddressNotAnOwner();
    error AavePM__DelegateCallFailed();
    error AavePM__NoTokensToWithdraw();
    error AavePM__ReinvestNotRequired();
    error AavePM__RebalanceNotRequired();
    error AavePM__FunctionDoesNotExist();
    error AavePM__NegativeInterestCalc();
    error AavePM__HealthFactorUnchanged();
    error AavePM__NoCollateralToWithdraw();
    error AavePM__InvalidWithdrawalToken();
    error AavePM__HealthFactorBelowMinimum();
    error AavePM__SlippageToleranceUnchanged();
    error AavePM__SlippageToleranceAboveMaximum();
    error AavePM__ZeroBorrowAndWithdrawUSDCAvailable();
    error AavePM__ManagerDailyInvocationLimitReached();

    error AaveFunctions__FlashLoanMsgSenderUnauthorized();
    error AaveFunctions__FlashLoanInitiatorUnauthorized();

    error TokenSwaps__NotEnoughTokensForSwap(string tokenInIdentifier);

    // ================================================================
    // │                           STRUCTS                            │
    // ================================================================
    struct UpgradeHistory {
        string version;
        uint256 upgradeTime;
        address upgradeInitiator;
    }

    struct ContractAddress {
        string identifier;
        address contractAddress;
    }

    struct TokenAddress {
        string identifier;
        address tokenAddress;
    }

    struct UniswapV3Pool {
        string identifier;
        address poolAddress;
        uint24 fee;
    }

    // ================================================================
    // │                            EVENTS                            │
    // ================================================================
    event EthRescued(address indexed to, uint256 amount);
    event ContractAddressUpdated(
        string indexed identifier, address indexed previousContractAddress, address indexed newContractAddress
    );
    event TokenAddressUpdated(
        string indexed identifier, address indexed previousTokenAddress, address indexed newTokenAddress
    );
    event UniswapV3PoolUpdated(
        string indexed identifier, address indexed newUniswapV3PoolAddress, uint24 indexed newUniswapV3PoolFee
    );
    event HealthFactorTargetUpdated(uint16 previousHealthFactorTarget, uint16 newHealthFactorTarget);
    event SlippageToleranceUpdated(uint16 previousSlippageTolerance, uint16 newSlippageTolerance);

    // ================================================================
    // │                    FUNCTIONS - INITIALIZER                   │
    // ================================================================
    function initialize(
        address owner,
        ContractAddress[] memory contractAddresses,
        TokenAddress[] memory tokenAddresses,
        UniswapV3Pool[] memory uniswapV3Pools,
        uint16 initialHealthFactorTarget,
        uint16 initialSlippageTolerance,
        uint16 initialManagerDailyInvocationLimit
    ) external;

    // ================================================================
    // │                     FUNCTIONS - UPDATES                      │
    // ================================================================
    function updateContractAddress(string memory identifier, address newContractAddress) external;
    function updateTokenAddress(string memory identifier, address newTokenAddress) external;
    function updateUniswapV3Pool(string memory identifier, address newUniswapV3PoolAddress, uint24 newUniswapV3PoolFee)
        external;
    function updateHealthFactorTarget(uint16 healthFactorTarget) external;
    function updateSlippageTolerance(uint16 slippageTolerance) external;
    function updateManagerDailyInvocationLimit(uint16 _managerDailyInvocationLimit) external;

    // ================================================================
    // │                   FUNCTIONS - CORE FUNCTIONS                 │
    // ================================================================
    function rebalance() external returns (uint256 repaymentAmountUSDC);
    function reinvest() external returns (uint256 reinvestedDebt);
    function deleverage() external;
    function aaveSupplyFromContractBalance() external returns (uint256 suppliedCollateral);
    function aaveRepayUSDCFromContractBalance() external;

    /// TODO: Move to different heading
    function delegateCallHelper(string memory _targetIdentifier, string memory _functionSignature, bytes memory _args)
        external
        returns (bytes memory);

    // ================================================================
    // │                FUNCTIONS - WITHDRAW FUNCTIONS                │
    // ================================================================
    function rescueEth(address ownerAddress) external;
    function withdrawTokensFromContractBalance(string memory identifier, address ownerAddress) external;
    function aaveWithdrawWstETH(uint256 withdrawAmount, address ownerAddress)
        external
        returns (uint256 collateralDeltaBase);
    function aaveBorrowAndWithdrawUSDC(uint256 borrowAmount, address ownerAddress) external;
    function aaveClosePosition(address ownerAddress) external;

    // ================================================================
    // │                       FUNCTIONS - GETTERS                    │
    // ================================================================
    function getCreator() external view returns (address creator);
    function getUpgradeHistory() external view returns (UpgradeHistory[] memory);
    function getVersion() external pure returns (string memory version);
    function getContractAddress(string memory) external view returns (address contractAddress);
    function getTokenAddress(string memory) external view returns (address tokenAddress);
    function getUniswapV3Pool(string memory)
        external
        view
        returns (address uniswapV3PoolAddress, uint24 uniswapV3PoolFee);
    function getHealthFactorTarget() external view returns (uint16 healthFactorTarget);
    function getHealthFactorTargetMinimum() external pure returns (uint16 healthFactorTargetMinimum);
    function getSlippageTolerance() external view returns (uint16 slippageTolerance);
    function getSlippageToleranceMaximum() external pure returns (uint16 slippageToleranceMaximum);
    function getManagerDailyInvocationLimit() external view returns (uint16 managerDailyInvocationLimit);
    function getManagerInvocationTimestamps() external view returns (uint64[] memory);
    function getContractBalance(string memory identifier) external view returns (uint256 contractBalance);
    function getRoleMembers(string memory roleString) external view returns (address[] memory);
    function getWithdrawnUSDCTotal() external view returns (uint256 withdrawnUSDCTotal);
    function getReinvestedDebtTotal() external view returns (uint256 reinvestedDebtTotal);
    function getTotalCollateralDelta() external returns (uint256 totalCollateralDelta, bool isPositive);
    function getSuppliedCollateralTotal() external view returns (uint256 depositedCollateralTotal);
    function getMaxBorrowAndWithdrawUSDCAmount() external view returns (uint256 maxBorrowAndWithdrawUSDCAmount);
    function getReinvestableAmount() external returns (uint256 reinvestableAmount);

    // ================================================================
    // │             INHERITED FUNCTIONS - ACCESS CONTROLS            │
    // ================================================================
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function renounceRole(bytes32 role, address callerConfirmation) external;
    function revokeRole(bytes32 role, address account) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    // ================================================================
    // │                 INHERITED FUNCTIONS - UPGRADES               │
    // ================================================================
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    // ================================================================
    // │             INHERITED FUNCTIONS - AAVE FLASH LOAN            │
    // ================================================================
    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata params)
        external
        returns (bool);
}
