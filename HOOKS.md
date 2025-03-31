# Designing a Hook-Based System for tRWA

A hook-based system would allow the tRWA contract to become highly extensible while maintaining its core functionality. This design aligns with the existing architecture of the codebase.

## 1. Hook Interface

Define a standard interface for hooks that can be registered with the tRWA token:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title ItRWAHook
 * @notice Interface for hooks that can extend tRWA token functionality
 * @dev All hooks must implement this interface to be registered with a tRWA token
 */
interface ItRWAHook {
    /**
     * @notice Hook evaluation result struct
     * @param success Whether the hook operation succeeded
     * @param message Additional information about the result
     */
    struct HookResult {
        bool success;
        string message;
    }

    /**
     * @notice Returns the unique identifier for this hook
     * @return Hook identifier
     */
    function hookId() external view returns (bytes32);

    /**
     * @notice Returns the human readable name of this hook
     * @return Hook name
     */
    function hookName() external view returns (string memory);

    /**
     * @notice Returns the bitmap of operations this hook applies to
     * @return Bitmap of operations (1 = deposit, 2 = withdraw, 4 = transfer)
     */
    function appliesTo() external view returns (uint256);

    // Pre-operation hooks - return false to prevent the operation
    function beforeDeposit(address user, uint256 assets, address receiver) external returns (HookResult memory);
    function beforeWithdraw(address user, uint256 assets, address receiver, address owner) external returns (HookResult memory);
    function beforeTransfer(address from, address to, uint256 amount) external returns (HookResult memory);

    // Post-operation hooks - these cannot prevent the operation but can perform additional actions
    function afterDeposit(address user, uint256 assets, address receiver, uint256 shares) external;
    function afterWithdraw(address user, uint256 assets, address receiver, address owner, uint256 shares) external;
    function afterTransfer(address from, address to, uint256 amount) external;
}
```

## 2. Hook Registry Contract

Create a registry contract for hooks that follows the pattern of the existing Registry contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "solady/auth/Ownable.sol";
import {ItRWAHook} from "./ItRWAHook.sol";

/**
 * @title HookRegistry
 * @notice Registry for tRWA hooks
 * @dev Maintains a list of allowed hook implementations
 */
contract HookRegistry is Ownable {
    // Registry mapping
    mapping(address => bool) public allowedHooks;

    // Events
    event SetHook(address indexed implementation, bool allowed);

    // Errors
    error ZeroAddress();

    /**
     * @notice Constructor
     */
    constructor() {
        _initializeOwner(msg.sender);
    }

    /**
     * @notice Register a hook implementation
     * @param implementation Address of the hook implementation
     * @param allowed Whether the implementation is allowed
     */
    function setHook(address implementation, bool allowed) external onlyOwner {
        if (implementation == address(0)) revert ZeroAddress();
        allowedHooks[implementation] = allowed;
        emit SetHook(implementation, allowed);
    }

    /**
     * @notice Check if a hook is allowed
     * @param hook Address of the hook to check
     * @return Whether the hook is allowed
     */
    function isHookAllowed(address hook) external view returns (bool) {
        return allowedHooks[hook];
    }
}
```

## 3. Extend tRWA Contract

Modify the tRWA contract to support hooks:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IRules} from "../rules/IRules.sol";
import {IStrategy} from "../strategy/IStrategy.sol";
import {ItRWA} from "./ItRWA.sol";
import {ItRWAHook} from "./ItRWAHook.sol";
import {HookRegistry} from "./HookRegistry.sol";

/**
 * @title tRWA
 * @notice Tokenized Real World Asset (tRWA) inheriting ERC4626 standard
 * @dev Each token represents a share in the underlying real-world fund
 */
