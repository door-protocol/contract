// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {SeniorVault} from "../../src/tranches/SeniorVault.sol";
import {JuniorVault} from "../../src/tranches/JuniorVault.sol";
import {CoreVault} from "../../src/core/CoreVault.sol";
import {DOORRateOracle} from "../../src/oracle/DOORRateOracle.sol";
import {MockYieldStrategy} from "../../src/strategy/MockYieldStrategy.sol";
import {WaterfallMath} from "../../src/libraries/WaterfallMath.sol";
import {SafetyLib} from "../../src/libraries/SafetyLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FuzzTest
 * @notice Fuzz tests for DOOR Protocol
 */
contract FuzzTest is Test {
    MockUSDC public usdc;
    SeniorVault public seniorVault;
    JuniorVault public juniorVault;
    CoreVault public coreVault;
    DOORRateOracle public oracle;
    MockYieldStrategy public strategy;

    address public deployer;
    address public treasury;
    address public alice;

    function setUp() public {
        deployer = address(this);
        treasury = makeAddr("treasury");
        alice = makeAddr("alice");

        usdc = new MockUSDC();
        seniorVault = new SeniorVault(IERC20(address(usdc)));
        juniorVault = new JuniorVault(IERC20(address(usdc)));
        coreVault = new CoreVault(address(usdc), address(seniorVault), address(juniorVault));
        oracle = new DOORRateOracle();
        strategy = new MockYieldStrategy(address(usdc));

        seniorVault.initialize(address(coreVault));
        juniorVault.initialize(address(coreVault));
        coreVault.initialize(address(strategy), address(oracle), treasury);
        strategy.setOwner(address(coreVault));
    }

    // ============ Senior Vault Fuzz Tests ============

    function testFuzz_SeniorDeposit(uint256 amount) public {
        // Bound to reasonable amounts (1 USDC to 100M USDC)
        amount = bound(amount, 1e6, 100_000_000e6);

        usdc.mint(alice, amount);

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), amount);
        uint256 shares = seniorVault.deposit(amount, alice);
        vm.stopPrank();

        assertEq(seniorVault.balanceOf(alice), shares);
        assertEq(seniorVault.totalPrincipal(), amount);
        assertGe(shares, 0);
    }

    function testFuzz_SeniorDepositWithdraw(uint256 depositAmount, uint256 withdrawPercent) public {
        depositAmount = bound(depositAmount, 1e6, 100_000_000e6);
        withdrawPercent = bound(withdrawPercent, 1, 100);

        usdc.mint(alice, depositAmount);

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), depositAmount);
        uint256 shares = seniorVault.deposit(depositAmount, alice);

        uint256 sharesToWithdraw = (shares * withdrawPercent) / 100;
        if (sharesToWithdraw > 0) {
            uint256 assets = seniorVault.redeem(sharesToWithdraw, alice, alice);
            assertGt(assets, 0);
        }
        vm.stopPrank();
    }

    // ============ Junior Vault Fuzz Tests ============

    function testFuzz_JuniorDeposit(uint256 amount) public {
        amount = bound(amount, 1e6, 100_000_000e6);

        usdc.mint(alice, amount);

        vm.startPrank(alice);
        usdc.approve(address(juniorVault), amount);
        uint256 shares = juniorVault.deposit(amount, alice);
        vm.stopPrank();

        assertEq(juniorVault.balanceOf(alice), shares);
        assertEq(juniorVault.totalPrincipal(), amount);
    }

    function testFuzz_JuniorSlash(uint256 depositAmount, uint256 slashPercent) public {
        depositAmount = bound(depositAmount, 1e6, 100_000_000e6);
        slashPercent = bound(slashPercent, 1, 150); // Can exceed 100% to test deficit

        usdc.mint(alice, depositAmount);

        vm.startPrank(alice);
        usdc.approve(address(juniorVault), depositAmount);
        juniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        uint256 slashAmount = (depositAmount * slashPercent) / 100;

        vm.prank(address(coreVault));
        uint256 actualSlash = juniorVault.slashPrincipal(slashAmount);

        if (slashPercent <= 100) {
            assertEq(actualSlash, slashAmount);
            assertEq(juniorVault.slashDeficit(), 0);
        } else {
            assertEq(actualSlash, depositAmount);
            assertGt(juniorVault.slashDeficit(), 0);
        }
    }

    // ============ Oracle Fuzz Tests ============

    function testFuzz_OracleRateUpdate(uint256 newRate) public {
        // Bound to valid rate range
        newRate = bound(newRate, 0, 5000); // Max 50%

        uint256 oldRate = oracle.getRateSource(0).rate;

        vm.prank(deployer);

        // If change is > MAX_RATE_CHANGE, it goes to challenge
        if (_absDiff(newRate, oldRate) > 200) {
            oracle.updateRate(0, newRate);
            // Rate should not change immediately
            assertEq(oracle.getRateSource(0).rate, oldRate);
        } else {
            oracle.updateRate(0, newRate);
            assertEq(oracle.getRateSource(0).rate, newRate);
        }
    }

    // ============ WaterfallMath Fuzz Tests ============

    function testFuzz_CalculateJuniorRatio(uint256 seniorPrincipal, uint256 juniorPrincipal) public pure {
        seniorPrincipal = bound(seniorPrincipal, 0, 1e18);
        juniorPrincipal = bound(juniorPrincipal, 0, 1e18);

        uint256 ratio = WaterfallMath.calculateJuniorRatio(seniorPrincipal, juniorPrincipal);

        if (seniorPrincipal + juniorPrincipal == 0) {
            assertEq(ratio, 0);
        } else {
            assertLe(ratio, 10_000);
        }
    }

    function testFuzz_CalculateLeverage(uint256 seniorPrincipal, uint256 juniorPrincipal) public pure {
        seniorPrincipal = bound(seniorPrincipal, 0, 1e18);
        juniorPrincipal = bound(juniorPrincipal, 1, 1e18); // Avoid division by zero

        uint256 leverage = WaterfallMath.calculateLeverage(seniorPrincipal, juniorPrincipal);

        // Leverage should be at least 1x (10000 bps)
        assertGe(leverage, 10_000);
    }

    function testFuzz_CalculateSeniorObligation(
        uint256 seniorPrincipal,
        uint256 seniorRate,
        uint256 timeElapsed
    ) public pure {
        seniorPrincipal = bound(seniorPrincipal, 0, 1e18);
        seniorRate = bound(seniorRate, 0, 5000);
        timeElapsed = bound(timeElapsed, 0, 365 days);

        uint256 obligation = WaterfallMath.calculateSeniorObligation(seniorPrincipal, seniorRate, timeElapsed);

        // Obligation should be reasonable
        if (seniorPrincipal == 0 || seniorRate == 0 || timeElapsed == 0) {
            assertEq(obligation, 0);
        } else {
            // For very small values, obligation might round to 0
            // Just ensure it doesn't revert and is within bounds
            assertLe(obligation, seniorPrincipal);
        }
    }

    function testFuzz_CalculateDistribution(
        uint256 totalProfit,
        uint256 seniorPrincipal,
        uint256 juniorPrincipal,
        uint256 seniorRate,
        uint256 protocolFee
    ) public pure {
        totalProfit = bound(totalProfit, 0, 1e18);
        seniorPrincipal = bound(seniorPrincipal, 0, 1e18);
        juniorPrincipal = bound(juniorPrincipal, 0, 1e18);
        seniorRate = bound(seniorRate, 0, 5000);
        protocolFee = bound(protocolFee, 0, 1000);

        WaterfallMath.DistributionParams memory params = WaterfallMath.DistributionParams({
            seniorPrincipal: seniorPrincipal,
            juniorPrincipal: juniorPrincipal,
            seniorFixedRate: seniorRate,
            protocolFeeRate: protocolFee,
            timeElapsed: 365 days,
            totalProfit: int256(totalProfit)
        });

        WaterfallMath.DistributionResult memory result = WaterfallMath.calculateDistribution(params);

        // In waterfall distribution, Senior can get more than total profit by slashing Junior
        // Total outflow (seniorYield + juniorYield + protocolFee) should not exceed
        // total profit + junior slash (which transfers from Junior to Senior)
        assertLe(result.juniorYield + result.protocolFee, totalProfit);
        assertLe(result.juniorSlash, juniorPrincipal);
    }

    // ============ SafetyLib Fuzz Tests ============

    function testFuzz_CalculateSafetyLevel(uint256 juniorRatio) public pure {
        juniorRatio = bound(juniorRatio, 0, 10_000);

        SafetyLib.SafetyLevel level = SafetyLib.calculateSafetyLevel(juniorRatio);

        if (juniorRatio >= 2000) {
            assertEq(uint256(level), uint256(SafetyLib.SafetyLevel.HEALTHY));
        } else if (juniorRatio >= 1500) {
            assertEq(uint256(level), uint256(SafetyLib.SafetyLevel.CAUTION));
        } else if (juniorRatio >= 1000) {
            assertEq(uint256(level), uint256(SafetyLib.SafetyLevel.WARNING));
        } else if (juniorRatio >= 500) {
            assertEq(uint256(level), uint256(SafetyLib.SafetyLevel.DANGER));
        } else {
            assertEq(uint256(level), uint256(SafetyLib.SafetyLevel.CRITICAL));
        }
    }

    function testFuzz_CheckHealth(uint256 juniorPrincipal, uint256 seniorPrincipal, uint256 minRatio) public pure {
        juniorPrincipal = bound(juniorPrincipal, 0, 1e18);
        seniorPrincipal = bound(seniorPrincipal, 0, 1e18);
        minRatio = bound(minRatio, 0, 10_000);

        (bool isHealthy, uint256 currentRatio) = WaterfallMath.checkHealth(juniorPrincipal, seniorPrincipal, minRatio);

        if (juniorPrincipal + seniorPrincipal == 0) {
            assertTrue(isHealthy);
            assertEq(currentRatio, 0);
        } else {
            assertLe(currentRatio, 10_000);
            assertEq(isHealthy, currentRatio >= minRatio);
        }
    }

    // ============ Protocol Stats Fuzz Tests ============

    function testFuzz_ProtocolStats(uint256 seniorAmount, uint256 juniorAmount) public {
        seniorAmount = bound(seniorAmount, 1e6, 100_000_000e6);
        juniorAmount = bound(juniorAmount, 1e6, 100_000_000e6);

        usdc.mint(alice, seniorAmount + juniorAmount);

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), seniorAmount);
        seniorVault.deposit(seniorAmount, alice);

        usdc.approve(address(juniorVault), juniorAmount);
        juniorVault.deposit(juniorAmount, alice);
        vm.stopPrank();

        (
            uint256 seniorPrincipal,
            uint256 juniorPrincipal,
            uint256 totalAssets,
            ,
            uint256 juniorRatio,
        ) = coreVault.getStats();

        assertEq(seniorPrincipal, seniorAmount);
        assertEq(juniorPrincipal, juniorAmount);
        assertEq(totalAssets, seniorAmount + juniorAmount);

        uint256 expectedRatio = (juniorAmount * 10_000) / (seniorAmount + juniorAmount);
        assertEq(juniorRatio, expectedRatio);
    }

    // ============ Helper Functions ============

    function _absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }
}
