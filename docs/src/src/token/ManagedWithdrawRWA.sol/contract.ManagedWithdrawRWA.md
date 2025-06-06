# ManagedWithdrawRWA
[Git Source](https://github.com/SovaNetwork/fountfi/blob/a2137abe6629a13ef56e85f61ccb9fcfe0d3f27a/src/token/ManagedWithdrawRWA.sol)

**Inherits:**
[tRWA](/src/token/tRWA.sol/contract.tRWA.md)

Extension of tRWA that implements manager-initiated withdrawals


## Functions
### constructor

Constructor


```solidity
constructor(string memory name_, string memory symbol_, address asset_, uint8 assetDecimals_, address strategy_)
    tRWA(name_, symbol_, asset_, assetDecimals_, strategy_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`|Token name|
|`symbol_`|`string`|Token symbol|
|`asset_`|`address`|Asset address|
|`assetDecimals_`|`uint8`|Decimals of the asset token|
|`strategy_`|`address`|Strategy address|


### redeem

Redeem shares from the strategy with minimum assets check


```solidity
function redeem(uint256 shares, address to, address owner, uint256 minAssets)
    public
    onlyStrategy
    returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The amount of shares to redeem|
|`to`|`address`|The address to send the assets to|
|`owner`|`address`|The owner of the shares|
|`minAssets`|`uint256`|The minimum amount of assets to receive|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets received|


### batchRedeemShares

Process a batch of user-requested withdrawals with minimum assets check


```solidity
function batchRedeemShares(
    uint256[] calldata shares,
    address[] calldata to,
    address[] calldata owner,
    uint256[] calldata minAssets
) external onlyStrategy nonReentrant returns (uint256[] memory assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256[]`|The amount of shares to redeem|
|`to`|`address[]`|The address to send the assets to|
|`owner`|`address[]`|The owner of the shares|
|`minAssets`|`uint256[]`|The minimum amount of assets for each withdrawal|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256[]`|The amount of assets received|


### withdraw

Withdraw assets from the strategy - must be called by the manager

*Use redeem instead - all accounting is share-based*


```solidity
function withdraw(uint256, address, address) public view override onlyStrategy returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|shares The amount of shares burned|


### redeem

Redeem shares from the strategy - must be called by the manager


```solidity
function redeem(uint256 shares, address to, address owner) public override onlyStrategy returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The amount of shares to redeem|
|`to`|`address`|The address to send the assets to|
|`owner`|`address`|The owner of the shares|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets received|


### _withdraw

Override _withdraw to skip transferAssets since we already collected


```solidity
function _withdraw(address by, address to, address owner, uint256 assets, uint256 shares)
    internal
    override
    nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`by`|`address`|Address initiating the withdrawal|
|`to`|`address`|Address receiving the assets|
|`owner`|`address`|Address that owns the shares|
|`assets`|`uint256`|Amount of assets to withdraw|
|`shares`|`uint256`|Amount of shares to burn|


## Errors
### UseRedeem

```solidity
error UseRedeem();
```

### InvalidArrayLengths

```solidity
error InvalidArrayLengths();
```

### InsufficientOutputAssets

```solidity
error InsufficientOutputAssets();
```