contract tRWA is ERC4626, ItRWA {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    // Internal storage for token metadata
    uint8 private constant DECIMALS = 18;
    string private _symbol;
    string private _name;
    address private immutable _asset;

    // Logic contracts
    IStrategy public strategy;
    IRules public immutable rules;
    HookRegistry public immutable hookRegistry;

    // Hook management
    mapping(address => bool) public activeHooks;
    address[] public hooks;

    // Events
    event HookAdded(address indexed hook);
    event HookRemoved(address indexed hook);
    event HookExecutionFailed(address indexed hook, string reason);

    // Errors
    error HookAlreadyAdded();
    error HookNotAllowed();
    error HookExecutionError(string reason);

    /**
     * @notice Contract constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param asset_ Asset address
     * @param strategy_ Strategy address
     * @param rules_ Rules address
     * @param hookRegistry_ Hook registry address
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address asset_,
        address strategy_,
        address rules_,
        address hookRegistry_
    ) {
        // Validate configuration parameters
        if (asset_ == address(0)) revert InvalidAddress();
        if (strategy_ == address(0)) revert InvalidAddress();
        if (rules_ == address(0)) revert InvalidAddress();
        if (hookRegistry_ == address(0)) revert InvalidAddress();

        _name = name_;
        _symbol = symbol_;
        _asset = asset_;

        strategy = IStrategy(strategy);
        rules = IRules(rules);
        hookRegistry = HookRegistry(hookRegistry_);

        if (strategy.asset() != _asset) revert AssetMismatch();
    }

    /**
     * @notice Add a hook to the token
     * @param hook Address of the hook to add
     */
    function addHook(address hook) external onlyManager {
        if (!hookRegistry.isHookAllowed(hook)) revert HookNotAllowed();
        if (activeHooks[hook]) revert HookAlreadyAdded();

        activeHooks[hook] = true;
        hooks.push(hook);

        emit HookAdded(hook);
    }

    /**
     * @notice Remove a hook from the token
     * @param hook Address of the hook to remove
     */
    function removeHook(address hook) external onlyManager {
        if (!activeHooks[hook]) return;

        activeHooks[hook] = false;

        // Remove from array
        for (uint256 i = 0; i < hooks.length; i++) {
            if (hooks[i] == hook) {
                hooks[i] = hooks[hooks.length - 1];
                hooks.pop();
                break;
            }
        }

        emit HookRemoved(hook);
    }

    /**
     * @notice Get all active hooks
     * @return Array of active hook addresses
     */
    function getActiveHooks() external view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < hooks.length; i++) {
            if (activeHooks[hooks[i]]) {
                count++;
            }
        }

        address[] memory result = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < hooks.length; i++) {
            if (activeHooks[hooks[i]]) {
                result[index] = hooks[i];
                index++;
            }
        }

        return result;
    }

    // ... existing code ...

    /**
     * @notice Execute pre-deposit hooks
     * @param user Address initiating the deposit
     * @param assets Amount of assets being deposited
     * @param receiver Address receiving the shares
     */
    function _executePreDepositHooks(address user, uint256 assets, address receiver) internal {
        for (uint256 i = 0; i < hooks.length; i++) {
            address hook = hooks[i];
            if (activeHooks[hook] && (ItRWAHook(hook).appliesTo() & 1) != 0) {
                try ItRWAHook(hook).beforeDeposit(user, assets, receiver) returns (ItRWAHook.HookResult memory result) {
                    if (!result.success) {
                        revert HookExecutionError(result.message);
                    }
                } catch Error(string memory reason) {
                    emit HookExecutionFailed(hook, reason);
                    revert HookExecutionError(reason);
                } catch {
                    emit HookExecutionFailed(hook, "Unknown error");
                    revert HookExecutionError("Hook execution failed");
                }
            }
        }
    }

    /**
     * @notice Execute post-deposit hooks
     * @param user Address initiating the deposit
     * @param assets Amount of assets being deposited
     * @param receiver Address receiving the shares
     * @param shares Amount of shares minted
     */
    function _executePostDepositHooks(address user, uint256 assets, address receiver, uint256 shares) internal {
        for (uint256 i = 0; i < hooks.length; i++) {
            address hook = hooks[i];
            if (activeHooks[hook] && (ItRWAHook(hook).appliesTo() & 1) != 0) {
                try ItRWAHook(hook).afterDeposit(user, assets, receiver, shares) {
                    // Success, continue
                } catch Error(string memory reason) {
                    // Log but don't revert
                    emit HookExecutionFailed(hook, reason);
                } catch {
                    // Log but don't revert
                    emit HookExecutionFailed(hook, "Unknown error");
                }
            }
        }
    }

    // Similar functions for withdraw and transfer hooks...

    /**
     * @notice Deposit assets into the token
     * @param by Address of the sender
     * @param to Address of the receiver
     * @param assets Amount of assets to deposit
     * @param shares Amount of shares to mint
     */
    function _deposit(address by, address to, uint256 assets, uint256 shares) internal override {
        // First check rules
        IRules.RuleResult memory result = rules.evaluateDeposit(address(this), by, assets, to);
        if (!result.approved) revert RuleCheckFailed(result.reason);

        // Then execute hooks
        _executePreDepositHooks(by, assets, to);

        // Perform the deposit
        SafeTransferLib.safeTransferFrom(asset(), by, address(this), assets);
        _mint(to, shares);

        emit Deposit(by, to, assets, shares);

        // Execute post hooks
        _executePostDepositHooks(by, assets, to, shares);
    }

    // Similar modifications for withdraw and transfer functions...
}
```

## 4. Modify Registry Contract

Update the Registry contract to include a HookRegistry:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "solady/auth/Ownable.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {IStrategy} from "../strategy/IStrategy.sol";
import {IRules} from "../rules/IRules.sol";
import {HookRegistry} from "../token/HookRegistry.sol";

/**
 * @title Registry
 * @notice Central registry for strategies, rules, assets, and hooks
 * @dev Uses minimal proxy pattern for cloning templates
 */
contract Registry is Ownable {
    using LibClone for address;

    // Registry mappings
    mapping(address => bool) public allowedStrategies;
    mapping(address => bool) public allowedRules;
    mapping(address => bool) public allowedAssets;

    // Hook registry
    HookRegistry public hookRegistry;

    // ... existing code ...

    /**
     * @notice Constructor
     */
    constructor() {
        _initializeOwner(msg.sender);
        hookRegistry = new HookRegistry();
        hookRegistry.transferOwnership(msg.sender);
    }

    // ... existing code plus hook registration ...

    /**
     * @notice Register a hook implementation
     * @param implementation Address of the hook implementation
     * @param allowed Whether the implementation is allowed
     */
    function setHook(address implementation, bool allowed) external onlyOwner {
        hookRegistry.setHook(implementation, allowed);
    }

    /**
     * @notice Deploy a new ReportedStrategy and its associated tRWA token
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _implementation Strategy implementation
     * @param _asset Asset address
     * @param _rules Rules address
     * @param _admin Admin address for the strategy
     * @param _manager Manager address for the strategy
     * @param _initData Initialization data
     * @return strategy Address of the deployed strategy
     * @return token Address of the deployed tRWA token
     */
    function deploy(
        string memory _name,
        string memory _symbol,
        address _implementation,
        address _asset,
        address _rules,
        address _admin,
        address _manager,
        bytes memory _initData
    ) external onlyOwner returns (address strategy, address token) {
        if (!allowedRules[_rules]) revert UnauthorizedRule();
        if (!allowedAssets[_asset]) revert UnauthorizedAsset();
        if (!allowedStrategies[_implementation]) revert UnauthorizedStrategy();

        // Clone the implementation
        strategy = _implementation.clone();

        // Initialize the strategy - modified to include the hook registry
        IStrategy(strategy).initialize(_name, _symbol, _admin, _manager, _asset, _rules, address(hookRegistry), _initData);

        // Register strategy in the factory
        allStrategies.push(strategy);

        // Get the token address
        token = IStrategy(strategy).sToken();

        emit Deploy(strategy, token, _asset);

        return (strategy, token);
    }
}
```

