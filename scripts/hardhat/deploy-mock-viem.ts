import hre from 'hardhat';
import { parseUnits, formatUnits } from 'viem';
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
  console.log('   DOOR Protocol Deployment (Viem)');
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

  // Phase 1: Deploy Mock Tokens
  console.log('--- Phase 1: Deploying Mock Tokens ---');

  const mockUSDC = await hre.viem.deployContract('MockUSDC');
  console.log('MockUSDC deployed at:', mockUSDC.address);

  const mockMETH = await hre.viem.deployContract('MockMETH');
  console.log('MockMETH deployed at:', mockMETH.address);

  // Phase 2: Deploy Tranche Vaults
  console.log('\n--- Phase 2: Deploying Tranche Vaults ---');

  const seniorVault = await hre.viem.deployContract('SeniorVault', [
    mockUSDC.address,
  ]);
  console.log('SeniorVault deployed at:', seniorVault.address);

  const juniorVault = await hre.viem.deployContract('JuniorVault', [
    mockUSDC.address,
  ]);
  console.log('JuniorVault deployed at:', juniorVault.address);

  // Phase 3: Deploy Core Infrastructure
  console.log('\n--- Phase 3: Deploying Core Infrastructure ---');

  const coreVault = await hre.viem.deployContract('CoreVault', [
    mockUSDC.address,
    seniorVault.address,
    juniorVault.address,
  ]);
  console.log('CoreVault deployed at:', coreVault.address);

  const epochManager = await hre.viem.deployContract('EpochManager', [
    mockUSDC.address,
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
    mockUSDC.address,
    mockMETH.address,
  ]);
  console.log('VaultStrategy deployed at:', vaultStrategy.address);

  const mockYieldStrategy = await hre.viem.deployContract('MockYieldStrategy', [
    mockUSDC.address,
  ]);
  console.log('MockYieldStrategy deployed at:', mockYieldStrategy.address);

  // Phase 4: Initialize Contracts
  console.log('\n--- Phase 4: Initializing Contracts ---');

  await seniorVault.write.initialize([coreVault.address]);
  console.log('SeniorVault initialized');

  await juniorVault.write.initialize([coreVault.address]);
  console.log('JuniorVault initialized');

  await coreVault.write.initialize([
    mockYieldStrategy.address,
    rateOracle.address,
    treasury as `0x${string}`,
  ]);
  console.log('CoreVault initialized');

  await epochManager.write.initialize();
  console.log('EpochManager initialized');

  await vaultStrategy.write.initialize([coreVault.address]);
  console.log('VaultStrategy initialized');

  await mockYieldStrategy.write.setOwner([coreVault.address]);
  console.log('MockYieldStrategy owner set');

  // Phase 5: Setup Roles
  console.log('\n--- Phase 5: Setting Up Roles ---');

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

  // Save deployment addresses
  const deployment: DeploymentAddresses = {
    network: hre.network.name,
    chainId,
    deployer: deployerAddress,
    treasury,
    contracts: {
      MockUSDC: mockUSDC.address,
      MockMETH: mockMETH.address,
      SeniorVault: seniorVault.address,
      JuniorVault: juniorVault.address,
      CoreVault: coreVault.address,
      EpochManager: epochManager.address,
      SafetyModule: safetyModule.address,
      DOORRateOracle: rateOracle.address,
      VaultStrategy: vaultStrategy.address,
      MockYieldStrategy: mockYieldStrategy.address,
    },
    timestamp: new Date().toISOString(),
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
