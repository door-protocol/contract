import hre from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Recover Partial Deployment
 *
 * Use this script when deployment was interrupted and contracts need initialization.
 * This script checks the initialization status of all contracts and completes
 * any missing initialization steps.
 *
 * Features:
 * - Checks initialization status before attempting to initialize
 * - Handles network errors gracefully
 * - Provides clear error messages for manual recovery
 *
 * Use cases:
 * - Deployment interrupted during initialization phase
 * - Network errors caused initialization failures
 * - Need to resume deployment from a specific point
 *
 * Usage:
 *   npx hardhat run scripts/hardhat/recover-partial-deployment.ts --network mantleTestnet
 */

interface PartialDeployment {
  network: string;
  chainId: number;
  deployer: string;
  treasury: string;
  contracts: {
    MockUSDC: string;
    MockMETH: string;
    SeniorVault: string;
    JuniorVault: string;
    CoreVault: string;
    EpochManager: string;
    SafetyModule: string;
    DOORRateOracle: string;
    VaultStrategy: string;
    MockYieldStrategy: string;
  };
}

async function main() {
  console.log('========================================');
  console.log('   DOOR Protocol - Finish Initialization');
  console.log('========================================\n');

  const [deployer] = await hre.viem.getWalletClients();
  const publicClient = await hre.viem.getPublicClient();

  const deployerAddress = deployer.account.address;
  const treasury = process.env.TREASURY_ADDRESS || deployerAddress;
  const chainId = await publicClient.getChainId();

  console.log('Network:', hre.network.name);
  console.log('Chain ID:', chainId);
  console.log('Deployer:', deployerAddress);
  console.log('');

  // ============================================================================
  // UPDATE THESE ADDRESSES WITH YOUR DEPLOYED CONTRACTS
  // ============================================================================
  const ADDRESSES = {
    MockUSDC: '0xa9fd59bf5009da2d002a474309ca38a8d8686f6a',
    MockMETH: '0xac8fc1d5593ada635c5569e35534bfab1ab2fedc',
    SeniorVault: '0x03f4903c3fcf0cb23bee2c11531afb8a1307ce91',
    JuniorVault: '0x694c667c3b7ba5620c68fe1cc3b308eed26afc6e',
    CoreVault: '0x8d3ed9a02d3f1e05f68a306037edaf9a54a16105',
    EpochManager: '0xdc0f912aa970f2a89381985a8e0ea3128e754748',
    SafetyModule: '0xab5fd152973f5430991df6c5b74a5559ffa0d189',
    DOORRateOracle: '0xe76e27759b2416ec7c9ddf8ed7a58e61030876a4',
    VaultStrategy: '0xdd84c599f3b9a12d7f8e583539f11a3e1d9224df',
    MockYieldStrategy: '0x403e548ec79ade195db7e7abaa0eb203bbaa1db0',
  };

  console.log('Using deployed contract addresses...\n');

  // Get contract instances
  const seniorVault = await hre.viem.getContractAt(
    'SeniorVault',
    ADDRESSES.SeniorVault as `0x${string}`,
  );
  const juniorVault = await hre.viem.getContractAt(
    'JuniorVault',
    ADDRESSES.JuniorVault as `0x${string}`,
  );
  const coreVault = await hre.viem.getContractAt(
    'CoreVault',
    ADDRESSES.CoreVault as `0x${string}`,
  );
  const epochManager = await hre.viem.getContractAt(
    'EpochManager',
    ADDRESSES.EpochManager as `0x${string}`,
  );
  const vaultStrategy = await hre.viem.getContractAt(
    'VaultStrategy',
    ADDRESSES.VaultStrategy as `0x${string}`,
  );
  const mockYieldStrategy = await hre.viem.getContractAt(
    'MockYieldStrategy',
    ADDRESSES.MockYieldStrategy as `0x${string}`,
  );
  const safetyModule = await hre.viem.getContractAt(
    'SafetyModule',
    ADDRESSES.SafetyModule as `0x${string}`,
  );

  // ============================================================================
  // Initialize contracts if not already initialized
  // ============================================================================

  console.log('--- Checking Initialization Status ---');

  // Check SeniorVault
  try {
    const seniorInitialized = await seniorVault.read.initialized();
    console.log(`SeniorVault initialized: ${seniorInitialized}`);
    if (!seniorInitialized) {
      console.log('Initializing SeniorVault...');
      await seniorVault.write.initialize([
        ADDRESSES.CoreVault as `0x${string}`,
      ]);
      console.log('✓ SeniorVault initialized');
    }
  } catch (e) {
    console.log('Error checking SeniorVault:', (e as Error).message);
  }

  // Check JuniorVault - THIS IS THE ONE THAT FAILED
  try {
    const juniorInitialized = await juniorVault.read.initialized();
    console.log(`JuniorVault initialized: ${juniorInitialized}`);
    if (!juniorInitialized) {
      console.log('Initializing JuniorVault...');
      // Add a delay and retry logic
      await new Promise((resolve) => setTimeout(resolve, 5000));
      await juniorVault.write.initialize([
        ADDRESSES.CoreVault as `0x${string}`,
      ]);
      console.log('✓ JuniorVault initialized');
    }
  } catch (e) {
    console.log('Error with JuniorVault:', (e as Error).message);
    console.log('You may need to initialize manually via Etherscan');
  }

  // Check CoreVault
  try {
    const coreInitialized = await coreVault.read.initialized();
    console.log(`CoreVault initialized: ${coreInitialized}`);
    if (!coreInitialized) {
      console.log('Initializing CoreVault...');
      await coreVault.write.initialize([
        ADDRESSES.MockYieldStrategy as `0x${string}`,
        ADDRESSES.DOORRateOracle as `0x${string}`,
        treasury as `0x${string}`,
      ]);
      console.log('✓ CoreVault initialized');
    }
  } catch (e) {
    console.log('Error checking CoreVault:', (e as Error).message);
  }

  // Check EpochManager
  try {
    const epochInitialized = await epochManager.read.initialized();
    console.log(`EpochManager initialized: ${epochInitialized}`);
    if (!epochInitialized) {
      console.log('Initializing EpochManager...');
      await epochManager.write.initialize();
      console.log('✓ EpochManager initialized');
    }
  } catch (e) {
    console.log('Error checking EpochManager:', (e as Error).message);
  }

  // Check VaultStrategy
  try {
    const strategyInitialized = await vaultStrategy.read.initialized();
    console.log(`VaultStrategy initialized: ${strategyInitialized}`);
    if (!strategyInitialized) {
      console.log('Initializing VaultStrategy...');
      await vaultStrategy.write.initialize([
        ADDRESSES.CoreVault as `0x${string}`,
      ]);
      console.log('✓ VaultStrategy initialized');
    }
  } catch (e) {
    console.log('Error checking VaultStrategy:', (e as Error).message);
  }

  // Set MockYieldStrategy owner
  try {
    const currentOwner = (await mockYieldStrategy.read.owner()) as string;
    console.log(`MockYieldStrategy owner: ${currentOwner}`);
    if (currentOwner.toLowerCase() !== ADDRESSES.CoreVault.toLowerCase()) {
      console.log('Setting MockYieldStrategy owner...');
      await mockYieldStrategy.write.setOwner([
        ADDRESSES.CoreVault as `0x${string}`,
      ]);
      console.log('✓ MockYieldStrategy owner set');
    }
  } catch (e) {
    console.log('Error with MockYieldStrategy:', (e as Error).message);
  }

  // ============================================================================
  // Setup Roles
  // ============================================================================

  console.log('\n--- Setting Up Roles ---');

  try {
    const KEEPER_ROLE = await coreVault.read.KEEPER_ROLE();
    const STRATEGY_ROLE = await coreVault.read.STRATEGY_ROLE();

    // Grant roles if not already granted
    const hasKeeperRole = await coreVault.read.hasRole([
      KEEPER_ROLE,
      deployerAddress,
    ]);
    if (!hasKeeperRole) {
      await coreVault.write.grantRole([KEEPER_ROLE, deployerAddress]);
      console.log('KEEPER_ROLE granted to deployer on CoreVault');
    }

    const hasStrategyRole = await coreVault.read.hasRole([
      STRATEGY_ROLE,
      deployerAddress,
    ]);
    if (!hasStrategyRole) {
      await coreVault.write.grantRole([STRATEGY_ROLE, deployerAddress]);
      console.log('STRATEGY_ROLE granted to deployer on CoreVault');
    }

    // Other roles...
    const hasEpochKeeperRole = await epochManager.read.hasRole([
      KEEPER_ROLE,
      deployerAddress,
    ]);
    if (!hasEpochKeeperRole) {
      await epochManager.write.grantRole([KEEPER_ROLE, deployerAddress]);
      console.log('KEEPER_ROLE granted to deployer on EpochManager');
    }

    const hasSafetyKeeperRole = await safetyModule.read.hasRole([
      KEEPER_ROLE,
      deployerAddress,
    ]);
    if (!hasSafetyKeeperRole) {
      await safetyModule.write.grantRole([KEEPER_ROLE, deployerAddress]);
      console.log('KEEPER_ROLE granted to deployer on SafetyModule');
    }

    const hasVaultStrategyKeeperRole = await vaultStrategy.read.hasRole([
      KEEPER_ROLE,
      deployerAddress,
    ]);
    if (!hasVaultStrategyKeeperRole) {
      await vaultStrategy.write.grantRole([KEEPER_ROLE, deployerAddress]);
      console.log('KEEPER_ROLE granted to deployer on VaultStrategy');
    }
  } catch (e) {
    console.log('Error setting up roles:', (e as Error).message);
  }

  // Save deployment addresses
  const deployment: PartialDeployment = {
    network: hre.network.name,
    chainId,
    deployer: deployerAddress,
    treasury,
    contracts: {
      MockUSDC: ADDRESSES.MockUSDC,
      MockMETH: ADDRESSES.MockMETH,
      SeniorVault: ADDRESSES.SeniorVault,
      JuniorVault: ADDRESSES.JuniorVault,
      CoreVault: ADDRESSES.CoreVault,
      EpochManager: ADDRESSES.EpochManager,
      SafetyModule: ADDRESSES.SafetyModule,
      DOORRateOracle: ADDRESSES.DOORRateOracle,
      VaultStrategy: ADDRESSES.VaultStrategy,
      MockYieldStrategy: ADDRESSES.MockYieldStrategy,
    },
  };

  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const deploymentPath = path.join(
    deploymentsDir,
    `${hre.network.name}-deployment.json`,
  );
  fs.writeFileSync(deploymentPath, JSON.stringify(deployment, null, 2));

  console.log('\n========================================');
  console.log('   Initialization Complete!');
  console.log('========================================');
  console.log('\nDeployment saved to:', deploymentPath);
  console.log('\nNext steps:');
  console.log('1. If JuniorVault failed to initialize, initialize manually:');
  console.log(
    `   - Go to: https://explorer.sepolia.mantle.xyz/address/${ADDRESSES.JuniorVault}#writeContract`,
  );
  console.log(`   - Call initialize(${ADDRESSES.CoreVault})`);
  console.log('2. Update frontend addresses.ts with these addresses');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
