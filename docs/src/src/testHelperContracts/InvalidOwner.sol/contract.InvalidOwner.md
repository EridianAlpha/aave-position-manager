# InvalidOwner
[Git Source](https://github.com/EridianAlpha/aave-position-manager/blob/ba6b1569c02e837921dd63705134a5fdb42edeb3/src/testHelperContracts/InvalidOwner.sol)

This contract is used to test the .call functions failing in AavePM.sol

*The test is found in AavePMTest.t.sol:
- "test_RescueEthCallFailureThrowsError()"
The reason this contract causes the .call to fail is because it doesn't have a receive()
or fallback() function so the ETH can't be accepted.*


## State Variables
### aavePM

```solidity
AavePM aavePM;
```


## Functions
### constructor


```solidity
constructor(address aavePMAddress);
```

### aavePMRescueAllETH


```solidity
function aavePMRescueAllETH() public payable;
```

