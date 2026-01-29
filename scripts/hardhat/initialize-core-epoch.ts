import hre from 'hardhat';

/**
 * Initialize CoreVault and EpochManager
 *
 * Use this script when:
 * - CoreVault initialization failed during deployment
 * - EpochManager initialization failed during deployment
 * - You need to manually initialize these two core contracts
 *
 * Usage:
 *   npx hardhat run scripts/hardhat/initialize-core-epoch.ts --network mantleTestnet
 */

const ADDRESSES = {
  CoreVault: '0x6D418348BFfB4196D477DBe2b1082485F5aE5164',
  EpochManager: '0x7cbdd2d816C4d733b36ED131695Ac9cb17684DC3',
  MockVaultStrategy: '0x6dc9D97D7d17B01Eb8D6669a6feF05cc3D3b70d6',
  DOORRateOracle: '0x738c765fB734b774EBbABc9eDb5f099c46542Ee4',
} as const;

async function main() {
  console.log('========================================');
  console.log('   Initialize Core Contracts');
  console.log('========================================\n');

  const [deployer] = await hre.viem.getWalletClients();
  const publicClient = await hre.viem.getPublicClient();

  const deployerAddress = deployer.account.address;
  const treasury = process.env.TREASURY_ADDRESS || deployerAddress;

  console.log('Deployer:', deployerAddress);
  console.log('Treasury:', treasury);
  console.log('');

  // Get contract instances
  const coreVault = await hre.viem.getContractAt(
    'CoreVault',
    ADDRESSES.CoreVault as `0x${string}`,
  );

  const epochManager = await hre.viem.getContractAt(
    'EpochManager',
    ADDRESSES.EpochManager as `0x${string}`,
  );

  // Initialize CoreVault
  console.log('--- Initializing CoreVault ---');
  try {
    const isInitialized = await coreVault.read.initialized();
    console.log(`CoreVault initialized: ${isInitialized}`);

    if (!isInitialized) {
      console.log('Calling CoreVault.initialize()...');
      console.log('  strategy:', ADDRESSES.MockVaultStrategy);
      console.log('  rateOracle:', ADDRESSES.DOORRateOracle);
      console.log('  treasury:', treasury);

      const hash = await coreVault.write.initialize([
        ADDRESSES.MockVaultStrategy as `0x${string}`,
        ADDRESSES.DOORRateOracle as `0x${string}`,
        treasury as `0x${string}`,
      ]);

      console.log('Transaction hash:', hash);
      console.log('Waiting for confirmation...');

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      console.log('✅ CoreVault initialized! Block:', receipt.blockNumber);
    } else {
      console.log('✅ CoreVault already initialized');
    }
  } catch (e) {
    console.log('❌ CoreVault initialization failed:', (e as Error).message);
  }

  // Wait between transactions
  console.log('\nWaiting 10 seconds before next transaction...\n');
  await new Promise((resolve) => setTimeout(resolve, 10000));

  // Initialize EpochManager
  console.log('--- Initializing EpochManager ---');
  try {
    const isInitialized = await epochManager.read.initialized();
    console.log(`EpochManager initialized: ${isInitialized}`);

    if (!isInitialized) {
      console.log('Calling EpochManager.initialize()...');

      const hash = await epochManager.write.initialize();

      console.log('Transaction hash:', hash);
      console.log('Waiting for confirmation...');

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      console.log('✅ EpochManager initialized! Block:', receipt.blockNumber);
    } else {
      console.log('✅ EpochManager already initialized');
    }
  } catch (e) {
    console.log('❌ EpochManager initialization failed:', (e as Error).message);
  }

  // Wait between transactions
  console.log('\nWaiting 10 seconds before next transaction...\n');
  await new Promise((resolve) => setTimeout(resolve, 10000));

  // Initialize MockVaultStrategy
  console.log('--- Initializing MockVaultStrategy ---');
  try {
    const mockVaultStrategy = await hre.viem.getContractAt(
      'MockVaultStrategy',
      ADDRESSES.MockVaultStrategy as `0x${string}`,
    );

    const isInitialized = await mockVaultStrategy.read.initialized();
    console.log(`MockVaultStrategy initialized: ${isInitialized}`);

    if (!isInitialized) {
      console.log('Calling MockVaultStrategy.initialize()...');

      const hash = await mockVaultStrategy.write.initialize([
        ADDRESSES.CoreVault as `0x${string}`,
      ]);

      console.log('Transaction hash:', hash);
      console.log('Waiting for confirmation...');

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      console.log('✅ MockVaultStrategy initialized! Block:', receipt.blockNumber);
    } else {
      console.log('✅ MockVaultStrategy already initialized');
    }
  } catch (e) {
    console.log('❌ MockVaultStrategy initialization failed:', (e as Error).message);
  }

  // Wait between transactions
  console.log('\nWaiting 10 seconds before next transaction...\n');
  await new Promise((resolve) => setTimeout(resolve, 10000));

  // Grant roles
  console.log('--- Granting Roles ---');
  try {
    const KEEPER_ROLE = await coreVault.read.KEEPER_ROLE();
    const STRATEGY_ROLE = await coreVault.read.STRATEGY_ROLE();

    // Get MockVaultStrategy instance
    const mockVaultStrategy = await hre.viem.getContractAt(
      'MockVaultStrategy',
      ADDRESSES.MockVaultStrategy as `0x${string}`,
    );
    const VAULT_ROLE = await mockVaultStrategy.read.VAULT_ROLE();

    // Grant KEEPER_ROLE to deployer on CoreVault
    const coreKeeperRole = await coreVault.read.hasRole([KEEPER_ROLE, deployerAddress]);
    if (!coreKeeperRole) {
      console.log('Granting KEEPER_ROLE to deployer on CoreVault...');
      await coreVault.write.grantRole([KEEPER_ROLE, deployerAddress]);
      console.log('✅ KEEPER_ROLE granted to deployer on CoreVault');
    } else {
      console.log('✅ Deployer already has KEEPER_ROLE on CoreVault');
    }

    // Grant KEEPER_ROLE to EpochManager on CoreVault
    const epochKeeperRole = await coreVault.read.hasRole([KEEPER_ROLE, ADDRESSES.EpochManager]);
    if (!epochKeeperRole) {
      console.log('Granting KEEPER_ROLE to EpochManager on CoreVault...');
      await coreVault.write.grantRole([KEEPER_ROLE, ADDRESSES.EpochManager]);
      console.log('✅ KEEPER_ROLE granted to EpochManager on CoreVault');
    } else {
      console.log('✅ EpochManager already has KEEPER_ROLE on CoreVault');
    }

    // Grant STRATEGY_ROLE to deployer on CoreVault
    const strategyRole = await coreVault.read.hasRole([STRATEGY_ROLE, deployerAddress]);
    if (!strategyRole) {
      console.log('Granting STRATEGY_ROLE to deployer on CoreVault...');
      await coreVault.write.grantRole([STRATEGY_ROLE, deployerAddress]);
      console.log('✅ STRATEGY_ROLE granted to deployer on CoreVault');
    } else {
      console.log('✅ Deployer already has STRATEGY_ROLE on CoreVault');
    }

    // Grant KEEPER_ROLE to deployer on EpochManager
    const epochManagerKeeperRole = await epochManager.read.hasRole([KEEPER_ROLE, deployerAddress]);
    if (!epochManagerKeeperRole) {
      console.log('Granting KEEPER_ROLE to deployer on EpochManager...');
      await epochManager.write.grantRole([KEEPER_ROLE, deployerAddress]);
      console.log('✅ KEEPER_ROLE granted to deployer on EpochManager');
    } else {
      console.log('✅ Deployer already has KEEPER_ROLE on EpochManager');
    }

    // Grant KEEPER_ROLE to deployer on MockVaultStrategy
    const strategyKeeperRole = await mockVaultStrategy.read.hasRole([KEEPER_ROLE, deployerAddress]);
    if (!strategyKeeperRole) {
      console.log('Granting KEEPER_ROLE to deployer on MockVaultStrategy...');
      await mockVaultStrategy.write.grantRole([KEEPER_ROLE, deployerAddress]);
      console.log('✅ KEEPER_ROLE granted to deployer on MockVaultStrategy');
    } else {
      console.log('✅ Deployer already has KEEPER_ROLE on MockVaultStrategy');
    }

    // Grant VAULT_ROLE to CoreVault on MockVaultStrategy
    const vaultRole = await mockVaultStrategy.read.hasRole([VAULT_ROLE, ADDRESSES.CoreVault]);
    if (!vaultRole) {
      console.log('Granting VAULT_ROLE to CoreVault on MockVaultStrategy...');
      await mockVaultStrategy.write.grantRole([VAULT_ROLE, ADDRESSES.CoreVault]);
      console.log('✅ VAULT_ROLE granted to CoreVault on MockVaultStrategy');
    } else {
      console.log('✅ CoreVault already has VAULT_ROLE on MockVaultStrategy');
    }
  } catch (e) {
    console.log('❌ Role grant failed:', (e as Error).message);
  }

  console.log('\n========================================');
  console.log('   Initialization Complete!');
  console.log('========================================');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
