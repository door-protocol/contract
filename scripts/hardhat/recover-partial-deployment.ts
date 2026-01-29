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
    MockVaultStrategy: string;
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
    MockUSDC: '0xbadbbDb50f5F0455Bf6E4Dd6d4B5ee664D07c109',
    MockMETH: '0x374962241A369F1696EF88C10beFe4f40C646592',
    SeniorVault: '0x766624E3E59a80Da9801e9b71994cb927eB7F260',
    JuniorVault: '0x8d1fBEa28CC47959bd94ece489cb1823BeB55075',
    CoreVault: '0x6D418348BFfB4196D477DBe2b1082485F5aE5164',
    EpochManager: '0x7cbdd2d816C4d733b36ED131695Ac9cb17684DC3',
    SafetyModule: '0xE2fa3596C8969bbd28b3dda515BABb268343df4B',
    DOORRateOracle: '0x738c765fB734b774EBbABc9eDb5f099c46542Ee4',
    VaultStrategy: '0xf9579CE4D63174b1f0f5bCB9d42255BDd07a6374',
    MockVaultStrategy: '0x6dc9D97D7d17B01Eb8D6669a6feF05cc3D3b70d6',
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
  const mockVaultStrategy = await hre.viem.getContractAt(
    'MockVaultStrategy',
    ADDRESSES.MockVaultStrategy as `0x${string}`,
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
        ADDRESSES.MockVaultStrategy as `0x${string}`,
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

  // Check MockVaultStrategy
  try {
    const strategyInitialized = await mockVaultStrategy.read.initialized();
    console.log(`MockVaultStrategy initialized: ${strategyInitialized}`);
    if (!strategyInitialized) {
      console.log('Initializing MockVaultStrategy...');
      await mockVaultStrategy.write.initialize([
        ADDRESSES.CoreVault as `0x${string}`,
      ]);
      console.log('✓ MockVaultStrategy initialized');
    }
  } catch (e) {
    console.log('Error with MockVaultStrategy:', (e as Error).message);
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

    // Grant KEEPER_ROLE to deployer on MockVaultStrategy
    const hasMockVaultStrategyKeeperRole = await mockVaultStrategy.read.hasRole([
      KEEPER_ROLE,
      deployerAddress,
    ]);
    if (!hasMockVaultStrategyKeeperRole) {
      await mockVaultStrategy.write.grantRole([KEEPER_ROLE, deployerAddress]);
      console.log('KEEPER_ROLE granted to deployer on MockVaultStrategy');
    }

    // Grant VAULT_ROLE to CoreVault on MockVaultStrategy
    const VAULT_ROLE = await mockVaultStrategy.read.VAULT_ROLE();
    const hasVaultRole = await mockVaultStrategy.read.hasRole([
      VAULT_ROLE,
      ADDRESSES.CoreVault as `0x${string}`,
    ]);
    if (!hasVaultRole) {
      await mockVaultStrategy.write.grantRole([VAULT_ROLE, ADDRESSES.CoreVault as `0x${string}`]);
      console.log('VAULT_ROLE granted to CoreVault on MockVaultStrategy');
    }

    // Grant KEEPER_ROLE to EpochManager on CoreVault
    const hasEpochManagerKeeperOnCore = await coreVault.read.hasRole([
      KEEPER_ROLE,
      ADDRESSES.EpochManager as `0x${string}`,
    ]);
    if (!hasEpochManagerKeeperOnCore) {
      await coreVault.write.grantRole([KEEPER_ROLE, ADDRESSES.EpochManager as `0x${string}`]);
      console.log('KEEPER_ROLE granted to EpochManager on CoreVault');
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
      MockVaultStrategy: ADDRESSES.MockVaultStrategy,
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
