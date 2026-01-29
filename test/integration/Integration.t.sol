// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockMETH} from "../../src/mocks/MockMETH.sol";
import {SeniorVault} from "../../src/tranches/SeniorVault.sol";
import {JuniorVault} from "../../src/tranches/JuniorVault.sol";
import {CoreVault} from "../../src/core/CoreVault.sol";
import {EpochManager} from "../../src/epoch/EpochManager.sol";
import {IEpochManager} from "../../src/epoch/interfaces/IEpochManager.sol";
import {SafetyModule} from "../../src/safety/SafetyModule.sol";
import {DOORRateOracle} from "../../src/oracle/DOORRateOracle.sol";
import {VaultStrategy} from "../../src/strategy/VaultStrategy.sol";
import {MockVaultStrategy} from "../../src/strategy/MockVaultStrategy.sol";
import {SafetyLib} from "../../src/libraries/SafetyLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IntegrationTest
 * @notice Integration tests for DOOR Protocol
 */
contract IntegrationTest is Test {
    MockUSDC public usdc;
    MockMETH public meth;
    SeniorVault public seniorVault;
    JuniorVault public juniorVault;
    CoreVault public coreVault;
    EpochManager public epochManager;
    SafetyModule public safetyModule;
    DOORRateOracle public rateOracle;
    VaultStrategy public strategy;
    MockVaultStrategy public mockStrategy;

    address public deployer;
    address public treasury;
    address public keeper;
    address public alice;
    address public bob;
    address public charlie;

    uint256 constant INITIAL_BALANCE = 1_000_000e6;

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    function setUp() public {
        deployer = address(this);
        treasury = makeAddr("treasury");
        keeper = makeAddr("keeper");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Deploy all contracts
        usdc = new MockUSDC();
        meth = new MockMETH();
        seniorVault = new SeniorVault(IERC20(address(usdc)));
        juniorVault = new JuniorVault(IERC20(address(usdc)));
        coreVault = new CoreVault(address(usdc), address(seniorVault), address(juniorVault));
        epochManager = new EpochManager(address(usdc), address(coreVault), address(seniorVault), address(juniorVault));
        safetyModule = new SafetyModule(address(coreVault));
        rateOracle = new DOORRateOracle();
        strategy = new VaultStrategy(address(usdc), address(meth));
        mockStrategy = new MockVaultStrategy(address(usdc), address(meth));

        // Initialize all contracts
        seniorVault.initialize(address(coreVault));
        juniorVault.initialize(address(coreVault));
        coreVault.initialize(address(mockStrategy), address(rateOracle), treasury);
        epochManager.initialize();
        strategy.initialize(address(coreVault));
        mockStrategy.initialize(address(coreVault));

        // Setup roles
        coreVault.grantRole(KEEPER_ROLE, keeper);
        coreVault.grantRole(KEEPER_ROLE, address(epochManager)); // EpochManager calls harvest()
        coreVault.grantRole(STRATEGY_ROLE, deployer);
        coreVault.grantRole(EMERGENCY_ROLE, deployer);
        epochManager.grantRole(KEEPER_ROLE, keeper);
        safetyModule.grantRole(KEEPER_ROLE, keeper);
        strategy.grantRole(KEEPER_ROLE, keeper);
        mockStrategy.grantRole(KEEPER_ROLE, keeper);
        mockStrategy.grantRole(VAULT_ROLE, address(coreVault));
        rateOracle.grantRole(ORACLE_ROLE, deployer);

        // Mint tokens to users
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        usdc.mint(charlie, INITIAL_BALANCE);
        usdc.mint(address(mockStrategy), 100_000e6); // For yield simulation
    }

    // ============ Full Deposit/Withdraw Flow Tests ============

    function test_FullDepositWithdrawFlow() public {
        uint256 seniorDeposit = 100_000e6;
        uint256 juniorDeposit = 25_000e6;

        // Alice deposits to Senior
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), seniorDeposit);
        uint256 seniorShares = seniorVault.deposit(seniorDeposit, alice);
        vm.stopPrank();

        // Bob deposits to Junior
        vm.startPrank(bob);
        usdc.approve(address(juniorVault), juniorDeposit);
        uint256 juniorShares = juniorVault.deposit(juniorDeposit, bob);
        vm.stopPrank();

        // Verify stats
        (uint256 seniorPrincipal, uint256 juniorPrincipal, , , uint256 ratio, ) = coreVault.getStats();
        assertEq(seniorPrincipal, seniorDeposit);
        assertEq(juniorPrincipal, juniorDeposit);
        assertEq(ratio, 2000); // 20%

        // Alice withdraws
        vm.startPrank(alice);
        uint256 aliceAssets = seniorVault.redeem(seniorShares, alice, alice);
        vm.stopPrank();

        assertEq(aliceAssets, seniorDeposit);
        assertEq(usdc.balanceOf(alice), INITIAL_BALANCE);

        // Bob withdraws
        vm.startPrank(bob);
        uint256 bobAssets = juniorVault.redeem(juniorShares, bob, bob);
        vm.stopPrank();

        assertEq(bobAssets, juniorDeposit);
        assertEq(usdc.balanceOf(bob), INITIAL_BALANCE);
    }

    // ============ Yield Distribution Tests ============

    function test_YieldDistributionFlow() public {
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
        usdc.mint(address(coreVault), seniorDeposit + juniorDeposit);
        vm.prank(deployer);
        coreVault.deployToStrategy(seniorDeposit + juniorDeposit);

        // Time passes - yield accumulates
        vm.warp(block.timestamp + 365 days);

        // Harvest
        uint256 seniorYieldBefore = seniorVault.accumulatedYield();
        uint256 juniorYieldBefore = juniorVault.accumulatedYield();

        vm.prank(keeper);
        coreVault.harvest();

        uint256 seniorYieldAfter = seniorVault.accumulatedYield();
        uint256 juniorYieldAfter = juniorVault.accumulatedYield();

        // Senior should have received yield
        assertTrue(seniorYieldAfter > seniorYieldBefore);
        // Junior should have received remaining yield
        assertTrue(juniorYieldAfter >= juniorYieldBefore);
    }

    // ============ Multi-User Scenario Tests ============

    function test_MultiUserScenario() public {
        // Multiple users deposit to both vaults
        uint256 aliceSenior = 50_000e6;
        uint256 bobSenior = 30_000e6;
        uint256 charlieJunior = 20_000e6;

        vm.startPrank(alice);
        usdc.approve(address(seniorVault), aliceSenior);
        seniorVault.deposit(aliceSenior, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(seniorVault), bobSenior);
        seniorVault.deposit(bobSenior, bob);
        vm.stopPrank();

        vm.startPrank(charlie);
        usdc.approve(address(juniorVault), charlieJunior);
        juniorVault.deposit(charlieJunior, charlie);
        vm.stopPrank();

        // Verify totals
        assertEq(seniorVault.totalPrincipal(), aliceSenior + bobSenior);
        assertEq(juniorVault.totalPrincipal(), charlieJunior);

        // Verify share proportions
        uint256 aliceShares = seniorVault.balanceOf(alice);
        uint256 bobShares = seniorVault.balanceOf(bob);

        assertEq(aliceShares * 1000 / (aliceShares + bobShares), 625); // ~62.5%
        assertEq(bobShares * 1000 / (aliceShares + bobShares), 375); // ~37.5%
    }

    // ============ Safety Level Transition Tests ============

    function test_SafetyLevelTransitions() public {
        // Start with healthy ratio
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), 80_000e6);
        seniorVault.deposit(80_000e6, alice);
        usdc.approve(address(juniorVault), 20_000e6);
        juniorVault.deposit(20_000e6, alice);
        vm.stopPrank();

        // Check health
        vm.prank(keeper);
        (bool isHealthy, ) = safetyModule.performHealthCheck();
        assertTrue(isHealthy);

        // More Senior deposits, ratio drops
        vm.startPrank(bob);
        usdc.approve(address(seniorVault), 100_000e6);
        seniorVault.deposit(100_000e6, bob);
        vm.stopPrank();

        // Check health again - should be less healthy
        vm.prank(keeper);
        (isHealthy, ) = safetyModule.performHealthCheck();
        // Ratio is now 20k / 200k = 10%, WARNING level
        assertFalse(isHealthy);
    }

    // ============ Oracle Rate Update Flow Tests ============

    function test_OracleRateUpdateFlow() public {
        // Get initial rate
        uint256 initialRate = coreVault.seniorFixedRate();

        // Update oracle
        vm.prank(deployer);
        rateOracle.updateRate(0, 400); // Update TESR

        // Sync rate from oracle
        vm.prank(keeper);
        coreVault.syncSeniorRateFromOracle();

        uint256 newRate = coreVault.seniorFixedRate();

        // Rate should have changed
        assertTrue(newRate != initialRate);
    }

    // ============ Epoch Manager Flow Tests ============

    function test_EpochWithdrawalFlow() public {
        uint256 depositAmount = 50_000e6;

        // Alice deposits to Senior
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), depositAmount);
        uint256 shares = seniorVault.deposit(depositAmount, alice);

        // Request withdrawal
        seniorVault.approve(address(epochManager), shares / 2);
        epochManager.requestWithdraw(true, shares / 2);
        vm.stopPrank();

        // Verify pending request
        IEpochManager.WithdrawRequest[] memory requests = epochManager.getUserWithdrawRequests(alice);
        assertEq(requests.length, 1);
        assertEq(requests[0].shares, shares / 2);

        // Get current epoch ID and lock
        uint256 epochId = epochManager.currentEpochId();
        vm.prank(keeper);
        epochManager.lockEpoch(epochId);

        // Wait for epoch to end
        vm.warp(block.timestamp + 7 days);

        // Process epoch - this automatically processes withdrawals
        uint256 balanceBefore = usdc.balanceOf(alice);
        vm.prank(keeper);
        epochManager.processEpoch();
        uint256 balanceAfter = usdc.balanceOf(alice);

        // Alice should have received assets
        assertTrue(balanceAfter > balanceBefore);
    }

    // ============ Early Withdrawal Penalty Tests ============

    function test_EarlyWithdrawalPenalty() public {
        uint256 depositAmount = 50_000e6;

        // Alice deposits
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), depositAmount);
        uint256 shares = seniorVault.deposit(depositAmount, alice);

        // Early withdrawal
        seniorVault.approve(address(epochManager), shares);
        uint256 balanceBefore = usdc.balanceOf(alice);
        epochManager.earlyWithdraw(true, shares);
        uint256 balanceAfter = usdc.balanceOf(alice);
        vm.stopPrank();

        // Should receive less than deposit due to penalty
        uint256 received = balanceAfter - balanceBefore;
        assertTrue(received < depositAmount);

        // Penalty accumulated
        assertTrue(epochManager.accumulatedPenalties() > 0);
    }

    // ============ Junior Slashing Scenario Tests ============

    function test_JuniorSlashingScenario() public {
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

        // Simulate loss - CoreVault slashes Junior
        uint256 slashAmount = 5_000e6;
        vm.prank(address(coreVault));
        juniorVault.slashPrincipal(slashAmount);

        // Junior principal reduced
        assertEq(juniorVault.totalPrincipal(), juniorDeposit - slashAmount);

        // Bob's effective assets reduced
        uint256 bobShares = juniorVault.balanceOf(bob);
        uint256 bobAssets = juniorVault.previewRedeem(bobShares);
        assertTrue(bobAssets < juniorDeposit);
    }

    // ============ Strategy Rebalancing Tests ============

    function test_StrategyRebalancing() public {
        uint256 depositAmount = 100_000e6;

        // Mint USDC to deployer for deposit
        usdc.mint(deployer, depositAmount);

        // Grant vault role to this contract for testing
        vm.prank(deployer);
        strategy.grantRole(VAULT_ROLE, address(this));

        // Deposit (as deployer)
        usdc.approve(address(strategy), depositAmount);
        strategy.deposit(depositAmount);

        // Check initial allocation
        VaultStrategy.Allocation memory allocation = strategy.getCurrentAllocation();

        // Rebalance
        vm.prank(keeper);
        strategy.rebalance();

        // Allocation should match target
        VaultStrategy.Allocation memory target = strategy.getTargetAllocation();
        VaultStrategy.Allocation memory current = strategy.getCurrentAllocation();

        assertEq(current.mEthRatio, target.mEthRatio);
        assertEq(current.usdcRatio, target.usdcRatio);
        assertEq(current.rwaRatio, target.rwaRatio);
    }

    // ============ End-to-End Scenario Tests ============

    function test_EndToEndScenario() public {
        // 1. Users deposit
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), 100_000e6);
        seniorVault.deposit(100_000e6, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(juniorVault), 25_000e6);
        juniorVault.deposit(25_000e6, bob);
        vm.stopPrank();

        // 2. Funds deployed to strategy
        usdc.mint(address(coreVault), 125_000e6);
        vm.prank(deployer);
        coreVault.deployToStrategy(125_000e6);

        // 3. Time passes, yield accrues
        vm.warp(block.timestamp + 30 days);

        // 4. Harvest yield
        vm.prank(keeper);
        coreVault.harvest();

        // 5. Check protocol health
        vm.prank(keeper);
        (bool isHealthy, ) = safetyModule.performHealthCheck();
        assertTrue(isHealthy);

        // 6. Alice requests withdrawal
        uint256 aliceShares = seniorVault.balanceOf(alice);
        vm.startPrank(alice);
        seniorVault.approve(address(epochManager), aliceShares);
        epochManager.requestWithdraw(true, aliceShares);
        vm.stopPrank();

        // 7. Process epoch
        uint256 epochId = epochManager.currentEpochId();
        vm.prank(keeper);
        epochManager.lockEpoch(epochId);
        vm.warp(block.timestamp + 7 days);

        // 8. Process epoch - automatically sends funds to Alice
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        vm.prank(keeper);
        epochManager.processEpoch();
        uint256 aliceBalanceAfter = usdc.balanceOf(alice);

        uint256 received = aliceBalanceAfter - aliceBalanceBefore;
        assertTrue(received >= 100_000e6); // At least principal
    }

    // ============ Emergency Role Tests ============

    function test_EmergencyWithdrawScenario() public {
        uint256 seniorDeposit = 100_000e6;
        uint256 juniorDeposit = 25_000e6;

        // Users deposit
        vm.startPrank(alice);
        usdc.approve(address(seniorVault), seniorDeposit);
        seniorVault.deposit(seniorDeposit, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(juniorVault), juniorDeposit);
        juniorVault.deposit(juniorDeposit, bob);
        vm.stopPrank();

        // Deploy to strategy
        usdc.mint(address(coreVault), seniorDeposit + juniorDeposit);
        vm.prank(deployer);
        coreVault.deployToStrategy(seniorDeposit + juniorDeposit);

        // Emergency situation - withdraw all funds
        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);

        vm.prank(deployer);
        coreVault.emergencyWithdraw();

        // Should be in emergency mode
        assertTrue(coreVault.emergencyMode());

        // Funds should be in treasury
        uint256 treasuryBalanceAfter = usdc.balanceOf(treasury);
        assertTrue(treasuryBalanceAfter > treasuryBalanceBefore);
    }

    function test_DisableEmergencyMode() public {
        // Trigger emergency mode
        vm.startPrank(deployer);
        coreVault.emergencyWithdraw();
        assertTrue(coreVault.emergencyMode());

        // Disable emergency mode
        coreVault.disableEmergencyMode();
        assertFalse(coreVault.emergencyMode());
        vm.stopPrank();
    }

    // ============ Oracle Role Tests ============

    function test_OracleRateUpdate() public {
        // Get initial rate source
        DOORRateOracle.RateSource memory initialSource = rateOracle.getRateSource(0);
        uint256 initialRate = initialSource.rate; // Should be 350

        // Update oracle rate (within MAX_RATE_CHANGE of 200)
        vm.prank(deployer);
        rateOracle.updateRate(0, 500); // Update TESR to 5% (change of 150)

        // Check rate changed immediately
        DOORRateOracle.RateSource memory newSource = rateOracle.getRateSource(0);
        assertEq(newSource.rate, 500);
        assertTrue(newSource.rate != initialRate);
    }

    function test_OracleBatchUpdate() public {
        uint256[] memory sourceIds = new uint256[](2);
        sourceIds[0] = 0; // TESR
        sourceIds[1] = 1; // AAVE

        uint256[] memory newRates = new uint256[](2);
        newRates[0] = 550; // 5.5%
        newRates[1] = 450; // 4.5%

        // Batch update
        vm.prank(deployer);
        rateOracle.batchUpdateRates(sourceIds, newRates);

        // Verify updated
        DOORRateOracle.RateSource memory tesrSource = rateOracle.getRateSource(0);
        DOORRateOracle.RateSource memory aaveSource = rateOracle.getRateSource(1);

        assertEq(tesrSource.rate, 550);
        assertEq(aaveSource.rate, 450);
    }
}
