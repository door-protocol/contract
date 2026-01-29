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
  CoreVault: '0x8d3ed9a02d3f1e05f68a306037edaf9a54a16105',
  EpochManager: '0xdc0f912aa970f2a89381985a8e0ea3128e754748',
  MockYieldStrategy: '0x403e548ec79ade195db7e7abaa0eb203bbaa1db0',
  DOORRateOracle: '0xe76e27759b2416ec7c9ddf8ed7a58e61030876a4',
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
      console.log('  strategy:', ADDRESSES.MockYieldStrategy);
      console.log('  rateOracle:', ADDRESSES.DOORRateOracle);
      console.log('  treasury:', treasury);

      const hash = await coreVault.write.initialize([
        ADDRESSES.MockYieldStrategy as `0x${string}`,
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

  // Grant KEEPER_ROLE to deployer
  console.log('--- Granting KEEPER_ROLE ---');
  try {
    const KEEPER_ROLE =
      '0x8972ffc6b90eca55e4e01e88a38e090782f47c5f07710cb6a076e12c89d44ce1' as const;

    const hasRole = await epochManager.read.hasRole([
      KEEPER_ROLE,
      deployerAddress,
    ]);
    console.log(`Deployer has KEEPER_ROLE: ${hasRole}`);

    if (!hasRole) {
      console.log('Granting KEEPER_ROLE to deployer...');

      const hash = await epochManager.write.grantRole([
        KEEPER_ROLE,
        deployerAddress,
      ]);

      console.log('Transaction hash:', hash);
      console.log('Waiting for confirmation...');

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      console.log('✅ KEEPER_ROLE granted! Block:', receipt.blockNumber);
    } else {
      console.log('✅ Deployer already has KEEPER_ROLE');
    }
  } catch (e) {
    console.log('❌ KEEPER_ROLE grant failed:', (e as Error).message);
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
