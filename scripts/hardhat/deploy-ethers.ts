import { ethers } from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

interface DeploymentAddresses {
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
  timestamp: string;
}

async function main() {
  console.log('========================================');
  console.log('   DOOR Protocol Deployment (Ethers)');
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

  // Phase 1: Deploy Mock Tokens
  console.log('--- Phase 1: Deploying Mock Tokens ---');

  const MockUSDC = await ethers.getContractFactory('MockUSDC');
  const mockUSDC = await MockUSDC.deploy();
  await mockUSDC.waitForDeployment();
  const mockUSDCAddress = await mockUSDC.getAddress();
  console.log('MockUSDC deployed at:', mockUSDCAddress);

  const MockMETH = await ethers.getContractFactory('MockMETH');
  const mockMETH = await MockMETH.deploy();
  await mockMETH.waitForDeployment();
  const mockMETHAddress = await mockMETH.getAddress();
  console.log('MockMETH deployed at:', mockMETHAddress);

  // Phase 2: Deploy Tranche Vaults
  console.log('\n--- Phase 2: Deploying Tranche Vaults ---');

  const SeniorVault = await ethers.getContractFactory('SeniorVault');
  const seniorVault = await SeniorVault.deploy(mockUSDCAddress);
  await seniorVault.waitForDeployment();
  const seniorVaultAddress = await seniorVault.getAddress();
  console.log('SeniorVault deployed at:', seniorVaultAddress);

  const JuniorVault = await ethers.getContractFactory('JuniorVault');
  const juniorVault = await JuniorVault.deploy(mockUSDCAddress);
  await juniorVault.waitForDeployment();
  const juniorVaultAddress = await juniorVault.getAddress();
  console.log('JuniorVault deployed at:', juniorVaultAddress);

  // Phase 3: Deploy Core Infrastructure
  console.log('\n--- Phase 3: Deploying Core Infrastructure ---');

  const CoreVault = await ethers.getContractFactory('CoreVault');
  const coreVault = await CoreVault.deploy(
    mockUSDCAddress,
    seniorVaultAddress,
    juniorVaultAddress,
  );
  await coreVault.waitForDeployment();
  const coreVaultAddress = await coreVault.getAddress();
  console.log('CoreVault deployed at:', coreVaultAddress);

  const EpochManager = await ethers.getContractFactory('EpochManager');
  const epochManager = await EpochManager.deploy(
    mockUSDCAddress,
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
    mockUSDCAddress,
    mockMETHAddress,
  );
  await vaultStrategy.waitForDeployment();
  const vaultStrategyAddress = await vaultStrategy.getAddress();
  console.log('VaultStrategy deployed at:', vaultStrategyAddress);

  const MockYieldStrategy =
    await ethers.getContractFactory('MockYieldStrategy');
  const mockYieldStrategy = await MockYieldStrategy.deploy(mockUSDCAddress);
  await mockYieldStrategy.waitForDeployment();
  const mockYieldStrategyAddress = await mockYieldStrategy.getAddress();
  console.log('MockYieldStrategy deployed at:', mockYieldStrategyAddress);

  // Phase 4: Initialize Contracts
  console.log('\n--- Phase 4: Initializing Contracts ---');

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

  // Phase 5: Setup Roles
  console.log('\n--- Phase 5: Setting Up Roles ---');

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
    contracts: {
      MockUSDC: mockUSDCAddress,
      MockMETH: mockMETHAddress,
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
    `${network.name}-deployment.json`,
  );
  fs.writeFileSync(deploymentPath, JSON.stringify(deployment, null, 2));

  console.log('\n========================================');
  console.log('   DOOR Protocol Deployed Successfully!');
  console.log('========================================');
  console.log('\nDeployment saved to:', deploymentPath);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
