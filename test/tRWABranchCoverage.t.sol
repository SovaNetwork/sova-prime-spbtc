// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {IHook} from "../src/hooks/IHook.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockRegistry} from "../src/mocks/MockRegistry.sol";
import {MockConduit} from "../src/mocks/MockConduit.sol";
import {MockRoleManager} from "../src/mocks/MockRoleManager.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";

/**
 * @title tRWABranchCoverageTest
 * @notice Additional tests to achieve 100% branch coverage for tRWA.sol
 */
contract tRWABranchCoverageTest is Test {
    tRWA public token;
    TestStrategy public strategy;
    MockERC20 public usdc;
    MockRegistry public registry;
    MockConduit public conduit;
    MockRoleManager public roleManager;
    
    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    
    // Hook operation types
    bytes32 public constant OP_DEPOSIT = keccak256("DEPOSIT_OPERATION");
    bytes32 public constant OP_WITHDRAW = keccak256("WITHDRAW_OPERATION");
    bytes32 public constant OP_TRANSFER = keccak256("TRANSFER_OPERATION");
    
    function setUp() public {
        // Deploy mocks
        usdc = new MockERC20("USDC", "USDC", 6);
        roleManager = new MockRoleManager(owner);
        registry = new MockRegistry();
        conduit = new MockConduit();
        strategy = new TestStrategy();
        
        // Set up registry
        registry.setConduit(address(conduit));
        
        // Set registry on strategy
        strategy.setRegistry(address(registry));
        
        // Initialize strategy which will deploy its own token
        strategy.initialize("Test RWA", "tRWA", address(roleManager), owner, address(usdc), 6, "");
        
        // Get the deployed token
        token = tRWA(strategy.sToken());
        
        // Fund users
        deal(address(usdc), alice, 1000000 * 10**6);
        deal(address(usdc), bob, 1000000 * 10**6);
        
        // Approve conduit
        vm.prank(alice);
        usdc.approve(address(conduit), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(conduit), type(uint256).max);
    }
    
    /**
     * @notice Test deposit when hook rejects
     * @dev Covers branch: if (!hookOutput.approved) in _deposit
     */
    function test_Deposit_HookRejects() public {
        // Deploy a rejecting hook
        RejectingHook rejectHook = new RejectingHook();
        
        // Add hook
        vm.prank(address(strategy));
        token.addOperationHook(OP_DEPOSIT, address(rejectHook));
        
        // Try to deposit
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(tRWA.HookCheckFailed.selector, "Deposit rejected"));
        token.deposit(100 * 10**6, alice);
    }
    
    /**
     * @notice Test withdraw when hook rejects
     * @dev Covers branch: if (!hookOutput.approved) in _withdraw
     */
    function test_Withdraw_HookRejects() public {
        // First deposit some funds
        vm.prank(alice);
        token.deposit(100 * 10**6, alice);
        
        // Deploy a rejecting hook for withdrawals
        RejectingHook rejectHook = new RejectingHook();
        
        // Add hook
        vm.prank(address(strategy));
        token.addOperationHook(OP_WITHDRAW, address(rejectHook));
        
        // Try to withdraw
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(tRWA.HookCheckFailed.selector, "Withdraw rejected"));
        token.withdraw(50 * 10**6, alice, alice);
    }
    
    /**
     * @notice Test withdraw with allowance (by != owner)
     * @dev Covers branch: if (by != owner) _spendAllowance
     */
    function test_Withdraw_WithAllowance() public {
        // First deposit some funds
        vm.prank(alice);
        token.deposit(100 * 10**6, alice);
        
        // Alice approves bob to withdraw
        vm.prank(alice);
        token.approve(bob, 50 * 10**18);
        
        // Fund token (not strategy) with USDC for withdrawal
        deal(address(usdc), address(token), 100 * 10**6);
        
        // Bob withdraws on behalf of alice
        vm.prank(bob);
        token.withdraw(50 * 10**6, bob, alice);
        
        // Check balances
        assertEq(usdc.balanceOf(bob), 1000050 * 10**6);
    }
    
    /**
     * @notice Test withdraw more than max
     * @dev Covers branch: if (shares > balanceOf(owner))
     */
    function test_Withdraw_MoreThanMax() public {
        // First deposit some funds
        vm.prank(alice);
        token.deposit(100 * 10**6, alice);
        
        uint256 aliceShares = token.balanceOf(alice);
        
        // Try to withdraw more shares than alice has
        vm.prank(alice);
        vm.expectRevert(ERC4626.RedeemMoreThanMax.selector);
        token.redeem(aliceShares + 1, alice, alice);
    }
    
    /**
     * @notice Test removing hook with invalid index
     * @dev Covers branch: if (index >= opHooks.length)
     */
    function test_RemoveHook_InvalidIndex() public {
        // Add one hook
        MockHook hook = new MockHook();
        vm.prank(address(strategy));
        token.addOperationHook(OP_DEPOSIT, address(hook));
        
        // Try to remove at invalid index
        vm.prank(address(strategy));
        vm.expectRevert(tRWA.HookIndexOutOfBounds.selector);
        token.removeOperationHook(OP_DEPOSIT, 1); // Only index 0 exists
    }
    
    /**
     * @notice Test removing hook that has processed operations
     * @dev Covers branch: if (opHooks[index].hasProcessedOperations)
     */
    function test_RemoveHook_HasProcessedOperations() public {
        // Add hook
        MockHook hook = new MockHook();
        vm.prank(address(strategy));
        token.addOperationHook(OP_DEPOSIT, address(hook));
        
        // Process a deposit to mark hook as having processed operations
        vm.prank(alice);
        token.deposit(100 * 10**6, alice);
        
        // Try to remove the hook
        vm.prank(address(strategy));
        vm.expectRevert(tRWA.HookHasProcessedOperations.selector);
        token.removeOperationHook(OP_DEPOSIT, 0);
    }
    
    /**
     * @notice Test reordering hooks with invalid length
     * @dev Covers branch: if (newOrderIndices.length != numHooks)
     */
    function test_ReorderHooks_InvalidLength() public {
        // Add two hooks
        MockHook hook1 = new MockHook();
        MockHook hook2 = new MockHook();
        vm.startPrank(address(strategy));
        token.addOperationHook(OP_DEPOSIT, address(hook1));
        token.addOperationHook(OP_DEPOSIT, address(hook2));
        
        // Try to reorder with wrong length array
        uint256[] memory indices = new uint256[](1); // Should be 2
        indices[0] = 0;
        
        vm.expectRevert(tRWA.ReorderInvalidLength.selector);
        token.reorderOperationHooks(OP_DEPOSIT, indices);
        vm.stopPrank();
    }
    
    /**
     * @notice Test reordering hooks with out of bounds index
     * @dev Covers branch: if (oldIndex >= numHooks)
     */
    function test_ReorderHooks_IndexOutOfBounds() public {
        // Add two hooks
        MockHook hook1 = new MockHook();
        MockHook hook2 = new MockHook();
        vm.startPrank(address(strategy));
        token.addOperationHook(OP_DEPOSIT, address(hook1));
        token.addOperationHook(OP_DEPOSIT, address(hook2));
        
        // Try to reorder with out of bounds index
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 2; // Out of bounds
        
        vm.expectRevert(tRWA.ReorderIndexOutOfBounds.selector);
        token.reorderOperationHooks(OP_DEPOSIT, indices);
        vm.stopPrank();
    }
    
    /**
     * @notice Test reordering hooks with duplicate index
     * @dev Covers branch: if (indexSeen[oldIndex])
     */
    function test_ReorderHooks_DuplicateIndex() public {
        // Add two hooks
        MockHook hook1 = new MockHook();
        MockHook hook2 = new MockHook();
        vm.startPrank(address(strategy));
        token.addOperationHook(OP_DEPOSIT, address(hook1));
        token.addOperationHook(OP_DEPOSIT, address(hook2));
        
        // Try to reorder with duplicate index
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 0; // Duplicate
        
        vm.expectRevert(tRWA.ReorderDuplicateIndex.selector);
        token.reorderOperationHooks(OP_DEPOSIT, indices);
        vm.stopPrank();
    }
    
    /**
     * @notice Test transfer when no hooks registered
     * @dev Covers branch: if (opHooks.length > 0) optimization
     */
    function test_Transfer_NoHooks() public {
        // First deposit some funds
        vm.prank(alice);
        token.deposit(100 * 10**6, alice);
        
        // Transfer without any transfer hooks
        vm.prank(alice);
        token.transfer(bob, 50 * 10**18);
        
        // Check balances
        assertEq(token.balanceOf(bob), 50 * 10**18);
    }
    
    /**
     * @notice Test transfer when hook rejects
     * @dev Covers branch: if (!hookOutput.approved) in _beforeTokenTransfer
     */
    function test_Transfer_HookRejects() public {
        // First deposit some funds
        vm.prank(alice);
        token.deposit(100 * 10**6, alice);
        
        // Deploy a rejecting hook for transfers
        RejectingHook rejectHook = new RejectingHook();
        
        // Add hook
        vm.prank(address(strategy));
        token.addOperationHook(OP_TRANSFER, address(rejectHook));
        
        // Try to transfer
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(tRWA.HookCheckFailed.selector, "Transfer rejected"));
        token.transfer(bob, 50 * 10**18);
    }
}

