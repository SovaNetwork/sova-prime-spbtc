# IRoleManager
[Git Source](https://github.com/SovaNetwork/fountfi/blob/a2137abe6629a13ef56e85f61ccb9fcfe0d3f27a/src/auth/IRoleManager.sol)

Interface for the RoleManager contract


## Functions
### grantRole

Grants a role to a user


```solidity
function grantRole(address user, uint256 role) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user to grant the role to|
|`role`|`uint256`|The role to grant|


### revokeRole

Revokes a role from a user


```solidity
function revokeRole(address user, uint256 role) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user to revoke the role from|
|`role`|`uint256`|The role to revoke|


### setRoleAdmin

Sets the specific role required to manage a target role.

*Requires the caller to have the PROTOCOL_ADMIN role or be the owner.*


```solidity
function setRoleAdmin(uint256 targetRole, uint256 adminRole) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`targetRole`|`uint256`|The role whose admin role is to be set. Cannot be PROTOCOL_ADMIN.|
|`adminRole`|`uint256`|The role that will be required to manage the targetRole. Set to 0 to require owner/PROTOCOL_ADMIN.|