## 5. Example Hook Implementations

### Subscription Hook

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "solady/auth/Ownable.sol";
import {ItRWAHook} from "../token/ItRWAHook.sol";

/**
 * @title SubscriptionHook
 * @notice Implements a subscription system for tRWA deposits
 * @dev Controls which addresses can deposit into the tRWA
 */
contract SubscriptionHook is ItRWAHook, Ownable {
    // Hook configuration
    bytes32 public constant override hookId = keccak256("SubscriptionHook");
    string public constant override hookName = "Subscription Hook";

    // Bitmap of operations this hook applies to (1 = deposit)
    uint256 public constant override appliesTo = 1;

    // State
    address public immutable tRWA;
    mapping(address => bool) public allowedUsers;

    // Events
    event UserAllowed(address indexed user, bool allowed);

    /**
     * @notice Constructor
     * @param _tRWA Address of the tRWA token
     * @param _owner Owner of the hook
     */
    constructor(address _tRWA, address _owner) {
        if (_tRWA == address(0)) revert("Invalid tRWA address");
        if (_owner == address(0)) revert("Invalid owner address");

        tRWA = _tRWA;
        _initializeOwner(_owner);
    }

    /**
     * @notice Allow or disallow a user to deposit
     * @param user Address of the user
     * @param allowed Whether the user is allowed
     */
    function setUserAllowed(address user, bool allowed) external onlyOwner {
        allowedUsers[user] = allowed;
        emit UserAllowed(user, allowed);
    }

    /**
     * @notice Pre-deposit hook
     * @param user Address initiating the deposit
     * @param assets Amount of assets being deposited
     * @param receiver Address receiving the shares
     * @return result Hook evaluation result
     */
    function beforeDeposit(address user, uint256 assets, address receiver) external override returns (HookResult memory) {
        require(msg.sender == tRWA, "Unauthorized");

        if (!allowedUsers[user]) {
            return HookResult({
                success: false,
                message: "User not allowed"
            });
        }

        return HookResult({
            success: true,
            message: ""
        });
    }

    /**
     * @notice Pre-withdraw hook - not used
     */
    function beforeWithdraw(address, uint256, address, address) external pure override returns (HookResult memory) {
        return HookResult({
            success: true,
            message: ""
        });
    }

    /**
     * @notice Pre-transfer hook - not used
     */
    function beforeTransfer(address, address, uint256) external pure override returns (HookResult memory) {
        return HookResult({
            success: true,
            message: ""
        });
    }

    /**
     * @notice Post-deposit hook - not used
     */
    function afterDeposit(address, uint256, address, uint256) external pure override {}

    /**
     * @notice Post-withdraw hook - not used
     */
    function afterWithdraw(address, uint256, address, address, uint256) external pure override {}

    /**
     * @notice Post-transfer hook - not used
     */
    function afterTransfer(address, address, uint256) external pure override {}
}
```

### Analytics Hook

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "solady/auth/Ownable.sol";
import {ItRWAHook} from "../token/ItRWAHook.sol";

/**
 * @title AnalyticsHook
 * @notice Tracks analytics data for tRWA operations
 * @dev Collects data on deposits, withdrawals, and transfers
 */
contract AnalyticsHook is ItRWAHook, Ownable {
    // Hook configuration
    bytes32 public constant override hookId = keccak256("AnalyticsHook");
    string public constant override hookName = "Analytics Hook";

    // Bitmap of operations this hook applies to (1 = deposit, 2 = withdraw, 4 = transfer)
    uint256 public constant override appliesTo = 7; // 1 + 2 + 4

    // State
    address public immutable tRWA;

    // Analytics storage
    mapping(address => uint256) public userDepositCount;
    mapping(address => uint256) public userTotalDeposited;
    mapping(address => uint256) public userWithdrawCount;
    mapping(address => uint256) public userTotalWithdrawn;
    mapping(address => uint256) public userTransferCount;

    uint256 public totalDepositCount;
    uint256 public totalWithdrawCount;
    uint256 public totalTransferCount;

    /**
     * @notice Constructor
     * @param _tRWA Address of the tRWA token
     * @param _owner Owner of the hook
     */
    constructor(address _tRWA, address _owner) {
        if (_tRWA == address(0)) revert("Invalid tRWA address");
        if (_owner == address(0)) revert("Invalid owner address");

        tRWA = _tRWA;
        _initializeOwner(_owner);
    }

    /**
     * @notice Pre-deposit hook - always approves
     */
    function beforeDeposit(address, uint256, address) external view override returns (HookResult memory) {
        require(msg.sender == tRWA, "Unauthorized");
        return HookResult({
            success: true,
            message: ""
        });
    }

    /**
     * @notice Post-deposit hook - records analytics
     */
    function afterDeposit(address user, uint256 assets, address, uint256) external override {
        require(msg.sender == tRWA, "Unauthorized");

        userDepositCount[user]++;
        userTotalDeposited[user] += assets;
        totalDepositCount++;
    }

    // Implement other required functions...

    /**
     * @notice Clear analytics data - admin only
     */
    function clearAnalytics() external onlyOwner {
        totalDepositCount = 0;
        totalWithdrawCount = 0;
        totalTransferCount = 0;
    }
}
```

