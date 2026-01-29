import * as fs from 'fs';
import * as path from 'path';

// Our core contracts to extract
const CONTRACTS = [
  'CoreVault',
  'SeniorVault',
  'JuniorVault',
  'EpochManager',
  'SafetyModule',
  'DOORRateOracle',
  'VaultStrategy',
  'MockVaultStrategy',
  'MockUSDC',
  'MockMETH',
];

interface ContractArtifact {
  abi: any[];
  bytecode?: {
    object: string;
  };
  deployedBytecode?: {
    object: string;
  };
}

function extractABIs() {
  console.log('========================================');
  console.log('   Extracting Contract ABIs');
  console.log('========================================\n');

  const outDir = path.join(__dirname, '..', 'out');
  const abiDir = path.join(__dirname, '..', 'abi');

  // Create abi directory if it doesn't exist
  if (!fs.existsSync(abiDir)) {
    fs.mkdirSync(abiDir, { recursive: true });
    console.log('Created abi directory\n');
  }

  const results: { name: string; status: string }[] = [];

  for (const contractName of CONTRACTS) {
    try {
      // Look for the contract in out directory
      const contractDir = path.join(outDir, `${contractName}.sol`);
      const artifactPath = path.join(contractDir, `${contractName}.json`);

      if (!fs.existsSync(artifactPath)) {
        results.push({ name: contractName, status: '❌ Not found' });
        continue;
      }

      // Read the artifact
      const artifact: ContractArtifact = JSON.parse(
        fs.readFileSync(artifactPath, 'utf8'),
      );

      // Extract just the ABI
      const abiPath = path.join(abiDir, `${contractName}.json`);
      fs.writeFileSync(abiPath, JSON.stringify(artifact.abi, null, 2));

      results.push({ name: contractName, status: '✓ Extracted' });
    } catch (error) {
      results.push({
        name: contractName,
        status: `❌ Error: ${error instanceof Error ? error.message : 'Unknown'}`,
      });
    }
  }

  // Print results
  console.log('Extraction Results:');
  console.log('─'.repeat(50));
  for (const result of results) {
    console.log(`${result.name.padEnd(25)} ${result.status}`);
  }

  console.log('\n========================================');
  console.log('   ABI Extraction Complete!');
  console.log('========================================');
  console.log(`\nABIs saved to: ${abiDir}\n`);
}

extractABIs();
