# GatedMintReportedStrategy
[Git Source](https://github.com/SovaNetwork/fountfi/blob/a2137abe6629a13ef56e85f61ccb9fcfe0d3f27a/src/strategy/GatedMintRWAStrategy.sol)

**Inherits:**
[ReportedStrategy](/src/strategy/ReportedStrategy.sol/contract.ReportedStrategy.md)

Extension of ReportedStrategy that deploys and configures GatedMintRWA tokens


## Functions
### _deployToken

Deploy a new GatedMintRWA token


```solidity
function _deployToken(string calldata name_, string calldata symbol_, address asset_, uint8 assetDecimals_)
    internal
    virtual
    override
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`|Name of the token|
|`symbol_`|`string`|Symbol of the token|
|`asset_`|`address`|Address of the underlying asset|
|`assetDecimals_`|`uint8`|Decimals of the asset|


