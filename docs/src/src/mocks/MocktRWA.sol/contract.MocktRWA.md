# MocktRWA
[Git Source](https://github.com/SovaNetwork/fountfi/blob/a2137abe6629a13ef56e85f61ccb9fcfe0d3f27a/src/mocks/MocktRWA.sol)

**Inherits:**
[tRWA](/src/token/tRWA.sol/contract.tRWA.md)

Mock tRWA token that implements burn for testing


## Functions
### constructor


```solidity
constructor(string memory name_, string memory symbol_, address asset_, uint8 assetDecimals_, address strategy_)
    tRWA(name_, symbol_, asset_, assetDecimals_, strategy_);
```

### burn

Utility function to burn tokens - ONLY FOR TESTING


```solidity
function burn(address from, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address to burn from|
|`amount`|`uint256`|Amount to burn|


