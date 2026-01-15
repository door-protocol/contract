import { ethers } from 'hardhat';
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
    MockYieldStrategy: string;
  };
  timestamp: string;
}

// Mantle Sepolia Testnet Token Addresses
const TESTNET_TOKENS = {
  USDC: '0x9a54bad93a00bf1232d4e636f5e53055dc0b8238',
  METH: '0x4Ade8aAa0143526393EcadA836224EF21aBC6ac6',
};

async function main() {
  console.log('========================================');
  console.log('   DOOR Protocol Testnet Deployment (Ethers)');
  console.log('========================================\n');

  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();

  const deployerAddress = await deployer.getAddress();
  const treasury = process.env.TREASURY_ADDRESS || deployerAddress;

  console.log('Network:', network.name);
  console.log('Chain ID:', network.chainId.toString());
  console.log('Deployer:', deployerAddress);
  console.log('Treasury:', treasury);
  console.log('');
  console.log('Using Existing Tokens:');
  console.log('USDC:', TESTNET_TOKENS.USDC);
  console.log('mETH:', TESTNET_TOKENS.METH);
  console.log('');

  // Phase 1: Deploy Tranche Vaults
  console.log('--- Phase 1: Deploying Tranche Vaults ---');

  const SeniorVault = await ethers.getContractFactory('SeniorVault');
  const seniorVault = await SeniorVault.deploy(TESTNET_TOKENS.USDC);
  await seniorVault.waitForDeployment();
  const seniorVaultAddress = await seniorVault.getAddress();
  console.log('SeniorVault deployed at:', seniorVaultAddress);

  const JuniorVault = await ethers.getContractFactory('JuniorVault');
  const juniorVault = await JuniorVault.deploy(TESTNET_TOKENS.USDC);
  await juniorVault.waitForDeployment();
  const juniorVaultAddress = await juniorVault.getAddress();
  console.log('JuniorVault deployed at:', juniorVaultAddress);

  // Phase 2: Deploy Core Infrastructure
  console.log('\n--- Phase 2: Deploying Core Infrastructure ---');

  const CoreVault = await ethers.getContractFactory('CoreVault');
  const coreVault = await CoreVault.deploy(
    TESTNET_TOKENS.USDC,
    seniorVaultAddress,
    juniorVaultAddress,
  );
  await coreVault.waitForDeployment();
  const coreVaultAddress = await coreVault.getAddress();
  console.log('CoreVault deployed at:', coreVaultAddress);

  const EpochManager = await ethers.getContractFactory('EpochManager');
  const epochManager = await EpochManager.deploy(
    TESTNET_TOKENS.USDC,
    coreVaultAddress,
    seniorVaultAddress,
    juniorVaultAddress,
  );
  await epochManager.waitForDeployment();
  const epochManagerAddress = await epochManager.getAddress();
  console.log('EpochManager deployed at:', epochManagerAddress);

  const SafetyModule = await ethers.getContractFactory('SafetyModule');
  const safetyModule = await SafetyModule.deploy(coreVaultAddress);
  await safetyModule.waitForDeployment();
  const safetyModuleAddress = await safetyModule.getAddress();
  console.log('SafetyModule deployed at:', safetyModuleAddress);

  const DOORRateOracle = await ethers.getContractFactory('DOORRateOracle');
  const rateOracle = await DOORRateOracle.deploy();
  await rateOracle.waitForDeployment();
  const rateOracleAddress = await rateOracle.getAddress();
  console.log('DOORRateOracle deployed at:', rateOracleAddress);

  const VaultStrategy = await ethers.getContractFactory('VaultStrategy');
  const vaultStrategy = await VaultStrategy.deploy(
    TESTNET_TOKENS.USDC,
    TESTNET_TOKENS.METH,
  );
  await vaultStrategy.waitForDeployment();
  const vaultStrategyAddress = await vaultStrategy.getAddress();
  console.log('VaultStrategy deployed at:', vaultStrategyAddress);

  const MockYieldStrategy =
    await ethers.getContractFactory('MockYieldStrategy');
  const mockYieldStrategy = await MockYieldStrategy.deploy(TESTNET_TOKENS.USDC);
  await mockYieldStrategy.waitForDeployment();
  const mockYieldStrategyAddress = await mockYieldStrategy.getAddress();
  console.log('MockYieldStrategy deployed at:', mockYieldStrategyAddress);

  // Phase 3: Initialize Contracts
  console.log('\n--- Phase 3: Initializing Contracts ---');

  await (await seniorVault.initialize(coreVaultAddress)).wait();
  console.log('SeniorVault initialized');

  await (await juniorVault.initialize(coreVaultAddress)).wait();
  console.log('JuniorVault initialized');

  await (
    await coreVault.initialize(
      mockYieldStrategyAddress,
      rateOracleAddress,
      treasury,
    )
  ).wait();
  console.log('CoreVault initialized');

  await (await epochManager.initialize()).wait();
  console.log('EpochManager initialized');

  await (await vaultStrategy.initialize(coreVaultAddress)).wait();
  console.log('VaultStrategy initialized');

  await (await mockYieldStrategy.setOwner(coreVaultAddress)).wait();
  console.log('MockYieldStrategy owner set');

  // Phase 4: Setup Roles
  console.log('\n--- Phase 4: Setting Up Roles ---');

  const KEEPER_ROLE = await coreVault.KEEPER_ROLE();
  const STRATEGY_ROLE = await coreVault.STRATEGY_ROLE();

  await (await coreVault.grantRole(KEEPER_ROLE, deployerAddress)).wait();
  console.log('KEEPER_ROLE granted to deployer on CoreVault');

  await (await coreVault.grantRole(STRATEGY_ROLE, deployerAddress)).wait();
  console.log('STRATEGY_ROLE granted to deployer on CoreVault');

  await (await epochManager.grantRole(KEEPER_ROLE, deployerAddress)).wait();
  console.log('KEEPER_ROLE granted to deployer on EpochManager');

  await (await safetyModule.grantRole(KEEPER_ROLE, deployerAddress)).wait();
  console.log('KEEPER_ROLE granted to deployer on SafetyModule');

  await (await vaultStrategy.grantRole(KEEPER_ROLE, deployerAddress)).wait();
  console.log('KEEPER_ROLE granted to deployer on VaultStrategy');

  // Save deployment addresses
  const deployment: DeploymentAddresses = {
    network: network.name,
    chainId: Number(network.chainId),
    deployer: deployerAddress,
    treasury,
    tokens: {
      USDC: TESTNET_TOKENS.USDC,
      METH: TESTNET_TOKENS.METH,
    },
    contracts: {
      SeniorVault: seniorVaultAddress,
      JuniorVault: juniorVaultAddress,
      CoreVault: coreVaultAddress,
      EpochManager: epochManagerAddress,
      SafetyModule: safetyModuleAddress,
      DOORRateOracle: rateOracleAddress,
      VaultStrategy: vaultStrategyAddress,
      MockYieldStrategy: mockYieldStrategyAddress,
    },
    timestamp: new Date().toISOString(),
  };

  const deploymentsDir = path.join(__dirname, '..', 'deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const deploymentPath = path.join(
    deploymentsDir,
    `${network.name}-testnet-deployment.json`,
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
