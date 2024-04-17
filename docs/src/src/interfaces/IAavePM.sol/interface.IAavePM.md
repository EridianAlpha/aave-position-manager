# IAavePM
[Git Source](https://github.com/EridianAlpha/aave-position-manager/blob/ba6b1569c02e837921dd63705134a5fdb42edeb3/src/interfaces/IAavePM.sol)

This interface defines the essential structures and functions for the AavePM contract.


## Functions
### initialize


```solidity
function initialize(
    address owner,
    ContractAddress[] memory contractAddresses,
    TokenAddress[] memory tokenAddresses,
    address uniswapV3WstETHETHPoolAddress,
    uint24 uniswapV3WstETHETHPoolFee,
    uint256 initialHealthFactorTarget
) external;
```

### updateAave


```solidity
function updateAave(address _aave) external;
```

### updateUniswapV3Router


```solidity
function updateUniswapV3Router(address _uniswapV3Router) external;
```

### updateWETH9


```solidity
function updateWETH9(address _WETH9) external;
```

### updateWstETH


```solidity
function updateWstETH(address _wstETH) external;
```

### updateUSDC


```solidity
function updateUSDC(address _USDC) external;
```

### updateHealthFactorTarget


```solidity
function updateHealthFactorTarget(uint256 _healthFactorTarget) external;
```

### receiveEth


```solidity
function receiveEth() external payable;
```

### rescueEth


```solidity
function rescueEth(address rescueAddress) external;
```

### swapETHToWstETH


```solidity
function swapETHToWstETH() external returns (uint256 amountOut);
```

### getCreator


```solidity
function getCreator() external view returns (address);
```

### getVersion


```solidity
function getVersion() external pure returns (string memory);
```

### getRoleHash


```solidity
function getRoleHash(string memory) external pure returns (bytes32);
```

### getContractAddress


```solidity
function getContractAddress(string memory) external view returns (address);
```

### getTokenAddress


```solidity
function getTokenAddress(string memory) external view returns (address);
```

### getHealthFactorTarget


```solidity
function getHealthFactorTarget() external view returns (uint256);
```

### getHealthFactorMinimum


```solidity
function getHealthFactorMinimum() external view returns (uint256);
```

### getRescueEthBalance


```solidity
function getRescueEthBalance() external view returns (uint256);
```

## Events
### EthRescued

```solidity
event EthRescued(address indexed to, uint256 amount);
```

### AaveUpdated

```solidity
event AaveUpdated(address indexed previousAaveAddress, address indexed newAaveAddress);
```

### UniswapV3RouterUpdated

```solidity
event UniswapV3RouterUpdated(address indexed previousUniswapV3RouterAddress, address indexed newUniswapV3RouterAddress);
```

### WETH9Updated

```solidity
event WETH9Updated(address indexed previousWETH9Address, address indexed newWETH9Address);
```

### WstETHUpdated

```solidity
event WstETHUpdated(address indexed previousWstETHAddress, address indexed newWstETHAddress);
```

### USDCUpdated

```solidity
event USDCUpdated(address indexed previousUSDCAddress, address indexed newUSDCAddress);
```

### HealthFactorTargetUpdated

```solidity
event HealthFactorTargetUpdated(uint256 previousHealthFactorTarget, uint256 newHealthFactorTarget);
```

## Errors
### AavePM__FunctionDoesNotExist

```solidity
error AavePM__FunctionDoesNotExist();
```

### AavePM__RescueEthFailed

```solidity
error AavePM__RescueEthFailed();
```

### AavePM__RescueAddressNotAnOwner

```solidity
error AavePM__RescueAddressNotAnOwner();
```

### AavePM__HealthFactorUnchanged

```solidity
error AavePM__HealthFactorUnchanged();
```

### AavePM__HealthFactorBelowMinimum

```solidity
error AavePM__HealthFactorBelowMinimum();
```

## Structs
### ContractAddress

```solidity
struct ContractAddress {
    string identifier;
    address contractAddress;
}
```

### TokenAddress

```solidity
struct TokenAddress {
    string identifier;
    address tokenAddress;
}
```

### UniswapV3Pool

```solidity
struct UniswapV3Pool {
    address poolAddress;
    uint24 fee;
}
```

