// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockMETH} from "../src/mocks/MockMETH.sol";
import {SeniorVault} from "../src/tranches/SeniorVault.sol";
import {JuniorVault} from "../src/tranches/JuniorVault.sol";
import {CoreVault} from "../src/core/CoreVault.sol";
import {EpochManager} from "../src/epoch/EpochManager.sol";
import {SafetyModule} from "../src/safety/SafetyModule.sol";
import {DOORRateOracle} from "../src/oracle/DOORRateOracle.sol";
import {VaultStrategy} from "../src/strategy/VaultStrategy.sol";
import {MockYieldStrategy} from "../src/strategy/MockYieldStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DOORProtocolTest is Test {
    MockUSDC public usdc;
    MockMETH public meth;
    SeniorVault public seniorVault;
    JuniorVault public juniorVault;
    CoreVault public coreVault;
    EpochManager public epochManager;
    SafetyModule public safetyModule;
    DOORRateOracle public rateOracle;
    VaultStrategy public strategy;
    MockYieldStrategy public mockStrategy;

    address public deployer;
    address public treasury;
    address public alice;
    address public bob;

    uint256 constant INITIAL_BALANCE = 1_000_000e6; // 1M USDC

    function setUp() public {
        deployer = address(this);
        treasury = makeAddr("treasury");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy Mock Tokens
        usdc = new MockUSDC();
        meth = new MockMETH();

        // Deploy Tranche Vaults
        seniorVault = new SeniorVault(IERC20(address(usdc)));
        juniorVault = new JuniorVault(IERC20(address(usdc)));

        // Deploy Core Infrastructure
        coreVault = new CoreVault(address(usdc), address(seniorVault), address(juniorVault));
        epochManager = new EpochManager(address(usdc), address(coreVault), address(seniorVault), address(juniorVault));
        safetyModule = new SafetyModule(address(coreVault));
        rateOracle = new DOORRateOracle();
        strategy = new VaultStrategy(address(usdc), address(meth));
        mockStrategy = new MockYieldStrategy(address(usdc));

        // Initialize
        seniorVault.initialize(address(coreVault));
        juniorVault.initialize(address(coreVault));
        coreVault.initialize(address(mockStrategy), address(rateOracle), treasury);
        epochManager.initialize();
        strategy.initialize(address(coreVault));
        mockStrategy.setOwner(address(coreVault));

        // Setup roles
        bytes32 KEEPER_ROLE = keccak256("KEEPER_ROLE");
        bytes32 STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
        coreVault.grantRole(KEEPER_ROLE, deployer);
        coreVault.grantRole(STRATEGY_ROLE, deployer);
        epochManager.grantRole(KEEPER_ROLE, deployer);
        safetyModule.grantRole(KEEPER_ROLE, deployer);
        strategy.grantRole(KEEPER_ROLE, deployer);

        // Mint tokens to users
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        usdc.mint(address(mockStrategy), 100_000e6); // For yield simulation
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(address(seniorVault.coreVault()), address(coreVault));
        assertEq(address(juniorVault.coreVault()), address(coreVault));
        assertTrue(coreVault.initialized());
        assertTrue(epochManager.initialized());
    }

    function test_TokenSymbols() public view {
        assertEq(seniorVault.symbol(), "DOOR-FIX");
        assertEq(juniorVault.symbol(), "DOOR-BOOST");
        assertEq(seniorVault.name(), "DOOR Fixed Income");
        assertEq(juniorVault.name(), "DOOR Boosted Yield");
    }

    // ============ Senior Vault Tests ============

    function test_SeniorDeposit() public {
        uint256 depositAmount = 10_000e6; // 10K USDC

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), depositAmount);
        uint256 shares = seniorVault.deposit(depositAmount, alice);
        vm.stopPrank();

        assertEq(seniorVault.balanceOf(alice), shares);
        assertEq(seniorVault.totalPrincipal(), depositAmount);
        assertEq(seniorVault.totalAssets(), depositAmount);
    }

    function test_SeniorWithdraw() public {
        uint256 depositAmount = 10_000e6;

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), depositAmount);
        uint256 shares = seniorVault.deposit(depositAmount, alice);

        uint256 assets = seniorVault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertEq(assets, depositAmount);
        assertEq(seniorVault.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(alice), INITIAL_BALANCE);
    }

    // ============ Junior Vault Tests ============

    function test_JuniorDeposit() public {
        uint256 depositAmount = 10_000e6;

        vm.startPrank(bob);
        usdc.approve(address(juniorVault), depositAmount);
        uint256 shares = juniorVault.deposit(depositAmount, bob);
        vm.stopPrank();

        assertEq(juniorVault.balanceOf(bob), shares);
        assertEq(juniorVault.totalPrincipal(), depositAmount);
    }

    function test_JuniorWithdraw() public {
        uint256 depositAmount = 10_000e6;

        vm.startPrank(bob);
        usdc.approve(address(juniorVault), depositAmount);
        uint256 shares = juniorVault.deposit(depositAmount, bob);

        uint256 assets = juniorVault.redeem(shares, bob, bob);
        vm.stopPrank();

        assertEq(assets, depositAmount);
        assertEq(juniorVault.balanceOf(bob), 0);
    }

    // ============ Oracle Tests ============

    function test_OracleDOR() public view {
        uint256 dor = rateOracle.getDOR();
        assertTrue(dor > 0, "DOR should be positive");

        uint256 seniorRate = rateOracle.calculateSeniorRate();
        assertEq(seniorRate, dor + 100); // 1% premium
    }

    function test_OracleRateSources() public view {
        uint256 sourceCount = rateOracle.getSourceCount();
        assertEq(sourceCount, 5); // 5 rate sources

        // Check TESR source
        DOORRateOracle.RateSource memory tesr = rateOracle.getRateSource(0);
        assertEq(tesr.weight, 2000); // 20%
        assertTrue(tesr.isActive);
    }

    // ============ Safety Module Tests ============

    function test_SafetyLevelHealthy() public view {
        // With no deposits, should be healthy
        (bool isHealthy, bool isCritical,) = safetyModule.getHealthStatus();
        assertTrue(isHealthy);
        assertFalse(isCritical);
    }

    function test_SafetyConfig() public view {
        SafetyModule.SafetyConfig memory config = safetyModule.getCurrentConfig();
        assertEq(config.minJuniorRatio, 2000); // 20%
        assertTrue(config.seniorDepositsEnabled);
        assertTrue(config.juniorDepositsEnabled);
    }

    // ============ Strategy Tests ============

    function test_StrategyAllocation() public view {
        VaultStrategy.Allocation memory target = strategy.getTargetAllocation();
        assertEq(target.mEthRatio, 6000); // 60%
        assertEq(target.usdcRatio, 3000); // 30%
        assertEq(target.rwaRatio, 1000);  // 10%
    }

    function test_MockStrategyYield() public view {
        uint256 apy = mockStrategy.calculateExpectedApy();
        assertEq(apy, 800); // 8% default
    }

    // ============ Integration Tests ============

    function test_FullDepositFlow() public {
        uint256 seniorDeposit = 80_000e6; // 80K
        uint256 juniorDeposit = 20_000e6; // 20K (20% ratio)

        // Alice deposits to Senior
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), seniorDeposit);
        seniorVault.deposit(seniorDeposit, alice);
        vm.stopPrank();

        // Bob deposits to Junior
        vm.startPrank(bob);
        usdc.approve(address(juniorVault), juniorDeposit);
        juniorVault.deposit(juniorDeposit, bob);
        vm.stopPrank();

        // Verify totals
        assertEq(seniorVault.totalPrincipal(), seniorDeposit);
        assertEq(juniorVault.totalPrincipal(), juniorDeposit);
        assertEq(seniorVault.totalAssets() + juniorVault.totalAssets(), seniorDeposit + juniorDeposit);
    }

    function test_CoreVaultStats() public {
        // Setup deposits
        uint256 seniorDeposit = 80_000e6;
        uint256 juniorDeposit = 20_000e6;

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), seniorDeposit);
        seniorVault.deposit(seniorDeposit, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(juniorVault), juniorDeposit);
        juniorVault.deposit(juniorDeposit, bob);
        vm.stopPrank();

        // Check stats via CoreVault
        (
            uint256 seniorPrincipal,
            uint256 juniorPrincipal,
            uint256 totalAssets,
            ,  // currentSeniorRate
            uint256 juniorRatio,
        ) = coreVault.getStats();

        assertEq(seniorPrincipal, seniorDeposit);
        assertEq(juniorPrincipal, juniorDeposit);
        assertEq(totalAssets, seniorDeposit + juniorDeposit);
        assertEq(juniorRatio, 2000); // 20%
    }
}
