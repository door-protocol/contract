// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {SeniorVault} from "../../src/tranches/SeniorVault.sol";
import {JuniorVault} from "../../src/tranches/JuniorVault.sol";
import {CoreVault} from "../../src/core/CoreVault.sol";
import {DOORRateOracle} from "../../src/oracle/DOORRateOracle.sol";
import {MockYieldStrategy} from "../../src/strategy/MockYieldStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CoreVaultTest
 * @notice Unit tests for CoreVault
 */
contract CoreVaultTest is Test {
    MockUSDC public usdc;
    SeniorVault public seniorVault;
    JuniorVault public juniorVault;
    CoreVault public coreVault;
    DOORRateOracle public oracle;
    MockYieldStrategy public strategy;

    address public deployer;
    address public alice;
    address public bob;
    address public treasury;
    address public keeper;

    uint256 constant INITIAL_BALANCE = 1_000_000e6;

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");

    function setUp() public {
        deployer = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        treasury = makeAddr("treasury");
        keeper = makeAddr("keeper");

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

        // Setup roles
        coreVault.grantRole(KEEPER_ROLE, keeper);
        coreVault.grantRole(STRATEGY_ROLE, deployer);

        // Mint tokens
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        usdc.mint(address(strategy), 100_000e6); // For yield
    }

    // ============ Constructor Tests ============

    function test_Constructor() public view {
        assertEq(address(coreVault.ASSET()), address(usdc));
        assertEq(address(coreVault.SENIOR_VAULT()), address(seniorVault));
        assertEq(address(coreVault.JUNIOR_VAULT()), address(juniorVault));
    }

    // ============ Initialization Tests ============

    function test_Initialize() public view {
        assertTrue(coreVault.initialized());
        assertEq(address(coreVault.strategy()), address(strategy));
        assertEq(address(coreVault.rateOracle()), address(oracle));
        assertEq(coreVault.treasury(), treasury);
    }

    function test_RevertWhen_InitializeTwice() public {
        vm.expectRevert(CoreVault.AlreadyInitialized.selector);
        coreVault.initialize(address(strategy), address(oracle), treasury);
    }

    // ============ Stats Tests ============

    function test_GetStats() public {
        uint256 seniorDeposit = 80_000e6;
        uint256 juniorDeposit = 20_000e6;

        // Setup deposits
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), seniorDeposit);
        seniorVault.deposit(seniorDeposit, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(juniorVault), juniorDeposit);
        juniorVault.deposit(juniorDeposit, bob);
        vm.stopPrank();

        (
            uint256 seniorPrincipal,
            uint256 juniorPrincipal,
            uint256 totalAssets,
            ,
            uint256 juniorRatio,
            bool isHealthy
        ) = coreVault.getStats();

        assertEq(seniorPrincipal, seniorDeposit);
        assertEq(juniorPrincipal, juniorDeposit);
        assertEq(totalAssets, seniorDeposit + juniorDeposit);
        assertEq(juniorRatio, 2000); // 20%
        assertTrue(isHealthy);
    }

    function test_GetJuniorRatio() public {
        uint256 seniorDeposit = 70_000e6;
        uint256 juniorDeposit = 30_000e6;

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), seniorDeposit);
        seniorVault.deposit(seniorDeposit, alice);
        usdc.approve(address(juniorVault), juniorDeposit);
        juniorVault.deposit(juniorDeposit, alice);
        vm.stopPrank();

        uint256 ratio = coreVault.getJuniorRatio();
        assertEq(ratio, 3000); // 30%
    }

    // ============ Harvest Tests ============

    function test_Harvest() public {
        uint256 seniorDeposit = 80_000e6;
        uint256 juniorDeposit = 20_000e6;

        // Setup deposits
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), seniorDeposit);
        seniorVault.deposit(seniorDeposit, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(juniorVault), juniorDeposit);
        juniorVault.deposit(juniorDeposit, bob);
        vm.stopPrank();

        // Deposit to strategy
        vm.startPrank(deployer);
        usdc.mint(address(coreVault), seniorDeposit + juniorDeposit);
        coreVault.deployToStrategy(seniorDeposit + juniorDeposit);
        vm.stopPrank();

        // Time passes
        vm.warp(block.timestamp + 30 days);

        // Harvest
        vm.prank(keeper);
        coreVault.harvest();

        // Check yield was distributed
        assertTrue(seniorVault.accumulatedYield() > 0 || juniorVault.accumulatedYield() > 0);
    }

    // ============ Strategy Tests ============

    function test_DepositToStrategy() public {
        uint256 amount = 50_000e6;

        usdc.mint(address(coreVault), amount);

        vm.prank(deployer);
        coreVault.deployToStrategy(amount);

        assertEq(strategy.totalDeployed(), amount);
    }

    function test_WithdrawFromStrategy() public {
        uint256 amount = 50_000e6;

        usdc.mint(address(coreVault), amount);

        vm.startPrank(deployer);
        coreVault.deployToStrategy(amount);

        uint256 beforeBalance = usdc.balanceOf(address(coreVault));
        coreVault.withdrawFromStrategy(amount / 2);
        uint256 afterBalance = usdc.balanceOf(address(coreVault));
        vm.stopPrank();

        assertEq(afterBalance - beforeBalance, amount / 2);
    }

    function test_RevertWhen_DepositToStrategyUnauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        coreVault.deployToStrategy(1000e6);
    }

    // ============ Rate Tests ============

    function test_SyncSeniorRateFromOracle() public {
        vm.prank(keeper);
        coreVault.syncSeniorRateFromOracle();

        uint256 expectedRate = oracle.getSeniorTargetAPY();
        assertEq(coreVault.seniorFixedRate(), expectedRate);
    }

    function test_SetBaseRate() public {
        uint256 newRate = 600; // 6%

        vm.prank(deployer);
        coreVault.setBaseRate(newRate);

        assertEq(coreVault.baseRate(), newRate);
    }

    // ============ Emergency Tests ============

    function test_EmergencyWithdraw() public {
        assertFalse(coreVault.emergencyMode());

        // Grant emergency role
        coreVault.grantRole(coreVault.EMERGENCY_ROLE(), deployer);

        vm.prank(deployer);
        coreVault.emergencyWithdraw();

        assertTrue(coreVault.emergencyMode());
    }

    function test_DisableEmergencyMode() public {
        // Grant emergency role and activate emergency mode
        coreVault.grantRole(coreVault.EMERGENCY_ROLE(), deployer);

        vm.prank(deployer);
        coreVault.emergencyWithdraw();
        assertTrue(coreVault.emergencyMode());

        vm.prank(deployer);
        coreVault.disableEmergencyMode();
        assertFalse(coreVault.emergencyMode());
    }

    function test_RevertWhen_HarvestInEmergencyMode() public {
        // Grant emergency role and activate emergency mode
        coreVault.grantRole(coreVault.EMERGENCY_ROLE(), deployer);

        vm.prank(deployer);
        coreVault.emergencyWithdraw();

        vm.prank(keeper);
        vm.expectRevert(CoreVault.EmergencyModeActive.selector);
        coreVault.harvest();
    }

    // ============ View Functions ============

    function test_GetSeniorVault() public view {
        assertEq(address(coreVault.SENIOR_VAULT()), address(seniorVault));
    }

    function test_GetJuniorVault() public view {
        assertEq(address(coreVault.JUNIOR_VAULT()), address(juniorVault));
    }

    // ============ Admin Tests ============

    function test_TreasuryIsSet() public view {
        assertEq(coreVault.treasury(), treasury);
    }

    function test_SetProtocolFeeRate() public {
        uint256 newFee = 200; // 2%

        vm.prank(deployer);
        coreVault.setProtocolFeeRate(newFee);

        assertEq(coreVault.protocolFeeRate(), newFee);
    }

    function test_SetMinJuniorRatio() public {
        uint256 newRatio = 1500; // 15%

        vm.prank(deployer);
        coreVault.setMinJuniorRatio(newRatio);

        assertEq(coreVault.minJuniorRatio(), newRatio);
    }

    function test_RevertWhen_SetProtocolFeeRateTooHigh() public {
        vm.prank(deployer);
        vm.expectRevert(CoreVault.InvalidFeeRate.selector);
        coreVault.setProtocolFeeRate(1001); // > 10%
    }
}
