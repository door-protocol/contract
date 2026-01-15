// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {JuniorVault} from "../../src/tranches/JuniorVault.sol";
import {SeniorVault} from "../../src/tranches/SeniorVault.sol";
import {CoreVault} from "../../src/core/CoreVault.sol";
import {DOORRateOracle} from "../../src/oracle/DOORRateOracle.sol";
import {MockYieldStrategy} from "../../src/strategy/MockYieldStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title JuniorVaultTest
 * @notice Unit tests for JuniorVault (DOOR-BOOST)
 */
contract JuniorVaultTest is Test {
    MockUSDC public usdc;
    JuniorVault public juniorVault;
    SeniorVault public seniorVault;
    CoreVault public coreVault;
    DOORRateOracle public oracle;
    MockYieldStrategy public strategy;

    address public deployer;
    address public alice;
    address public bob;
    address public treasury;

    uint256 constant INITIAL_BALANCE = 1_000_000e6;

    event YieldAdded(uint256 amount);
    event PrincipalSlashed(uint256 amount, uint256 newDeficit);
    event DeficitRecovered(uint256 amount);

    function setUp() public {
        deployer = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        treasury = makeAddr("treasury");

        // Deploy contracts
        usdc = new MockUSDC();
        seniorVault = new SeniorVault(IERC20(address(usdc)));
        juniorVault = new JuniorVault(IERC20(address(usdc)));
        coreVault = new CoreVault(address(usdc), address(seniorVault), address(juniorVault));
        oracle = new DOORRateOracle();
        strategy = new MockYieldStrategy(address(usdc));

        // Initialize
        seniorVault.initialize(address(coreVault));
        juniorVault.initialize(address(coreVault));
        coreVault.initialize(address(strategy), address(oracle), treasury);
        strategy.setOwner(address(coreVault));

        // Mint tokens
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        usdc.mint(address(coreVault), 100_000e6);
    }

    // ============ Constructor Tests ============

    function test_Constructor() public view {
        assertEq(address(juniorVault.asset()), address(usdc));
        assertEq(juniorVault.name(), "DOOR Boosted Yield");
        assertEq(juniorVault.symbol(), "DOOR-BOOST");
        assertEq(juniorVault.slashDeficit(), 0);
    }

    // ============ Initialization Tests ============

    function test_Initialize() public view {
        assertEq(juniorVault.coreVault(), address(coreVault));
        assertTrue(juniorVault.initialized());
    }

    function test_RevertWhen_InitializeTwice() public {
        JuniorVault newVault = new JuniorVault(IERC20(address(usdc)));
        newVault.initialize(address(coreVault));

        vm.expectRevert(JuniorVault.AlreadyInitialized.selector);
        newVault.initialize(address(coreVault));
    }

    // ============ Deposit Tests ============

    function test_Deposit() public {
        uint256 depositAmount = 10_000e6;

        vm.startPrank(alice);
        usdc.approve(address(juniorVault), depositAmount);
        uint256 shares = juniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        assertEq(shares, depositAmount);
        assertEq(juniorVault.balanceOf(alice), shares);
        assertEq(juniorVault.totalPrincipal(), depositAmount);
    }

    function test_DepositMultipleUsers() public {
        uint256 aliceDeposit = 10_000e6;
        uint256 bobDeposit = 30_000e6;

        vm.startPrank(alice);
        usdc.approve(address(juniorVault), aliceDeposit);
        juniorVault.deposit(aliceDeposit, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(juniorVault), bobDeposit);
        juniorVault.deposit(bobDeposit, bob);
        vm.stopPrank();

        assertEq(juniorVault.totalPrincipal(), aliceDeposit + bobDeposit);
    }

    // ============ Withdrawal Tests ============

    function test_Withdraw() public {
        uint256 depositAmount = 10_000e6;

        vm.startPrank(alice);
        usdc.approve(address(juniorVault), depositAmount);
        uint256 shares = juniorVault.deposit(depositAmount, alice);

        uint256 assets = juniorVault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertEq(assets, depositAmount);
        assertEq(juniorVault.balanceOf(alice), 0);
    }

    // ============ Yield Tests ============

    function test_AddYield() public {
        uint256 depositAmount = 10_000e6;
        uint256 yieldAmount = 1_000e6;

        vm.startPrank(alice);
        usdc.approve(address(juniorVault), depositAmount);
        juniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        vm.startPrank(address(coreVault));
        usdc.approve(address(juniorVault), yieldAmount);

        vm.expectEmit(true, true, true, true);
        emit YieldAdded(yieldAmount);
        juniorVault.addYield(yieldAmount);
        vm.stopPrank();

        assertEq(juniorVault.accumulatedYield(), yieldAmount);
    }

    function test_AddYieldWithDeficit() public {
        uint256 depositAmount = 10_000e6;
        uint256 slashAmount = 12_000e6;  // Slash more than principal to create deficit
        uint256 yieldAmount = 3_000e6;
        uint256 expectedDeficit = slashAmount - depositAmount;  // 2,000e6

        // Setup: deposit and slash
        vm.startPrank(alice);
        usdc.approve(address(juniorVault), depositAmount);
        juniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Slash principal (more than available to create a deficit)
        vm.startPrank(address(coreVault));
        juniorVault.slashPrincipal(slashAmount);

        // Verify deficit was created
        assertEq(juniorVault.slashDeficit(), expectedDeficit);

        // Add yield - should first recover deficit
        usdc.approve(address(juniorVault), yieldAmount);

        vm.expectEmit(true, true, true, true);
        emit DeficitRecovered(expectedDeficit);
        juniorVault.addYield(yieldAmount);
        vm.stopPrank();

        assertEq(juniorVault.slashDeficit(), 0);
        assertEq(juniorVault.accumulatedYield(), yieldAmount - expectedDeficit);
    }

    // ============ Slashing Tests ============

    function test_SlashPrincipal() public {
        uint256 depositAmount = 10_000e6;
        uint256 slashAmount = 2_000e6;

        vm.startPrank(alice);
        usdc.approve(address(juniorVault), depositAmount);
        juniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        vm.startPrank(address(coreVault));
        vm.expectEmit(true, true, true, true);
        emit PrincipalSlashed(slashAmount, 0);
        uint256 actualSlash = juniorVault.slashPrincipal(slashAmount);
        vm.stopPrank();

        assertEq(actualSlash, slashAmount);
        assertEq(juniorVault.totalPrincipal(), depositAmount - slashAmount);
    }

    function test_SlashPrincipalUsesYieldFirst() public {
        uint256 depositAmount = 10_000e6;
        uint256 yieldAmount = 1_000e6;
        uint256 slashAmount = 1_500e6;

        // Deposit and add yield
        vm.startPrank(alice);
        usdc.approve(address(juniorVault), depositAmount);
        juniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        vm.startPrank(address(coreVault));
        usdc.approve(address(juniorVault), yieldAmount);
        juniorVault.addYield(yieldAmount);

        // Slash - should use yield first
        uint256 actualSlash = juniorVault.slashPrincipal(slashAmount);
        vm.stopPrank();

        assertEq(actualSlash, slashAmount);
        assertEq(juniorVault.accumulatedYield(), 0);
        assertEq(juniorVault.totalPrincipal(), depositAmount - (slashAmount - yieldAmount));
    }

    function test_SlashPrincipalCreatesDeficit() public {
        uint256 depositAmount = 5_000e6;
        uint256 slashAmount = 7_000e6;

        vm.startPrank(alice);
        usdc.approve(address(juniorVault), depositAmount);
        juniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        vm.startPrank(address(coreVault));
        uint256 actualSlash = juniorVault.slashPrincipal(slashAmount);
        vm.stopPrank();

        assertEq(actualSlash, depositAmount);
        assertEq(juniorVault.totalPrincipal(), 0);
        assertEq(juniorVault.slashDeficit(), slashAmount - depositAmount);
    }

    function test_RevertWhen_SlashNotCoreVault() public {
        vm.startPrank(alice);
        vm.expectRevert(JuniorVault.NotCoreVault.selector);
        juniorVault.slashPrincipal(1000e6);
        vm.stopPrank();
    }

    // ============ View Function Tests ============

    function test_EffectiveTotalAssets() public {
        uint256 depositAmount = 10_000e6;

        vm.startPrank(alice);
        usdc.approve(address(juniorVault), depositAmount);
        juniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        assertEq(juniorVault.effectiveTotalAssets(), depositAmount);
    }

    function test_EffectiveTotalAssetsWithDeficit() public {
        uint256 depositAmount = 10_000e6;
        uint256 slashAmount = 12_000e6;

        vm.startPrank(alice);
        usdc.approve(address(juniorVault), depositAmount);
        juniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        vm.startPrank(address(coreVault));
        juniorVault.slashPrincipal(slashAmount);
        vm.stopPrank();

        assertEq(juniorVault.effectiveTotalAssets(), 0);
        assertEq(juniorVault.slashDeficit(), slashAmount - depositAmount);
    }

    function test_EstimatedAPY() public {
        uint256 depositAmount = 10_000e6;
        uint256 yieldAmount = 1_000e6;

        vm.startPrank(alice);
        usdc.approve(address(juniorVault), depositAmount);
        juniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        vm.startPrank(address(coreVault));
        usdc.approve(address(juniorVault), yieldAmount);
        juniorVault.addYield(yieldAmount);
        vm.stopPrank();

        // 1000 / 10000 * 10000 = 1000 bps = 10%
        assertEq(juniorVault.estimatedAPY(), 1000);
    }

    function test_LeverageFactor() public {
        uint256 depositAmount = 10_000e6;
        uint256 seniorPrincipal = 40_000e6;

        vm.startPrank(alice);
        usdc.approve(address(juniorVault), depositAmount);
        juniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Leverage = (40000 + 10000) / 10000 * 10000 = 50000 bps = 5x
        uint256 leverage = juniorVault.leverageFactor(seniorPrincipal);
        assertEq(leverage, 50000);
    }

    function test_IsHealthy() public {
        vm.startPrank(alice);
        usdc.approve(address(juniorVault), 10_000e6);
        juniorVault.deposit(10_000e6, alice);
        vm.stopPrank();

        assertTrue(juniorVault.isHealthy());

        // Slash to create deficit
        vm.startPrank(address(coreVault));
        juniorVault.slashPrincipal(15_000e6);
        vm.stopPrank();

        assertFalse(juniorVault.isHealthy());
    }

    // ============ Auto-Compound Tests ============

    function test_SetAutoCompound() public {
        vm.startPrank(alice);
        juniorVault.setAutoCompound(true);
        vm.stopPrank();

        assertTrue(juniorVault.isAutoCompoundEnabled(alice));
    }
}
