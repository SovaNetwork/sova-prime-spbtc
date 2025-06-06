# MockReporter
[Git Source](https://github.com/SovaNetwork/fountfi/blob/a2137abe6629a13ef56e85f61ccb9fcfe0d3f27a/src/mocks/MockReporter.sol)

**Inherits:**
[BaseReporter](/src/reporter/BaseReporter.sol/abstract.BaseReporter.md)

A simple reporter implementation for testing


## State Variables
### _value

```solidity
uint256 private _value;
```


## Functions
### constructor


```solidity
constructor(uint256 initialValue);
```

### setValue

Set a new value for the reporter


```solidity
function setValue(uint256 newValue) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newValue`|`uint256`|The new value to report|


### report

Report the current value


```solidity
function report() external view override returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The encoded current value|


