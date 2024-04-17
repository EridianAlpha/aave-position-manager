# AavePMUpgradeExample
[Git Source](https://github.com/EridianAlpha/aave-position-manager/blob/ba6b1569c02e837921dd63705134a5fdb42edeb3/src/testHelperContracts/AavePMUpgradeExample.sol)

**Inherits:**
Initializable, AccessControlUpgradeable, UUPSUpgradeable

**Author:**
EridianAlpha

A contract to manage positions on Aave.


## State Variables
### OWNER_ROLE

```solidity
bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");
```


### VERSION

```solidity
string private constant VERSION = "0.0.2";
```


## Functions
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


### getVersion


```solidity
function getVersion() public pure returns (string memory);
```

