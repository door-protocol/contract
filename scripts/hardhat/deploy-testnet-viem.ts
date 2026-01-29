import hre from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

interface DeploymentAddresses {
  network: string;
  chainId: number;
  deployer: string;
  treasury: string;
  tokens: {
    USDC: string;
    METH: string;
  };
  contracts: {
    SeniorVault: string;
    JuniorVault: string;
    CoreVault: string;
    EpochManager: string;
    SafetyModule: string;
    DOORRateOracle: string;
    VaultStrategy: string;
    MockVaultStrategy: string;
  };
  timestamp: string;
}

// Mantle Sepolia Testnet Token Addresses
const TESTNET_TOKENS = {
  USDC: '0x9a54bad93a00bf1232d4e636f5e53055dc0b8238' as `0x${string}`,
  METH: '0x4Ade8aAa0143526393EcadA836224EF21aBC6ac6' as `0x${string}`,
};

async function main() {
  console.log('========================================');
  console.log('   DOOR Protocol Testnet Deployment (Viem)');
  console.log('========================================\n');

  const [deployer] = await hre.viem.getWalletClients();
  const publicClient = await hre.viem.getPublicClient();

  const deployerAddress = deployer.account.address;
  const treasury = process.env.TREASURY_ADDRESS || deployerAddress;
  const chainId = await publicClient.getChainId();

  console.log('Network:', hre.network.name);
  console.log('Chain ID:', chainId);
  console.log('Deployer:', deployerAddress);
  console.log('Treasury:', treasury);
  console.log('');
  console.log('Using Existing Tokens:');
  console.log('USDC:', TESTNET_TOKENS.USDC);
  console.log('mETH:', TESTNET_TOKENS.METH);
  console.log('');

  // Phase 1: Deploy Tranche Vaults
  console.log('--- Phase 1: Deploying Tranche Vaults ---');

  const seniorVault = await hre.viem.deployContract('SeniorVault', [
    TESTNET_TOKENS.USDC,
  ]);
  console.log('SeniorVault deployed at:', seniorVault.address);

  const juniorVault = await hre.viem.deployContract('JuniorVault', [
    TESTNET_TOKENS.USDC,
  ]);
  console.log('JuniorVault deployed at:', juniorVault.address);

  // Phase 2: Deploy Core Infrastructure
  console.log('\n--- Phase 2: Deploying Core Infrastructure ---');

  const coreVault = await hre.viem.deployContract('CoreVault', [
    TESTNET_TOKENS.USDC,
    seniorVault.address,
    juniorVault.address,
  ]);
  console.log('CoreVault deployed at:', coreVault.address);

  const epochManager = await hre.viem.deployContract('EpochManager', [
    TESTNET_TOKENS.USDC,
    coreVault.address,
    seniorVault.address,
    juniorVault.address,
  ]);
  console.log('EpochManager deployed at:', epochManager.address);

  const safetyModule = await hre.viem.deployContract('SafetyModule', [
    coreVault.address,
  ]);
  console.log('SafetyModule deployed at:', safetyModule.address);

  const rateOracle = await hre.viem.deployContract('DOORRateOracle');
  console.log('DOORRateOracle deployed at:', rateOracle.address);

  const vaultStrategy = await hre.viem.deployContract('VaultStrategy', [
    TESTNET_TOKENS.USDC,
    TESTNET_TOKENS.METH,
  ]);
  console.log('VaultStrategy deployed at:', vaultStrategy.address);

  const mockVaultStrategy = await hre.viem.deployContract('MockVaultStrategy', [
    TESTNET_TOKENS.USDC,
    TESTNET_TOKENS.METH,
  ]);
  console.log('MockVaultStrategy deployed at:', mockVaultStrategy.address);

  // Phase 3: Initialize Contracts
  console.log('\n--- Phase 3: Initializing Contracts ---');

  await seniorVault.write.initialize([coreVault.address]);
  console.log('SeniorVault initialized');

  await juniorVault.write.initialize([coreVault.address]);
  console.log('JuniorVault initialized');

  await coreVault.write.initialize([
    mockVaultStrategy.address,
    rateOracle.address,
    treasury as `0x${string}`,
  ]);
  console.log('CoreVault initialized');

  await coreVault.write.setSafetyModule([safetyModule.address]);
  console.log('CoreVault SafetyModule set');

  await coreVault.write.syncSeniorRateFromSafetyModule();
  console.log('CoreVault synced rate from SafetyModule');

  const seniorFixedRate = await coreVault.read.seniorFixedRate();
  const baseRate = await coreVault.read.baseRate();
  console.log(`  Senior Fixed Rate: ${(Number(seniorFixedRate) / 100).toFixed(1)}%`);
  console.log(`  Base Rate: ${(Number(baseRate) / 100).toFixed(1)}%`);

  await epochManager.write.initialize();
  console.log('EpochManager initialized');

  await vaultStrategy.write.initialize([coreVault.address]);
  console.log('VaultStrategy initialized');

  await mockVaultStrategy.write.initialize([coreVault.address]);
  console.log('MockVaultStrategy initialized');

  // Phase 4: Setup Roles
  console.log('\n--- Phase 4: Setting Up Roles ---');

  const KEEPER_ROLE = await coreVault.read.KEEPER_ROLE();
  const STRATEGY_ROLE = await coreVault.read.STRATEGY_ROLE();

  await coreVault.write.grantRole([KEEPER_ROLE, deployerAddress]);
  console.log('KEEPER_ROLE granted to deployer on CoreVault');

  await coreVault.write.grantRole([STRATEGY_ROLE, deployerAddress]);
  console.log('STRATEGY_ROLE granted to deployer on CoreVault');

  await epochManager.write.grantRole([KEEPER_ROLE, deployerAddress]);
  console.log('KEEPER_ROLE granted to deployer on EpochManager');

  await safetyModule.write.grantRole([KEEPER_ROLE, deployerAddress]);
  console.log('KEEPER_ROLE granted to deployer on SafetyModule');

  await vaultStrategy.write.grantRole([KEEPER_ROLE, deployerAddress]);
  console.log('KEEPER_ROLE granted to deployer on VaultStrategy');

  await mockVaultStrategy.write.grantRole([KEEPER_ROLE, deployerAddress]);
  console.log('KEEPER_ROLE granted to deployer on MockVaultStrategy');

  // Save deployment addresses
  const deployment: DeploymentAddresses = {
    network: hre.network.name,
    chainId,
    deployer: deployerAddress,
    treasury,
    tokens: {
      USDC: TESTNET_TOKENS.USDC,
      METH: TESTNET_TOKENS.METH,
    },
    contracts: {
      SeniorVault: seniorVault.address,
      JuniorVault: juniorVault.address,
      CoreVault: coreVault.address,
      EpochManager: epochManager.address,
      SafetyModule: safetyModule.address,
      DOORRateOracle: rateOracle.address,
      VaultStrategy: vaultStrategy.address,
      MockVaultStrategy: mockVaultStrategy.address,
    },
    timestamp: new Date().toISOString(),
  };

  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const deploymentPath = path.join(
    deploymentsDir,
    `${hre.network.name}-testnet-deployment.json`,
  );
  fs.writeFileSync(deploymentPath, JSON.stringify(deployment, null, 2));

  console.log('\n========================================');
  console.log('   DOOR Protocol Deployed Successfully!');
  console.log('========================================');
  console.log('\nDeployment saved to:', deploymentPath);
  console.log('\nImportant: Make sure you have USDC and mETH on testnet!');
  console.log('USDC Address:', TESTNET_TOKENS.USDC);
  console.log('mETH Address:', TESTNET_TOKENS.METH);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
