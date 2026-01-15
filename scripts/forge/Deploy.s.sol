// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockMETH} from "../../src/mocks/MockMETH.sol";
import {SeniorVault} from "../../src/tranches/SeniorVault.sol";
import {JuniorVault} from "../../src/tranches/JuniorVault.sol";
import {CoreVault} from "../../src/core/CoreVault.sol";
import {EpochManager} from "../../src/epoch/EpochManager.sol";
import {SafetyModule} from "../../src/safety/SafetyModule.sol";
import {DOORRateOracle} from "../../src/oracle/DOORRateOracle.sol";
import {VaultStrategy} from "../../src/strategy/VaultStrategy.sol";
import {MockYieldStrategy} from "../../src/strategy/MockYieldStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Deploy
 * @notice Deployment script for DOOR Protocol
 * @dev Deploys all contracts in correct order with proper initialization
 *
 * Usage:
 *   forge script scripts/forge/Deploy.s.sol:Deploy --rpc-url <RPC_URL> --broadcast
 *
 * For local testing:
 *   forge script scripts/forge/Deploy.s.sol:Deploy --fork-url http://localhost:8545 --broadcast
 */
contract Deploy is Script {
    // Deployed contract addresses
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

    // Configuration
    address public deployer;
    address public treasury;

    function run() public virtual {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));

        if (deployerPrivateKey == 0) {
            // Use default anvil account for local testing
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }

        deployer = vm.addr(deployerPrivateKey);
        treasury = vm.envOr("TREASURY", deployer);

        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);

        vm.startBroadcast(deployerPrivateKey);

        // Phase 1: Deploy Mock Tokens
        _deployMockTokens();

        // Phase 2: Deploy Tranche Vaults
        _deployTrancheVaults();

        // Phase 3: Deploy Core Infrastructure
        _deployCoreInfrastructure();

        // Phase 4: Initialize Contracts
        _initializeContracts();

        // Phase 5: Setup Roles
        _setupRoles();

        vm.stopBroadcast();

        // Log deployed addresses
        _logDeployedAddresses();
    }

    function _deployMockTokens() internal {
        console.log("\n--- Deploying Mock Tokens ---");

        usdc = new MockUSDC();
        console.log("MockUSDC deployed at:", address(usdc));

        meth = new MockMETH();
        console.log("MockMETH deployed at:", address(meth));
    }

    function _deployTrancheVaults() internal {
        console.log("\n--- Deploying Tranche Vaults ---");

        seniorVault = new SeniorVault(IERC20(address(usdc)));
        console.log("SeniorVault deployed at:", address(seniorVault));

        juniorVault = new JuniorVault(IERC20(address(usdc)));
        console.log("JuniorVault deployed at:", address(juniorVault));
    }

    function _deployCoreInfrastructure() internal {
        console.log("\n--- Deploying Core Infrastructure ---");

        // Deploy CoreVault
        coreVault = new CoreVault(address(usdc), address(seniorVault), address(juniorVault));
        console.log("CoreVault deployed at:", address(coreVault));

        // Deploy EpochManager
        epochManager = new EpochManager(
            address(usdc),
            address(coreVault),
            address(seniorVault),
            address(juniorVault)
        );
        console.log("EpochManager deployed at:", address(epochManager));

        // Deploy SafetyModule
        safetyModule = new SafetyModule(address(coreVault));
        console.log("SafetyModule deployed at:", address(safetyModule));

        // Deploy DOORRateOracle
        rateOracle = new DOORRateOracle();
        console.log("DOORRateOracle deployed at:", address(rateOracle));

        // Deploy VaultStrategy
        strategy = new VaultStrategy(address(usdc), address(meth));
        console.log("VaultStrategy deployed at:", address(strategy));

        // Deploy MockYieldStrategy (for testing)
        mockStrategy = new MockYieldStrategy(address(usdc));
        console.log("MockYieldStrategy deployed at:", address(mockStrategy));
    }

    function _initializeContracts() internal {
        console.log("\n--- Initializing Contracts ---");

        // Initialize SeniorVault with CoreVault
        seniorVault.initialize(address(coreVault));
        console.log("SeniorVault initialized");

        // Initialize JuniorVault with CoreVault
        juniorVault.initialize(address(coreVault));
        console.log("JuniorVault initialized");

        // Initialize CoreVault with Strategy, Oracle, and Treasury
        // Using MockYieldStrategy for testing - replace with VaultStrategy in production
        coreVault.initialize(address(mockStrategy), address(rateOracle), treasury);
        console.log("CoreVault initialized");

        // Initialize EpochManager
        epochManager.initialize();
        console.log("EpochManager initialized");

        // Initialize VaultStrategy with CoreVault
        strategy.initialize(address(coreVault));
        console.log("VaultStrategy initialized");

        // Set MockYieldStrategy owner to CoreVault
        mockStrategy.setOwner(address(coreVault));
        console.log("MockYieldStrategy owner set");
    }

    function _setupRoles() internal {
        console.log("\n--- Setting Up Roles ---");

        // Grant KEEPER_ROLE to deployer for CoreVault
        bytes32 KEEPER_ROLE = keccak256("KEEPER_ROLE");
        coreVault.grantRole(KEEPER_ROLE, deployer);
        console.log("KEEPER_ROLE granted to deployer on CoreVault");

        // Grant STRATEGY_ROLE to deployer for CoreVault
        bytes32 STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
        coreVault.grantRole(STRATEGY_ROLE, deployer);
        console.log("STRATEGY_ROLE granted to deployer on CoreVault");

        // Grant roles on EpochManager
        epochManager.grantRole(KEEPER_ROLE, deployer);
        console.log("KEEPER_ROLE granted to deployer on EpochManager");

        // Grant roles on SafetyModule
        safetyModule.grantRole(KEEPER_ROLE, deployer);
        console.log("KEEPER_ROLE granted to deployer on SafetyModule");

        // Grant roles on VaultStrategy
        strategy.grantRole(KEEPER_ROLE, deployer);
        console.log("KEEPER_ROLE granted to deployer on VaultStrategy");
    }

    function _logDeployedAddresses() internal view {
        console.log("\n========================================");
        console.log("       DOOR Protocol Deployed");
        console.log("========================================");
        console.log("\n--- Token Addresses ---");
        console.log("MockUSDC:", address(usdc));
        console.log("MockMETH:", address(meth));
        console.log("\n--- Tranche Addresses ---");
        console.log("SeniorVault:", address(seniorVault));
        console.log("JuniorVault:", address(juniorVault));
        console.log("\n--- Core Addresses ---");
        console.log("CoreVault:", address(coreVault));
        console.log("EpochManager:", address(epochManager));
        console.log("SafetyModule:", address(safetyModule));
        console.log("DOORRateOracle:", address(rateOracle));
        console.log("\n--- Strategy Addresses ---");
        console.log("VaultStrategy:", address(strategy));
        console.log("MockYieldStrategy:", address(mockStrategy));
        console.log("\n--- Configuration ---");
        console.log("Treasury:", treasury);
        console.log("========================================\n");
    }
}

/**
 * @title DeployTestnet
 * @notice Testnet deployment with initial token minting
 */
contract DeployTestnet is Deploy {
    function run() public override {
        super.run();

        // Mint initial tokens for testing
        vm.startBroadcast();

        // Mint USDC to deployer for testing
        usdc.mint(deployer, 1_000_000e6); // 1M USDC
        console.log("Minted 1M USDC to deployer");

        // Mint mETH to deployer for testing
        meth.mint(deployer, 1000e18); // 1000 mETH
        console.log("Minted 1000 mETH to deployer");

        // Mint USDC to strategy for yield simulation
        usdc.mint(address(mockStrategy), 100_000e6); // 100K USDC for yield
        console.log("Minted 100K USDC to MockYieldStrategy for yield simulation");

        vm.stopBroadcast();
    }
}
