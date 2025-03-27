// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {NavOracle} from "../src/token/NavOracle.sol";
import {tRWAFactory} from "../src/token/tRWAFactory.sol";
import {ComplianceModule} from "../src/token/ComplianceModule.sol";

contract ComplianceModuleTest is Test {
    ComplianceModule public compliance;
    tRWA public token;
    NavOracle public oracle;
    tRWAFactory public factory;

    address public user1 = address(2);
    address public user2 = address(3);
    address public user3 = address(4);

    uint256 public initialNav = 1e18; // $1.00 per share
    uint256 public transferLimit = 100e18; // 100 token transfer limit

    function setUp() public {
        // Deploy contracts
        oracle = new NavOracle();

        // Verify test contract has authorization in the oracle
        assertTrue(oracle.authorizedUpdaters(address(this)), "Test contract not authorized in oracle");

        factory = new tRWAFactory(address(oracle));

        // Update the factory to be the admin of the oracle
        oracle.updateAdmin(address(factory));

        compliance = new ComplianceModule(transferLimit, true);

        // Deploy a test token through the factory
        address tokenAddress = factory.deployToken("Tokenized Real Estate Fund", "TREF", initialNav);
        token = tRWA(tokenAddress);

        // Transfer the token admin role back to the test contract for testing purposes
        vm.startPrank(address(factory));
        token.updateAdmin(address(this));
        vm.stopPrank();

        // Set compliance module for the token
        token.setComplianceModule(address(compliance));

        // Register token in compliance module
        compliance.registerToken(address(token));

        // Approve KYC for user1, but not user2
        compliance.approveKyc(user1);

        // Mint tokens to users for testing
        token.deposit(1000e18, user1);
        token.deposit(500e18, user2);
        token.deposit(50e18, user3);

        // Mark user3 as exempt from KYC
        compliance.updateExemptStatus(user3, true);
    }

    function test_ComplianceInitialState() public {
        assertEq(compliance.admin(), address(this));
        assertEq(compliance.complianceOfficer(), address(this));
        assertEq(compliance.transferLimit(), transferLimit);
        assertTrue(compliance.enforceTransferLimits());
        assertTrue(compliance.isRegulatedToken(address(token)));
        assertTrue(compliance.isKycApproved(user1));
        assertFalse(compliance.isKycApproved(user2));
        assertTrue(compliance.isExempt(user3));
    }

    function test_ComplianceCheck() public {
        // Enable compliance on token
        token.toggleCompliance(true);

        // Approve KYC for User2 as well, so transfers to them will work
        compliance.approveKyc(user2);

        // Test transfer from KYC-approved user to another KYC-approved user (should pass)
        vm.startPrank(user1);
        token.transfer(user2, 10e18);

        // Test transfer exceeding limit (should fail)
        vm.expectRevert();
        token.transfer(user2, 200e18);
        vm.stopPrank();

        // Revoke KYC for user2 to test transfers to non-approved users
        compliance.revokeKyc(user2);

        // Test transfer from KYC-approved user to non-KYC-approved user (should fail)
        vm.startPrank(user1);
        vm.expectRevert();
        token.transfer(user2, 10e18);
        vm.stopPrank();

        // Test transfer from non-KYC-approved user (should fail)
        vm.startPrank(user2);
        vm.expectRevert();
        token.transfer(user1, 10e18);
        vm.stopPrank();

        // Test transfer from exempt user (should pass)
        vm.startPrank(user3);
        token.transfer(user1, 10e18);
        vm.stopPrank();
    }

    function test_KycManagement() public {
        // Revoke KYC for user1
        compliance.revokeKyc(user1);
        assertFalse(compliance.isKycApproved(user1));

        // Approve KYC for user2
        compliance.approveKyc(user2);
        assertTrue(compliance.isKycApproved(user2));

        // Test batch KYC approval
        address[] memory users = new address[](2);
        users[0] = address(5);
        users[1] = address(6);
        compliance.batchApproveKyc(users);

        assertTrue(compliance.isKycApproved(address(5)));
        assertTrue(compliance.isKycApproved(address(6)));
    }

    function test_TransferLimitManagement() public {
        // Update transfer limit
        uint256 newLimit = 50e18;
        compliance.updateTransferLimit(newLimit);
        assertEq(compliance.transferLimit(), newLimit);

        // Disable transfer limit enforcement
        compliance.setTransferLimitEnforcement(false);
        assertFalse(compliance.enforceTransferLimits());

        // Enable compliance but approve KYC for user2
        token.toggleCompliance(true);
        compliance.approveKyc(user2);

        // Now test a transfer over the limit (should pass now since limits are disabled)
        vm.startPrank(user1);
        token.transfer(user2, 75e18);
        vm.stopPrank();
    }

    function test_TokenRegistration() public {
        // Deploy another token
        address token2Address = factory.deployToken("Tokenized Credit Fund", "TCF", initialNav);

        // Register the token
        compliance.registerToken(token2Address);
        assertTrue(compliance.isRegulatedToken(token2Address));

        // Unregister the token
        compliance.unregisterToken(token2Address);
        assertFalse(compliance.isRegulatedToken(token2Address));
    }

    function test_AdminFunctions() public {
        // Test updating admin
        address newAdmin = address(8);
        compliance.updateAdmin(newAdmin);
        assertEq(compliance.admin(), newAdmin);

        // Test updating compliance officer
        address newOfficer = address(9);

        vm.startPrank(newAdmin);
        compliance.updateComplianceOfficer(newOfficer);
        assertEq(compliance.complianceOfficer(), newOfficer);
        vm.stopPrank();
    }

    function test_UnauthorizedAccess() public {
        vm.startPrank(user1);

        // Try to approve KYC as non-admin (should fail)
        vm.expectRevert();
        compliance.approveKyc(user2);

        // Try to register token as non-admin (should fail)
        vm.expectRevert();
        compliance.registerToken(address(0x123));

        // Try to update transfer limit as non-admin (should fail)
        vm.expectRevert();
        compliance.updateTransferLimit(200e18);

        vm.stopPrank();
    }
}