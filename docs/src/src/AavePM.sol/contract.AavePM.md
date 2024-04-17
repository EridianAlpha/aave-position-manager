# AavePM
[Git Source](https://github.com/EridianAlpha/aave-position-manager/blob/ba6b1569c02e837921dd63705134a5fdb42edeb3/src/AavePM.sol)

**Inherits:**
[IAavePM](/src/interfaces/IAavePM.sol/interface.IAavePM.md), Initializable, AccessControlUpgradeable, UUPSUpgradeable

**Author:**
EridianAlpha

A contract to manage positions on Aave.


## State Variables
### s_creator

```solidity
address private s_creator;
```


### s_contractAddresses

```solidity
mapping(string => address) s_contractAddresses;
```


### s_tokenAddresses

```solidity
mapping(string => address) s_tokenAddresses;
```


### s_healthFactorTarget

```solidity
uint256 private s_healthFactorTarget;
```


### s_healthFactorMinimum

```solidity
uint256 private s_healthFactorMinimum;
```


### s_uniswapV3WstETHETHPool

```solidity
UniswapV3Pool private s_uniswapV3WstETHETHPool;
```


### VERSION

```solidity
string private constant VERSION = "0.0.1";
```


### OWNER_ROLE

```solidity
bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");
```


### MANAGER_ROLE

```solidity
bytes32 private constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
```


### UNISWAPV3_WSTETH_ETH_POOL_SLIPPAGE

```solidity
uint256 private constant UNISWAPV3_WSTETH_ETH_POOL_SLIPPAGE = 200;
```


## Functions
### constructor


```solidity
constructor();
```

### receive


```solidity
receive() external payable;
```

### fallback


```solidity
fallback() external payable;
```

### initialize


```solidity
function initialize(
    address owner,
    ContractAddress[] memory contractAddresses,
    TokenAddress[] memory tokenAddresses,
    address uniswapV3WstETHETHPoolAddress,
    uint24 uniswapV3WstETHETHPoolFee,
    uint256 initialHealthFactorTarget
) public initializer;
```

### _authorizeUpgrade

Internal function to authorize an upgrade.

*Only callable by the owner role.*


```solidity
function _authorizeUpgrade(address _newImplementation) internal override onlyRole(OWNER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newImplementation`|`address`|Address of the new contract implementation.|


### updateAave

Update the Aave contract address.

*Only the contract owner can call this function.
Emits an AaveUpdated event.*


```solidity
function updateAave(address _aave) external onlyRole(OWNER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_aave`|`address`|The new Aave contract address.|


### updateUniswapV3Router

Update the UniswapV3Router contract address.

*Only the contract owner can call this function.
Emits an UniswapV3RouterUpdated event.*


```solidity
function updateUniswapV3Router(address _uniswapV3Router) external onlyRole(OWNER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_uniswapV3Router`|`address`|The new UniswapV3Router contract address.|


### updateWETH9

Update the WETH9 contract address.

*Only the contract owner can call this function.
Emits a WETH9Updated event.*


```solidity
function updateWETH9(address _WETH9) external onlyRole(OWNER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_WETH9`|`address`|The new WETH9 contract address.|


### updateWstETH

Update the wstETH contract address.

*Only the contract owner can call this function.
Emits an WstETHUpdated event.*


```solidity
function updateWstETH(address _wstETH) external onlyRole(OWNER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_wstETH`|`address`|The new wstETH contract address.|


### updateUSDC

Update the USDC contract address.

*Only the contract owner can call this function.
Emits an USDCUpdated event.*


```solidity
function updateUSDC(address _USDC) external onlyRole(OWNER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_USDC`|`address`|The new USDC contract address.|


### updateHealthFactorTarget

Update the Health Factor target.

*Only the contract owner can call this function.
Emits a HealthFactorTargetUpdated event.*


```solidity
function updateHealthFactorTarget(uint256 _healthFactorTarget) external onlyRole(OWNER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_healthFactorTarget`|`uint256`|The new Health Factor target.|


### receiveEth


```solidity
function receiveEth() external payable;
```

### rescueEth

Rescue all ETH from the contract.

*This function is intended for emergency use.
In normal operation, the contract shouldn't hold ETH,
as it is used to swap for wstETH.
It can be called without an argument to rescue the entire balance.
Only the contract owner can call this function.
The use of nonReentrant isn't required due to the owner-only restriction.
Throws `AavePM__RescueEthFailed` if the ETH transfer fails.
Emits a RescueEth event.*


```solidity
function rescueEth(address rescueAddress) external onlyRole(OWNER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rescueAddress`|`address`|The address to send the rescued ETH to.|


### swapETHToWstETH


```solidity
function swapETHToWstETH() public onlyRole(MANAGER_ROLE) returns (uint256 amountOut);
```

### getCreator

Getter function to get the i_creator address.

*Public function to allow anyone to view the contract creator.*


```solidity
function getCreator() public view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address of the creator.|


### getVersion


```solidity
function getVersion() public pure returns (string memory);
```

### getRoleHash


```solidity
function getRoleHash(string memory role) public pure returns (bytes32);
```

### getContractAddress

Generic getter function to get the contract address for a given identifier.

*Public function to allow anyone to view the contract address for the given identifier.*


```solidity
function getContractAddress(string memory identifier) public view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`identifier`|`string`|The identifier for the contract address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address of the contract corresponding to the given identifier.|


### getTokenAddress

Generic getter function to get the token address for a given identifier.

*Public function to allow anyone to view the token address for the given identifier.*


```solidity
function getTokenAddress(string memory identifier) public view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`identifier`|`string`|The identifier for the contract address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address of the token corresponding to the given identifier.|


### getHealthFactorTarget

Getter function to get the Health Factor target.

*Public function to allow anyone to view the Health Factor target value.*


```solidity
function getHealthFactorTarget() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 of the Health Factor target.|


### getHealthFactorMinimum

Getter function to get the Health Factor minimum.

*Public function to allow anyone to view the Health Factor minimum value.*


```solidity
function getHealthFactorMinimum() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 of the Health Factor minimum.|


### getRescueEthBalance

Getter function to get the contract's ETH balance.

*Public function to allow anyone to view the contract's ETH balance.*


```solidity
function getRescueEthBalance() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 of the contract's ETH balance.|


