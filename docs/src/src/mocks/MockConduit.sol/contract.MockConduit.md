# MockConduit
[Git Source](https://github.com/SovaNetwork/fountfi/blob/a2137abe6629a13ef56e85f61ccb9fcfe0d3f27a/src/mocks/MockConduit.sol)

Simple mock implementation of conduit for testing


## Functions
### collectDeposit

Simulates collecting deposits, just transfers tokens directly


```solidity
function collectDeposit(address token, address from, address to, uint256 amount) external returns (bool);
```

