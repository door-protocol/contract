// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockMETH} from "../../src/mocks/MockMETH.sol";
import {SeniorVault} from "../../src/tranches/SeniorVault.sol";
import {JuniorVault} from "../../src/tranches/JuniorVault.sol";
import {CoreVault} from "../../src/core/CoreVault.sol";
import {SafetyModule} from "../../src/safety/SafetyModule.sol";
import {ISafetyModule} from "../../src/safety/interfaces/ISafetyModule.sol";
import {DOORRateOracle} from "../../src/oracle/DOORRateOracle.sol";
import {MockVaultStrategy} from "../../src/strategy/MockVaultStrategy.sol";
import {SafetyLib} from "../../src/libraries/SafetyLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SafetyModuleTest
 * @notice Unit tests for SafetyModule
 */
contract SafetyModuleTest is Test {
    MockUSDC public usdc;
    MockMETH public meth;
    SeniorVault public seniorVault;
    JuniorVault public juniorVault;
    CoreVault public coreVault;
    SafetyModule public safetyModule;
    DOORRateOracle public oracle;
    MockVaultStrategy public strategy;

    address public deployer;
    address public alice;
    address public bob;
    address public treasury;
    address public keeper;

    uint256 constant INITIAL_BALANCE = 1_000_000e6;

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    event SafetyLevelChanged(SafetyLib.SafetyLevel indexed oldLevel, SafetyLib.SafetyLevel indexed newLevel);
    event SeniorDepositsPaused(string reason);
    event SeniorDepositsResumed();

    function setUp() public {
        deployer = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        treasury = makeAddr("treasury");
        keeper = makeAddr("keeper");

        // Deploy contracts
        usdc = new MockUSDC();
        meth = new MockMETH();
        seniorVault = new SeniorVault(IERC20(address(usdc)));
        juniorVault = new JuniorVault(IERC20(address(usdc)));
        coreVault = new CoreVault(address(usdc), address(seniorVault), address(juniorVault));
        safetyModule = new SafetyModule(address(coreVault));
        oracle = new DOORRateOracle();
        strategy = new MockVaultStrategy(address(usdc), address(meth));

        // Initialize
        seniorVault.initialize(address(coreVault));
        juniorVault.initialize(address(coreVault));
        coreVault.initialize(address(strategy), address(oracle), treasury);
        strategy.initialize(address(coreVault));
        strategy.grantRole(VAULT_ROLE, address(coreVault));

        // Setup roles
        safetyModule.grantRole(KEEPER_ROLE, keeper);

        // Mint tokens
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
    }

    // ============ Constructor Tests ============

    function test_Constructor() public view {
        assertEq(address(safetyModule.CORE_VAULT()), address(coreVault));
        assertTrue(safetyModule.autoPauseEnabled());
    }

    // ============ Safety Level Tests ============

    function test_InitialSafetyLevel() public view {
        assertEq(uint256(safetyModule.getCurrentLevel()), uint256(SafetyLib.SafetyLevel.HEALTHY));
    }

    function test_UpdateSafetyLevel() public {
        // Update to CAUTION (15-20% junior ratio)
        vm.prank(keeper);
        vm.expectEmit(true, true, true, true);
        emit SafetyLevelChanged(SafetyLib.SafetyLevel.HEALTHY, SafetyLib.SafetyLevel.CAUTION);
        safetyModule.updateSafetyLevel(1700); // 17%

        assertEq(uint256(safetyModule.getCurrentLevel()), uint256(SafetyLib.SafetyLevel.CAUTION));
    }

    function test_UpdateSafetyLevelToWarning() public {
        vm.prank(keeper);
        safetyModule.updateSafetyLevel(1200); // 12%

        assertEq(uint256(safetyModule.getCurrentLevel()), uint256(SafetyLib.SafetyLevel.WARNING));
    }

    function test_UpdateSafetyLevelToDanger() public {
        vm.prank(keeper);
        safetyModule.updateSafetyLevel(700); // 7%

        assertEq(uint256(safetyModule.getCurrentLevel()), uint256(SafetyLib.SafetyLevel.DANGER));
    }

    function test_UpdateSafetyLevelToCritical() public {
        vm.prank(keeper);
        safetyModule.updateSafetyLevel(300); // 3%

        assertEq(uint256(safetyModule.getCurrentLevel()), uint256(SafetyLib.SafetyLevel.CRITICAL));
        assertTrue(safetyModule.seniorDepositsPaused()); // Auto-paused
        assertTrue(safetyModule.juniorDepositsPaused()); // Auto-paused
    }

    // ============ Health Check Tests ============

    function test_PerformHealthCheck() public {
        // Setup healthy ratio (20%)
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), 80_000e6);
        seniorVault.deposit(80_000e6, alice);
        usdc.approve(address(juniorVault), 20_000e6);
        juniorVault.deposit(20_000e6, alice);
        vm.stopPrank();

        vm.prank(keeper);
        (bool isHealthy, bool isCritical) = safetyModule.performHealthCheck();

        assertTrue(isHealthy);
        assertFalse(isCritical);
    }

    function test_PerformHealthCheckCritical() public {
        // Setup critical ratio (2%)
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), 98_000e6);
        seniorVault.deposit(98_000e6, alice);
        usdc.approve(address(juniorVault), 2_000e6);
        juniorVault.deposit(2_000e6, alice);
        vm.stopPrank();

        vm.prank(keeper);
        (bool isHealthy, bool isCritical) = safetyModule.performHealthCheck();

        assertFalse(isHealthy);
        assertTrue(isCritical);
        assertTrue(safetyModule.seniorDepositsPaused());
    }

    // ============ Deposit Check Tests ============

    function test_CanDepositSenior() public {
        // Setup healthy ratio
        vm.startPrank(alice);
        usdc.approve(address(juniorVault), 30_000e6);
        juniorVault.deposit(30_000e6, alice);
        vm.stopPrank();

        (bool allowed, string memory reason) = safetyModule.canDepositSenior(10_000e6);
        assertTrue(allowed);
        assertEq(bytes(reason).length, 0);
    }

    function test_CanDepositSeniorWhenPaused() public {
        vm.prank(deployer);
        safetyModule.pauseSeniorDeposits("Testing");

        (bool allowed, string memory reason) = safetyModule.canDepositSenior(10_000e6);
        assertFalse(allowed);
        assertEq(reason, "Senior deposits paused");
    }

    function test_CanDepositSeniorWouldMakeRatioTooLow() public {
        // Setup 20% ratio
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), 80_000e6);
        seniorVault.deposit(80_000e6, alice);
        usdc.approve(address(juniorVault), 20_000e6);
        juniorVault.deposit(20_000e6, alice);
        vm.stopPrank();

        // Try to deposit more Senior which would lower Junior ratio below 20%
        (bool allowed, string memory reason) = safetyModule.canDepositSenior(50_000e6);
        assertFalse(allowed);
        assertEq(reason, "Would make junior ratio too low");
    }

    function test_CanDepositJunior() public {
        (bool allowed, string memory reason) = safetyModule.canDepositJunior();
        assertTrue(allowed);
        assertEq(bytes(reason).length, 0);
    }

    function test_IsDepositAllowed() public view {
        assertTrue(safetyModule.isDepositAllowed(true)); // Senior
        assertTrue(safetyModule.isDepositAllowed(false)); // Junior
    }

    // ============ Config Tests ============

    function test_GetCurrentConfig() public view {
        SafetyModule.SafetyConfig memory config = safetyModule.getCurrentConfig();

        assertEq(config.minJuniorRatio, 2000);
        assertEq(config.maxSeniorDeposit, type(uint256).max);
        assertEq(config.seniorTargetAPY, 600);
        assertTrue(config.seniorDepositsEnabled);
        assertTrue(config.juniorDepositsEnabled);
    }

    function test_GetSeniorTargetAPY() public view {
        assertEq(safetyModule.getSeniorTargetAPY(), 600);
    }

    function test_GetMinJuniorRatio() public view {
        assertEq(safetyModule.getMinJuniorRatio(), 2000);
    }

    // ============ Admin Tests ============

    function test_PauseSeniorDeposits() public {
        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit SeniorDepositsPaused("Emergency");
        safetyModule.pauseSeniorDeposits("Emergency");

        assertTrue(safetyModule.seniorDepositsPaused());
    }

    function test_ResumeSeniorDeposits() public {
        vm.startPrank(deployer);
        safetyModule.pauseSeniorDeposits("Emergency");

        vm.expectEmit(true, true, true, true);
        emit SeniorDepositsResumed();
        safetyModule.resumeSeniorDeposits();
        vm.stopPrank();

        assertFalse(safetyModule.seniorDepositsPaused());
    }

    function test_PauseJuniorDeposits() public {
        vm.prank(deployer);
        safetyModule.pauseJuniorDeposits("Emergency");

        assertTrue(safetyModule.juniorDepositsPaused());
    }

    function test_ResumeJuniorDeposits() public {
        vm.startPrank(deployer);
        safetyModule.pauseJuniorDeposits("Emergency");
        safetyModule.resumeJuniorDeposits();
        vm.stopPrank();

        assertFalse(safetyModule.juniorDepositsPaused());
    }

    function test_SetSeniorDepositCap() public {
        uint256 newCap = 1_000_000e6;

        vm.prank(deployer);
        safetyModule.setSeniorDepositCap(newCap);

        assertEq(safetyModule.seniorDepositCap(), newCap);
    }

    function test_SetAutoPause() public {
        vm.prank(deployer);
        safetyModule.setAutoPause(false);

        assertFalse(safetyModule.autoPauseEnabled());
    }

    function test_SetLevelConfig() public {
        ISafetyModule.SafetyConfig memory newConfig = ISafetyModule.SafetyConfig({
            minJuniorRatio: 2500,
            maxSeniorDeposit: 500_000e6,
            seniorTargetAPY: 700,
            seniorDepositsEnabled: true,
            juniorDepositsEnabled: true
        });

        vm.prank(deployer);
        safetyModule.setLevelConfig(SafetyLib.SafetyLevel.HEALTHY, newConfig);

        ISafetyModule.SafetyConfig memory config = safetyModule.getCurrentConfig();
        assertEq(config.minJuniorRatio, 2500);
        assertEq(config.seniorTargetAPY, 700);
    }

    // ============ Calculate Required Junior Deposit Tests ============

    function test_CalculateRequiredJuniorDeposit() public {
        // Setup 15% ratio
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), 85_000e6);
        seniorVault.deposit(85_000e6, alice);
        usdc.approve(address(juniorVault), 15_000e6);
        juniorVault.deposit(15_000e6, alice);
        vm.stopPrank();

        // Calculate how much Junior needed to reach 20%
        uint256 required = safetyModule.calculateRequiredJuniorDeposit(2000);
        assertTrue(required > 0);
    }
}
