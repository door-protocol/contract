// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockMETH} from "../../src/mocks/MockMETH.sol";
import {SeniorVault} from "../../src/tranches/SeniorVault.sol";
import {CoreVault} from "../../src/core/CoreVault.sol";
import {JuniorVault} from "../../src/tranches/JuniorVault.sol";
import {DOORRateOracle} from "../../src/oracle/DOORRateOracle.sol";
import {MockVaultStrategy} from "../../src/strategy/MockVaultStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SeniorVaultTest
 * @notice Unit tests for SeniorVault (DOOR-FIX)
 */
contract SeniorVaultTest is Test {
    MockUSDC public usdc;
    MockMETH public meth;
    SeniorVault public seniorVault;
    JuniorVault public juniorVault;
    CoreVault public coreVault;
    DOORRateOracle public oracle;
    MockVaultStrategy public strategy;

    address public deployer;
    address public alice;
    address public bob;
    address public treasury;

    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    uint256 constant INITIAL_BALANCE = 1_000_000e6;

    event YieldAdded(uint256 amount);
    event FixedRateUpdated(uint256 oldRate, uint256 newRate);

    function setUp() public {
        deployer = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        treasury = makeAddr("treasury");

        // Deploy contracts
        usdc = new MockUSDC();
        meth = new MockMETH();
        seniorVault = new SeniorVault(IERC20(address(usdc)));
        juniorVault = new JuniorVault(IERC20(address(usdc)));
        coreVault = new CoreVault(address(usdc), address(seniorVault), address(juniorVault));
        oracle = new DOORRateOracle();
        strategy = new MockVaultStrategy(address(usdc), address(meth));

        // Initialize
        seniorVault.initialize(address(coreVault));
        juniorVault.initialize(address(coreVault));
        coreVault.initialize(address(strategy), address(oracle), treasury);
        strategy.initialize(address(coreVault));
        strategy.grantRole(VAULT_ROLE, address(coreVault));

        // Mint tokens
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        usdc.mint(address(coreVault), 100_000e6); // For yield distribution
    }

    // ============ Constructor Tests ============

    function test_Constructor() public view {
        assertEq(address(seniorVault.asset()), address(usdc));
        assertEq(seniorVault.name(), "DOOR Fixed Income");
        assertEq(seniorVault.symbol(), "DOOR-FIX");
        assertEq(seniorVault.fixedRate(), 500); // 5% default
    }

    // ============ Initialization Tests ============

    function test_Initialize() public view {
        assertEq(seniorVault.coreVault(), address(coreVault));
        assertTrue(seniorVault.initialized());
    }

    function test_RevertWhen_InitializeTwice() public {
        SeniorVault newVault = new SeniorVault(IERC20(address(usdc)));
        newVault.initialize(address(coreVault));

        vm.expectRevert(SeniorVault.AlreadyInitialized.selector);
        newVault.initialize(address(coreVault));
    }

    function test_RevertWhen_InitializeWithZeroAddress() public {
        SeniorVault newVault = new SeniorVault(IERC20(address(usdc)));

        vm.expectRevert(SeniorVault.ZeroAddress.selector);
        newVault.initialize(address(0));
    }

    // ============ Deposit Tests ============

    function test_Deposit() public {
        uint256 depositAmount = 10_000e6;

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), depositAmount);
        uint256 shares = seniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        assertEq(shares, depositAmount); // 1:1 initially
        assertEq(seniorVault.balanceOf(alice), shares);
        assertEq(seniorVault.totalPrincipal(), depositAmount);
        assertEq(seniorVault.totalAssets(), depositAmount);
        assertEq(usdc.balanceOf(alice), INITIAL_BALANCE - depositAmount);
    }

    function test_DepositMultipleUsers() public {
        uint256 aliceDeposit = 10_000e6;
        uint256 bobDeposit = 20_000e6;

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), aliceDeposit);
        seniorVault.deposit(aliceDeposit, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(seniorVault), bobDeposit);
        seniorVault.deposit(bobDeposit, bob);
        vm.stopPrank();

        assertEq(seniorVault.totalPrincipal(), aliceDeposit + bobDeposit);
        assertEq(seniorVault.balanceOf(alice), aliceDeposit);
        assertEq(seniorVault.balanceOf(bob), bobDeposit);
    }

    function test_RevertWhen_DepositBeforeInitialize() public {
        SeniorVault newVault = new SeniorVault(IERC20(address(usdc)));

        vm.startPrank(alice);
        usdc.approve(address(newVault), 1000e6);

        vm.expectRevert(SeniorVault.NotInitialized.selector);
        newVault.deposit(1000e6, alice);
        vm.stopPrank();
    }

    // ============ Withdrawal Tests ============

    function test_Withdraw() public {
        uint256 depositAmount = 10_000e6;

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), depositAmount);
        seniorVault.deposit(depositAmount, alice);

        uint256 shares = seniorVault.balanceOf(alice);
        uint256 assets = seniorVault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertEq(assets, depositAmount);
        assertEq(seniorVault.balanceOf(alice), 0);
        assertEq(seniorVault.totalPrincipal(), 0);
        assertEq(usdc.balanceOf(alice), INITIAL_BALANCE);
    }

    function test_PartialWithdraw() public {
        uint256 depositAmount = 10_000e6;
        uint256 withdrawAmount = 4_000e6;

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), depositAmount);
        seniorVault.deposit(depositAmount, alice);

        seniorVault.withdraw(withdrawAmount, alice, alice);
        vm.stopPrank();

        assertEq(seniorVault.totalPrincipal(), depositAmount - withdrawAmount);
        assertEq(usdc.balanceOf(alice), INITIAL_BALANCE - depositAmount + withdrawAmount);
    }

    // ============ Yield Tests ============

    function test_AddYield() public {
        uint256 depositAmount = 10_000e6;
        uint256 yieldAmount = 500e6;

        // Alice deposits
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), depositAmount);
        seniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        // CoreVault adds yield
        vm.startPrank(address(coreVault));
        usdc.approve(address(seniorVault), yieldAmount);

        vm.expectEmit(true, true, true, true);
        emit YieldAdded(yieldAmount);
        seniorVault.addYield(yieldAmount);
        vm.stopPrank();

        assertEq(seniorVault.accumulatedYield(), yieldAmount);
        assertEq(seniorVault.totalAssets(), depositAmount + yieldAmount);
    }

    function test_WithdrawWithYield() public {
        uint256 depositAmount = 10_000e6;
        uint256 yieldAmount = 500e6;

        // Alice deposits
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), depositAmount);
        uint256 shares = seniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        // CoreVault adds yield
        vm.startPrank(address(coreVault));
        usdc.approve(address(seniorVault), yieldAmount);
        seniorVault.addYield(yieldAmount);
        vm.stopPrank();

        // Alice withdraws all
        vm.startPrank(alice);
        uint256 assets = seniorVault.redeem(shares, alice, alice);
        vm.stopPrank();

        // Allow for small rounding differences
        assertApproxEqAbs(assets, depositAmount + yieldAmount, 2);
    }

    function test_RevertWhen_AddYieldNotCoreVault() public {
        vm.startPrank(alice);
        vm.expectRevert(SeniorVault.NotCoreVault.selector);
        seniorVault.addYield(1000e6);
        vm.stopPrank();
    }

    // ============ Fixed Rate Tests ============

    function test_SetFixedRate() public {
        uint256 newRate = 600; // 6%

        vm.startPrank(address(coreVault));
        vm.expectEmit(true, true, true, true);
        emit FixedRateUpdated(500, newRate);
        seniorVault.setFixedRate(newRate);
        vm.stopPrank();

        assertEq(seniorVault.fixedRate(), newRate);
    }

    function test_RevertWhen_SetFixedRateNotCoreVault() public {
        vm.startPrank(alice);
        vm.expectRevert(SeniorVault.NotCoreVault.selector);
        seniorVault.setFixedRate(600);
        vm.stopPrank();
    }

    // ============ View Function Tests ============

    function test_ExpectedAnnualYield() public view {
        uint256 principal = 100_000e6;
        uint256 expectedYield = seniorVault.expectedAnnualYield(principal);

        // 5% of 100,000 = 5,000
        assertEq(expectedYield, 5_000e6);
    }

    function test_CurrentAPY() public view {
        assertEq(seniorVault.currentAPY(), 500);
    }

    // ============ Auto-Compound Tests ============

    function test_SetAutoCompound() public {
        vm.startPrank(alice);
        seniorVault.setAutoCompound(true);
        vm.stopPrank();

        assertTrue(seniorVault.isAutoCompoundEnabled(alice));
        assertFalse(seniorVault.isAutoCompoundEnabled(bob));
    }

    // ============ ERC-4626 Compliance Tests ============

    function test_PreviewDeposit() public view {
        uint256 assets = 10_000e6;
        uint256 shares = seniorVault.previewDeposit(assets);
        assertEq(shares, assets); // 1:1 initially
    }

    function test_PreviewMint() public view {
        uint256 shares = 10_000e6;
        uint256 assets = seniorVault.previewMint(shares);
        assertEq(assets, shares); // 1:1 initially
    }

    function test_MaxDeposit() public view {
        uint256 maxDeposit = seniorVault.maxDeposit(alice);
        assertEq(maxDeposit, type(uint256).max);
    }

    function test_MaxWithdraw() public {
        uint256 depositAmount = 10_000e6;

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), depositAmount);
        seniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        uint256 maxWithdraw = seniorVault.maxWithdraw(alice);
        assertEq(maxWithdraw, depositAmount);
    }
}
