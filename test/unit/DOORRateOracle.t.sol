// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DOORRateOracle} from "../../src/oracle/DOORRateOracle.sol";

/**
 * @title DOORRateOracleTest
 * @notice Unit tests for DOORRateOracle
 */
contract DOORRateOracleTest is Test {
    DOORRateOracle public oracle;

    address public deployer;
    address public oracleUpdater;

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    event RateUpdated(uint256 indexed sourceId, string name, uint256 oldRate, uint256 newRate, uint256 timestamp);
    event DORUpdated(uint256 oldDOR, uint256 newDOR, uint256 timestamp);
    event RateChallengeInitiated(uint256 indexed sourceId, uint256 oldRate, uint256 newRate, uint256 challengeDeadline);

    function setUp() public {
        deployer = address(this);
        oracleUpdater = makeAddr("oracleUpdater");

        oracle = new DOORRateOracle();
        oracle.grantRole(ORACLE_ROLE, oracleUpdater);
        oracle.setAuthorizedUpdater(oracleUpdater, true);
    }

    // ============ Constructor Tests ============

    function test_Constructor() public view {
        assertEq(oracle.getSourceCount(), 5);
        assertTrue(oracle.getDOR() > 0);
    }

    // ============ Rate Source Tests ============

    function test_GetRateSource() public view {
        // Check TESR
        DOORRateOracle.RateSource memory tesr = oracle.getRateSource(0);
        assertEq(tesr.weight, 2000);
        assertEq(tesr.rate, 350);
        assertTrue(tesr.isActive);

        // Check mETH
        DOORRateOracle.RateSource memory meth = oracle.getRateSource(1);
        assertEq(meth.weight, 3000);
        assertEq(meth.rate, 450);

        // Check SOFR
        DOORRateOracle.RateSource memory sofr = oracle.getRateSource(2);
        assertEq(sofr.weight, 2500);
        assertEq(sofr.rate, 460);
    }

    function test_GetAllRateSources() public view {
        DOORRateOracle.RateSource[] memory sources = oracle.getAllRateSources();
        assertEq(sources.length, 5);
    }

    // ============ DOR Calculation Tests ============

    function test_GetDOR() public view {
        uint256 dor = oracle.getDOR();

        // Manual calculation:
        // TESR: 350 * 2000 = 700,000
        // mETH: 450 * 3000 = 1,350,000
        // SOFR: 460 * 2500 = 1,150,000
        // Aave: 600 * 1500 = 900,000
        // Ondo: 500 * 1000 = 500,000
        // Total: 4,600,000 / 10,000 = 460
        assertEq(dor, 460);
    }

    function test_CalculateSeniorRate() public view {
        uint256 seniorRate = oracle.calculateSeniorRate();
        uint256 dor = oracle.getDOR();

        // Senior rate = DOR + 100 bps (1% premium)
        assertEq(seniorRate, dor + 100);
    }

    function test_GetSeniorTargetAPY() public view {
        uint256 targetAPY = oracle.getSeniorTargetAPY();
        assertEq(targetAPY, oracle.getDOR() + 100);
    }

    // ============ Rate Update Tests ============

    function test_UpdateRate() public {
        uint256 sourceId = 0; // TESR
        uint256 newRate = 400; // 4%

        vm.prank(oracleUpdater);
        vm.expectEmit(true, true, true, true);
        emit RateUpdated(sourceId, "TESR", 350, newRate, block.timestamp);
        oracle.updateRate(sourceId, newRate);

        DOORRateOracle.RateSource memory source = oracle.getRateSource(sourceId);
        assertEq(source.rate, newRate);
    }

    function test_UpdateRateTriggersChallenge() public {
        uint256 sourceId = 0;
        uint256 oldRate = 350;
        uint256 newRate = 600; // > MAX_RATE_CHANGE (200 bps)

        vm.prank(oracleUpdater);
        vm.expectEmit(true, true, true, true);
        emit RateChallengeInitiated(sourceId, oldRate, newRate, block.timestamp + 24 hours);
        oracle.updateRate(sourceId, newRate);

        // Rate should not change immediately
        DOORRateOracle.RateSource memory source = oracle.getRateSource(sourceId);
        assertEq(source.rate, oldRate);
    }

    function test_BatchUpdateRates() public {
        uint256[] memory sourceIds = new uint256[](2);
        uint256[] memory newRates = new uint256[](2);

        sourceIds[0] = 0;
        sourceIds[1] = 1;
        newRates[0] = 380;
        newRates[1] = 480;

        vm.prank(oracleUpdater);
        oracle.batchUpdateRates(sourceIds, newRates);

        assertEq(oracle.getRateSource(0).rate, 380);
        assertEq(oracle.getRateSource(1).rate, 480);
    }

    function test_RevertWhen_UpdateRateTooHigh() public {
        vm.prank(oracleUpdater);
        vm.expectRevert(DOORRateOracle.RateTooHigh.selector);
        oracle.updateRate(0, 6000); // > MAX_RATE (5000)
    }

    function test_RevertWhen_UpdateRateInvalidSource() public {
        vm.prank(oracleUpdater);
        vm.expectRevert(DOORRateOracle.InvalidSourceId.selector);
        oracle.updateRate(99, 400);
    }

    function test_RevertWhen_UpdateRateUnauthorized() public {
        vm.prank(makeAddr("unauthorized"));
        vm.expectRevert();
        oracle.updateRate(0, 400);
    }

    // ============ Challenge Tests ============

    function test_ExecutePendingChange() public {
        uint256 sourceId = 0;
        uint256 newRate = 600;

        // Initiate challenge
        vm.prank(oracleUpdater);
        oracle.updateRate(sourceId, newRate);

        // Wait for challenge period
        vm.warp(block.timestamp + 25 hours);

        // Execute pending change
        oracle.executePendingChange(sourceId);

        DOORRateOracle.RateSource memory source = oracle.getRateSource(sourceId);
        assertEq(source.rate, newRate);
    }

    function test_RevertWhen_ExecutePendingChangeEarly() public {
        uint256 sourceId = 0;
        uint256 newRate = 600;

        vm.prank(oracleUpdater);
        oracle.updateRate(sourceId, newRate);

        // Try to execute before challenge period ends
        vm.warp(block.timestamp + 12 hours);

        vm.expectRevert(DOORRateOracle.ChallengePeriodNotEnded.selector);
        oracle.executePendingChange(sourceId);
    }

    function test_RevertWhen_NoPendingChallenge() public {
        vm.expectRevert(DOORRateOracle.NoPendingChallenge.selector);
        oracle.executePendingChange(0);
    }

    // ============ View Function Tests ============

    function test_IsFresh() public view {
        assertTrue(oracle.isFresh());
    }

    function test_IsFreshAfterStaleness() public {
        // Warp past staleness threshold
        vm.warp(block.timestamp + 25 hours);
        assertFalse(oracle.isFresh());
    }

    function test_GetDORBreakdown() public view {
        (
            string[] memory names,
            uint256[] memory weights,
            uint256[] memory rates,
            uint256[] memory contributions,
            uint256 totalDOR
        ) = oracle.getDORBreakdown();

        assertEq(names.length, 5);
        assertEq(weights.length, 5);
        assertEq(rates.length, 5);
        assertEq(contributions.length, 5);
        assertEq(totalDOR, oracle.getDOR());
    }

    function test_GetSourceHealth() public view {
        (bool[] memory isHealthy, uint256[] memory lastUpdates, uint256 healthyCount) = oracle.getSourceHealth();

        assertEq(isHealthy.length, 5);
        assertEq(lastUpdates.length, 5);
        assertEq(healthyCount, 5); // All healthy initially
    }

    // ============ Admin Tests ============

    function test_AddRateSource() public {
        string memory name = "NewSource";
        uint256 weight = 500;
        uint256 rate = 400;

        oracle.addRateSource(name, weight, rate);

        assertEq(oracle.getSourceCount(), 6);

        DOORRateOracle.RateSource memory source = oracle.getRateSource(5);
        assertEq(source.weight, weight);
        assertEq(source.rate, rate);
    }

    function test_UpdateSourceWeight() public {
        uint256 newWeight = 2500;

        oracle.updateSourceWeight(0, newWeight);

        DOORRateOracle.RateSource memory source = oracle.getRateSource(0);
        assertEq(source.weight, newWeight);
    }

    function test_ToggleSourceActive() public {
        oracle.toggleSourceActive(0, false);

        DOORRateOracle.RateSource memory source = oracle.getRateSource(0);
        assertFalse(source.isActive);

        // DOR should be recalculated without this source
        uint256 newDOR = oracle.getDOR();
        assertTrue(newDOR != 460); // Different from original
    }

    function test_SetAuthorizedUpdater() public {
        address newUpdater = makeAddr("newUpdater");

        oracle.setAuthorizedUpdater(newUpdater, true);
        assertTrue(oracle.authorizedUpdaters(newUpdater));

        oracle.setAuthorizedUpdater(newUpdater, false);
        assertFalse(oracle.authorizedUpdaters(newUpdater));
    }
}