## 6. Benefits of This Design

1. **Integration with Existing Architecture**: Works with the current tRWA, Strategy, and Rules system.
2. **Extensible Validation**: Hooks provide additional validation beyond the rules system.
3. **Post-Operation Actions**: Enables actions to be performed after operations complete.
4. **Modular Functionality**: Different tokens can have different hooks activated.
5. **Layer Separation**: Clear separation between core token logic, rules, and hooks.
6. **Targeted Extensions**: Hooks can target specific operations (deposit, withdraw, transfer).
7. **Analytics and Monitoring**: Hooks enable non-blocking analytics and event monitoring.
8. **Dynamic Configuration**: Hooks can be added or removed at runtime.

## 7. Implementation Considerations

1. **Gas Optimization**: Iterating over hooks increases gas costs. Consider gas limits per hook.
2. **Failure Handling**: Pre-operation hooks can prevent operations, while post-operation hooks should not revert.
3. **Hook Ordering**: Hook execution order matters. Consider adding priority mechanisms if needed.
4. **Upgradeability**: Hook implementations can be upgraded independently of the tRWA token.
5. **Security**: Hooks need careful security auditing as they can affect token operations.
6. **Testing**: Each hook needs thorough testing with different edge cases.

This design leverages the existing architecture while providing a flexible extension mechanism that can adapt to future requirements.
