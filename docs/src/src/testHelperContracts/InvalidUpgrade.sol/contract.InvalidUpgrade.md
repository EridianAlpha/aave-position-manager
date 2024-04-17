# InvalidUpgrade
[Git Source](https://github.com/EridianAlpha/aave-position-manager/blob/ba6b1569c02e837921dd63705134a5fdb42edeb3/src/testHelperContracts/InvalidUpgrade.sol)

This contract is used to test uups upgrade to an invalid contract

*The contact is not a valid upgradeable contract so the test should fail*


## State Variables
### VERSION

```solidity
string private constant VERSION = "INVALID_UPGRADE";
```


## Functions
### getVersion


```solidity
function getVersion() public pure returns (string memory);
```

