// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {SovaBTCv1} from "../src/token/SovaBTCv1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }
}

contract SovaBTCv1Test is Test {
    SovaBTCv1 public token;
    SovaBTCv1 public implementation;

    address public admin;
    address public user1;
    address public user2;

    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event TokensRecovered(address indexed token, address indexed to, uint256 amount);

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy implementation
        implementation = new SovaBTCv1();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(SovaBTCv1.initialize.selector, admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        token = SovaBTCv1(address(proxy));
    }

    function test_Initialize() public view {
        assertEq(token.name(), "Sova BTC v1");
        assertEq(token.symbol(), "SOVABTCV1");
        assertEq(token.decimals(), 8);
        assertEq(token.admin(), admin);
        assertEq(token.totalSupply(), 0);
        assertEq(token.version(), "1.0.0");
    }

    function test_Initialize_RevertsIfAdminIsZero() public {
        SovaBTCv1 newImpl = new SovaBTCv1();
        bytes memory initData = abi.encodeWithSelector(SovaBTCv1.initialize.selector, address(0));

        vm.expectRevert(SovaBTCv1.InvalidAddress.selector);
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_Mint() public {
        vm.startPrank(admin);

        vm.expectEmit(true, true, true, true);
        emit Mint(user1, 1000e8);

        token.mint(user1, 1000e8);

        assertEq(token.balanceOf(user1), 1000e8);
        assertEq(token.totalSupply(), 1000e8);
        vm.stopPrank();
    }

    function test_Mint_RevertsIfNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert(SovaBTCv1.Unauthorized.selector);
        token.mint(user1, 1000e8);
    }

    function test_Mint_RevertsIfToIsZero() public {
        vm.prank(admin);
        vm.expectRevert(SovaBTCv1.InvalidAddress.selector);
        token.mint(address(0), 1000e8);
    }

    function test_Burn() public {
        vm.prank(admin);
        token.mint(user1, 1000e8);

        vm.startPrank(user1);

        vm.expectEmit(true, true, true, true);
        emit Burn(user1, 500e8);

        token.burn(500e8);

        assertEq(token.balanceOf(user1), 500e8);
        assertEq(token.totalSupply(), 500e8);
        vm.stopPrank();
    }

    function test_BurnFrom() public {
        vm.prank(admin);
        token.mint(user1, 1000e8);

        vm.prank(user1);
        token.approve(user2, 500e8);

        vm.startPrank(user2);

        vm.expectEmit(true, true, true, true);
        emit Burn(user1, 500e8);

        token.burnFrom(user1, 500e8);

        assertEq(token.balanceOf(user1), 500e8);
        assertEq(token.totalSupply(), 500e8);
        assertEq(token.allowance(user1, user2), 0);
        vm.stopPrank();
    }

    function test_AdminBurn() public {
        vm.prank(admin);
        token.mint(user1, 1000e8);

        vm.startPrank(admin);

        vm.expectEmit(true, true, true, true);
        emit Burn(user1, 600e8);

        token.adminBurn(user1, 600e8);

        assertEq(token.balanceOf(user1), 400e8);
        assertEq(token.totalSupply(), 400e8);
        vm.stopPrank();
    }

    function test_AdminBurn_RevertsIfNotAdmin() public {
        vm.prank(admin);
        token.mint(user1, 1000e8);

        vm.prank(user1);
        vm.expectRevert(SovaBTCv1.Unauthorized.selector);
        token.adminBurn(user1, 500e8);
    }

    function test_ChangeAdmin() public {
        vm.startPrank(admin);

        vm.expectEmit(true, true, true, true);
        emit AdminChanged(admin, user1);

        token.changeAdmin(user1);

        assertEq(token.admin(), user1);
        vm.stopPrank();
    }

    function test_ChangeAdmin_RevertsIfNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert(SovaBTCv1.Unauthorized.selector);
        token.changeAdmin(user2);
    }

    function test_ChangeAdmin_RevertsIfNewAdminIsZero() public {
        vm.prank(admin);
        vm.expectRevert(SovaBTCv1.InvalidAddress.selector);
        token.changeAdmin(address(0));
    }

    function test_Pause() public {
        vm.prank(admin);
        token.mint(user1, 1000e8);

        vm.prank(admin);
        token.pause();

        assertTrue(token.paused());

        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, 100e8);
    }

    function test_Pause_RevertsIfNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert(SovaBTCv1.Unauthorized.selector);
        token.pause();
    }

    function test_Unpause() public {
        vm.startPrank(admin);
        token.mint(user1, 1000e8);
        token.pause();
        token.unpause();
        vm.stopPrank();

        assertFalse(token.paused());

        vm.prank(user1);
        token.transfer(user2, 100e8);
        assertEq(token.balanceOf(user2), 100e8);
    }

    function test_Unpause_RevertsIfNotAdmin() public {
        vm.prank(admin);
        token.pause();

        vm.prank(user1);
        vm.expectRevert(SovaBTCv1.Unauthorized.selector);
        token.unpause();
    }

    function test_PauseBlocksMint() public {
        vm.startPrank(admin);
        token.pause();

        vm.expectRevert();
        token.mint(user1, 1000e8);
        vm.stopPrank();
    }

    function test_PauseBlocksBurn() public {
        vm.prank(admin);
        token.mint(user1, 1000e8);

        vm.prank(admin);
        token.pause();

        vm.prank(user1);
        vm.expectRevert();
        token.burn(500e8);
    }

    function test_RecoverTokens() public {
        MockERC20 otherToken = new MockERC20();
        otherToken.mint(address(token), 1000e18);

        vm.startPrank(admin);

        vm.expectEmit(true, true, true, true);
        emit TokensRecovered(address(otherToken), user1, 1000e18);

        token.recoverTokens(address(otherToken), user1, 1000e18);

        assertEq(otherToken.balanceOf(user1), 1000e18);
        assertEq(otherToken.balanceOf(address(token)), 0);
        vm.stopPrank();
    }

    function test_RecoverTokens_RevertsIfNotAdmin() public {
        MockERC20 otherToken = new MockERC20();
        otherToken.mint(address(token), 1000e18);

        vm.prank(user1);
        vm.expectRevert(SovaBTCv1.Unauthorized.selector);
        token.recoverTokens(address(otherToken), user1, 1000e18);
    }

    function test_RecoverTokens_RevertsIfToIsZero() public {
        MockERC20 otherToken = new MockERC20();
        otherToken.mint(address(token), 1000e18);

        vm.prank(admin);
        vm.expectRevert(SovaBTCv1.InvalidAddress.selector);
        token.recoverTokens(address(otherToken), address(0), 1000e18);
    }

    function test_Permit() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);

        vm.prank(admin);
        token.mint(owner, 1000e8);

        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                user1,
                500e8,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        token.permit(owner, user1, 500e8, deadline, v, r, s);

        assertEq(token.allowance(owner, user1), 500e8);
    }

    function test_Transfer() public {
        vm.prank(admin);
        token.mint(user1, 1000e8);

        vm.prank(user1);
        token.transfer(user2, 500e8);

        assertEq(token.balanceOf(user1), 500e8);
        assertEq(token.balanceOf(user2), 500e8);
    }

    function test_TransferFrom() public {
        vm.prank(admin);
        token.mint(user1, 1000e8);

        vm.prank(user1);
        token.approve(user2, 500e8);

        vm.prank(user2);
        token.transferFrom(user1, user2, 500e8);

        assertEq(token.balanceOf(user1), 500e8);
        assertEq(token.balanceOf(user2), 500e8);
        assertEq(token.allowance(user1, user2), 0);
    }

    function test_Upgrade() public {
        vm.prank(admin);
        token.mint(user1, 1000e8);

        SovaBTCv1 newImplementation = new SovaBTCv1();

        vm.prank(admin);
        token.upgradeToAndCall(address(newImplementation), "");

        assertEq(token.balanceOf(user1), 1000e8);
        assertEq(token.admin(), admin);
    }

    function test_Upgrade_RevertsIfNotAdmin() public {
        SovaBTCv1 newImplementation = new SovaBTCv1();

        vm.prank(user1);
        vm.expectRevert(SovaBTCv1.Unauthorized.selector);
        token.upgradeToAndCall(address(newImplementation), "");
    }

    function testFuzz_Mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount <= type(uint256).max / 2);

        vm.prank(admin);
        token.mint(to, amount);

        assertEq(token.balanceOf(to), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testFuzz_Burn(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount <= type(uint256).max / 2);
        vm.assume(burnAmount <= mintAmount);

        vm.prank(admin);
        token.mint(user1, mintAmount);

        vm.prank(user1);
        token.burn(burnAmount);

        assertEq(token.balanceOf(user1), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    function testFuzz_Transfer(uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(mintAmount <= type(uint256).max / 2);
        vm.assume(transferAmount <= mintAmount);

        vm.prank(admin);
        token.mint(user1, mintAmount);

        vm.prank(user1);
        token.transfer(user2, transferAmount);

        assertEq(token.balanceOf(user1), mintAmount - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
    }
}