/**
 * @title MockHook
 * @notice Simple hook that always approves operations
 */
contract MockHook is IHook {
    function onBeforeDeposit(
        address token,
        address from,
        uint256 assets,
        address receiver
    ) external pure override returns (HookOutput memory) {
        return HookOutput(true, "");
    }
    
    function onBeforeWithdraw(
        address token,
        address operator,
        uint256 assets,
        address receiver,
        address owner
    ) external pure override returns (HookOutput memory) {
        return HookOutput(true, "");
    }
    
    function onBeforeTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) external pure override returns (HookOutput memory) {
        return HookOutput(true, "");
    }
    
    function hookName() external pure override returns (string memory) {
        return "MockHook";
    }
    
    function hookId() external pure override returns (bytes32) {
        return keccak256("MockHook");
    }
}

/**
 * @title RejectingHook
 * @notice Hook that always rejects operations
 */
contract RejectingHook is IHook {
    function onBeforeDeposit(
        address token,
        address from,
        uint256 assets,
        address receiver
    ) external pure override returns (HookOutput memory) {
        return HookOutput(false, "Deposit rejected");
    }
    
    function onBeforeWithdraw(
        address token,
        address operator,
        uint256 assets,
        address receiver,
        address owner
    ) external pure override returns (HookOutput memory) {
        return HookOutput(false, "Withdraw rejected");
    }
    
    function onBeforeTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) external pure override returns (HookOutput memory) {
        return HookOutput(false, "Transfer rejected");
    }
    
    function hookName() external pure override returns (string memory) {
        return "RejectingHook";
    }
    
    function hookId() external pure override returns (bytes32) {
        return keccak256("RejectingHook");
    }
}

/**
 * @title TestStrategy
 * @notice Strategy contract that properly implements registry() method
 */
contract TestStrategy is MockStrategy {
    address public _registry;
    
    function registry() external view override returns (address) {
        return _registry;
    }
    
    function setRegistry(address reg) external {
        _registry = reg;
    }
}