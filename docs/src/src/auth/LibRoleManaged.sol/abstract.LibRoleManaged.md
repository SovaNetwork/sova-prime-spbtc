# LibRoleManaged
[Git Source](https://github.com/SovaNetwork/fountfi/blob/a2137abe6629a13ef56e85f61ccb9fcfe0d3f27a/src/auth/LibRoleManaged.sol)

Logical library for role-managed contracts. Can be inherited by
both deployable and cloneable versions of RoleManaged.


## State Variables
### roleManager
The role manager contract


```solidity
RoleManager public roleManager;
```


## Functions
### registry

Get the registry contract


```solidity
function registry() public view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the registry contract|


### onlyRoles

Modifier to restrict access to addresses with a specific role


```solidity
modifier onlyRoles(uint256 role);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`uint256`|The role required to access the function|


## Errors
### UnauthorizedRole

```solidity
error UnauthorizedRole(address caller, uint256 roleRequired);
```

