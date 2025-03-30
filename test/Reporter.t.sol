// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";

contract ReporterTest is BaseFountfiTest {
    PriceOracleReporter public reporter;
    address public updater;

    function setUp() public override {
        super.setUp();

        updater = makeAddr("updater");

        vm.startPrank(owner);
        reporter = new PriceOracleReporter(1000 * 10**6, updater);
        vm.stopPrank();
    }

    function test_Initialization() public {
        assertEq(reporter.price(), 1000 * 10**6);
        assertEq(reporter.currentRound(), 1);
        assertTrue(reporter.authorizedUpdaters(updater));
        assertEq(reporter.maxDeviationBps(), 500); // Default 5%
    }

    function test_PriceUpdates() public {
        // Update price (within deviation limits)
        uint256 newPrice = 1050 * 10**6; // 5% increase

        vm.prank(updater);
        reporter.update(newPrice, "Test Source");

        assertEq(reporter.price(), newPrice);
        assertEq(reporter.currentRound(), 2);

        // Report should return the new price
        bytes memory reportData = reporter.report();
        uint256 reportedPrice = abi.decode(reportData, (uint256));
        assertEq(reportedPrice, newPrice);
    }

    function test_DeviationLimits() public {
        // Try to update price beyond deviation limits
        uint256 newPrice = 1060 * 10**6; // 6% increase (above default 5%)

        vm.prank(updater);
        vm.expectRevert(PriceOracleReporter.MaxDeviation.selector);
        reporter.update(newPrice, "Test Source");

        // Change deviation limits
        vm.prank(owner);
        reporter.setMaxDeviation(1000); // 10%

        // Now the update should work
        vm.prank(updater);
        reporter.update(newPrice, "Test Source");

        assertEq(reporter.price(), newPrice);
    }

    function test_UpdaterManagement() public {
        address newUpdater = makeAddr("newUpdater");

        // New updater should not be authorized
        assertFalse(reporter.authorizedUpdaters(newUpdater));

        // Unauthorized updater can't update
        vm.prank(newUpdater);
        bytes4 unauthorizedSelector = bytes4(keccak256("Unauthorized()"));
        vm.expectRevert(unauthorizedSelector);
        reporter.update(1100 * 10**6, "Test Source");

        // Add new updater
        vm.prank(owner);
        reporter.setUpdater(newUpdater, true);

        assertTrue(reporter.authorizedUpdaters(newUpdater));

        // Now the new updater can update - but we need to stay within deviation limits
        // Price is initially 1000*10^6, so we can update to at most 1050*10^6 (5% change)
        vm.prank(newUpdater);
        reporter.update(1050 * 10**6, "Test Source");

        assertEq(reporter.price(), 1050 * 10**6);

        // Remove original updater
        vm.prank(owner);
        reporter.setUpdater(updater, false);

        assertFalse(reporter.authorizedUpdaters(updater));

        // Original updater can no longer update
        vm.prank(updater);
        vm.expectRevert(unauthorizedSelector);
        reporter.update(1100 * 10**6, "Test Source");
    }

    function test_SourceValidation() public {
        // Empty source should fail
        vm.prank(updater);
        vm.expectRevert(PriceOracleReporter.InvalidSource.selector);
        reporter.update(1100 * 10**6, "");
    }
}