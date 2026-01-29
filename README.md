# DOOR Protocol

**Structured DeFi Product with Waterfall Distribution on Mantle Network**

## 🚀 Deployed Contracts (Mantle Sepolia Testnet)

> **⭐ Recommendation**: Use the **Mock Token Deployment** below for testing, as **obtaining sufficient testnet USDC and mETH balance is extremely difficult** on Mantle Sepolia.

### Mock Token Deployment (⭐ RECOMMENDED)

**Deployed on**: 2026-01-15
**Status**: ✅ All contracts initialized and ready to use!

**Why use this deployment?**

- ✅ **No need to obtain testnet USDC/mETH** (very difficult to get sufficient balance)
- ✅ **Instant access** to unlimited test tokens
- ✅ **Full protocol functionality** - same features as production
- ✅ **Perfect for development**, testing, and demos

This deployment includes mock USDC and mETH tokens for isolated testing.

| Contract              | Address                                                                                                                                | Explorer                                                                                         |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **MockUSDC**          | [`0xbadbbDb50f5F0455Bf6E4Dd6d4B5ee664D07c109`](https://explorer.sepolia.mantle.xyz/address/0xbadbbDb50f5F0455Bf6E4Dd6d4B5ee664D07c109) | [View →](https://explorer.sepolia.mantle.xyz/address/0xbadbbDb50f5F0455Bf6E4Dd6d4B5ee664D07c109) |
| **MockMETH**          | [`0x374962241A369F1696EF88C10beFe4f40C646592`](https://explorer.sepolia.mantle.xyz/address/0x374962241A369F1696EF88C10beFe4f40C646592) | [View →](https://explorer.sepolia.mantle.xyz/address/0x374962241A369F1696EF88C10beFe4f40C646592) |
| **SeniorVault**       | [`0x766624E3E59a80Da9801e9b71994cb927eB7F260`](https://explorer.sepolia.mantle.xyz/address/0x766624E3E59a80Da9801e9b71994cb927eB7F260) | [View →](https://explorer.sepolia.mantle.xyz/address/0x766624E3E59a80Da9801e9b71994cb927eB7F260) |
| **JuniorVault**       | [`0x8d1fBEa28CC47959bd94ece489cb1823BeB55075`](https://explorer.sepolia.mantle.xyz/address/0x8d1fBEa28CC47959bd94ece489cb1823BeB55075) | [View →](https://explorer.sepolia.mantle.xyz/address/0x8d1fBEa28CC47959bd94ece489cb1823BeB55075) |
| **CoreVault**         | [`0x6D418348BFfB4196D477DBe2b1082485F5aE5164`](https://explorer.sepolia.mantle.xyz/address/0x6D418348BFfB4196D477DBe2b1082485F5aE5164) | [View →](https://explorer.sepolia.mantle.xyz/address/0x6D418348BFfB4196D477DBe2b1082485F5aE5164) |
| **EpochManager**      | [`0x7cbdd2d816C4d733b36ED131695Ac9cb17684DC3`](https://explorer.sepolia.mantle.xyz/address/0x7cbdd2d816C4d733b36ED131695Ac9cb17684DC3) | [View →](https://explorer.sepolia.mantle.xyz/address/0x7cbdd2d816C4d733b36ED131695Ac9cb17684DC3) |
| **SafetyModule**      | [`0xE2fa3596C8969bbd28b3dda515BABb268343df4B`](https://explorer.sepolia.mantle.xyz/address/0xE2fa3596C8969bbd28b3dda515BABb268343df4B) | [View →](https://explorer.sepolia.mantle.xyz/address/0xE2fa3596C8969bbd28b3dda515BABb268343df4B) |
| **DOORRateOracle**    | [`0x738c765fB734b774EBbABc9eDb5f099c46542Ee4`](https://explorer.sepolia.mantle.xyz/address/0x738c765fB734b774EBbABc9eDb5f099c46542Ee4) | [View →](https://explorer.sepolia.mantle.xyz/address/0x738c765fB734b774EBbABc9eDb5f099c46542Ee4) |
| **MockVaultStrategy** | [`0x6dc9D97D7d17B01Eb8D6669a6feF05cc3D3b70d6`](https://explorer.sepolia.mantle.xyz/address/0x6dc9D97D7d17B01Eb8D6669a6feF05cc3D3b70d6) | [View →](https://explorer.sepolia.mantle.xyz/address/0x6dc9D97D7d17B01Eb8D6669a6feF05cc3D3b70d6) |

---

### Production Deployment (Real Testnet Tokens) - ⚠️ NOT RECOMMENDED

**Deployed on**: 2026-01-15

**⚠️ Important**: This deployment uses real USDC and mETH tokens. However, **obtaining sufficient testnet USDC and mETH balance is extremely difficult** on Mantle Sepolia (no reliable faucet, requires complex bridging). Use the Mock Token Deployment above instead.

This deployment was created for integration testing with actual testnet tokens, but is not recommended for general use due to the difficulty of obtaining sufficient token balances for testing.

| Contract           | Address                                                                                                                                | Explorer                                                                                         |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **SeniorVault**    | [`0x34BC889a143870bBd8538EAe6421cA4c62e84bc3`](https://explorer.sepolia.mantle.xyz/address/0x34BC889a143870bBd8538EAe6421cA4c62e84bc3) | [View →](https://explorer.sepolia.mantle.xyz/address/0x34BC889a143870bBd8538EAe6421cA4c62e84bc3) |
| **JuniorVault**    | [`0x8E1A6A3Ba7c5cb4d416Da7Fd376b2BC75227022e`](https://explorer.sepolia.mantle.xyz/address/0x8E1A6A3Ba7c5cb4d416Da7Fd376b2BC75227022e) | [View →](https://explorer.sepolia.mantle.xyz/address/0x8E1A6A3Ba7c5cb4d416Da7Fd376b2BC75227022e) |
| **CoreVault**      | [`0x1601Aa4aE97b999cEd4bbaCF0D4B52f29554846F`](https://explorer.sepolia.mantle.xyz/address/0x1601Aa4aE97b999cEd4bbaCF0D4B52f29554846F) | [View →](https://explorer.sepolia.mantle.xyz/address/0x1601Aa4aE97b999cEd4bbaCF0D4B52f29554846F) |
| **EpochManager**   | [`0x2956e44668E4026D499D46Ad7eCB1312EA8484aa`](https://explorer.sepolia.mantle.xyz/address/0x2956e44668E4026D499D46Ad7eCB1312EA8484aa) | [View →](https://explorer.sepolia.mantle.xyz/address/0x2956e44668E4026D499D46Ad7eCB1312EA8484aa) |
| **SafetyModule**   | [`0xA08fF559C4Fc41FEf01D26744394dD2d2aa74E55`](https://explorer.sepolia.mantle.xyz/address/0xA08fF559C4Fc41FEf01D26744394dD2d2aa74E55) | [View →](https://explorer.sepolia.mantle.xyz/address/0xA08fF559C4Fc41FEf01D26744394dD2d2aa74E55) |
| **DOORRateOracle** | [`0x8888F236f9ec2B3aD0c07080ba5Ebc1241F70d71`](https://explorer.sepolia.mantle.xyz/address/0x8888F236f9ec2B3aD0c07080ba5Ebc1241F70d71) | [View →](https://explorer.sepolia.mantle.xyz/address/0x8888F236f9ec2B3aD0c07080ba5Ebc1241F70d71) |
| **VaultStrategy**  | [`0x92273a6629A87094E4A2525a7AcDE00eD3f025D3`](https://explorer.sepolia.mantle.xyz/address/0x92273a6629A87094E4A2525a7AcDE00eD3f025D3) | [View →](https://explorer.sepolia.mantle.xyz/address/0x92273a6629A87094E4A2525a7AcDE00eD3f025D3) |

**Token Addresses (External - Real Testnet Tokens)**:

| Token    | Address                                                                                                                                | Explorer                                                                                         |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **USDC** | [`0x9a54bad93a00bf1232d4e636f5e53055dc0b8238`](https://explorer.sepolia.mantle.xyz/address/0x9a54bad93a00bf1232d4e636f5e53055dc0b8238) | [View →](https://explorer.sepolia.mantle.xyz/address/0x9a54bad93a00bf1232d4e636f5e53055dc0b8238) |
| **mETH** | [`0x4Ade8aAa0143526393EcadA836224EF21aBC6ac6`](https://explorer.sepolia.mantle.xyz/address/0x4Ade8aAa0143526393EcadA836224EF21aBC6ac6) | [View →](https://explorer.sepolia.mantle.xyz/address/0x4Ade8aAa0143526393EcadA836224EF21aBC6ac6) |

---

**Network**: Mantle Sepolia Testnet (Chain ID: 5003)

**Deployer**: `0xb09b4152D37a05a2f2D73e1f5010014e6aFAFC39`

**Deployment Commands**:

- **Recommended - Mock Tokens**: `npm run deploy:testnet:mock` ⭐ (Unlimited balance!)
- Production (Real Tokens): `npm run deploy:testnet` ⚠️ (Not practical - insufficient token balance)

---

## 📖 Overview

DOOR Protocol is a next-generation structured DeFi product that implements a **waterfall distribution mechanism** for risk-adjusted yield generation. Built on Mantle Network, it provides sophisticated capital allocation strategies through a dual-tranche system that separates risk and return profiles for different investor preferences.

### 🎯 What Problem Does DOOR Solve?

Traditional DeFi protocols offer a one-size-fits-all approach to yield generation, where all users are exposed to the same level of risk regardless of their risk tolerance. This creates several problems:

1. **Risk Mismatch**: Conservative investors are forced into high-risk positions
2. **Capital Inefficiency**: Different risk profiles cannot coexist in the same pool
3. **Unpredictable Returns**: No guaranteed rate structures for risk-averse users
4. **Limited Downside Protection**: Junior capital has no buffer against losses

DOOR Protocol solves these issues through a **structured product approach** with waterfall distribution mechanics.

---

## 💎 Key Strengths & Differentiators

### 1. **Waterfall Distribution Mechanism**

DOOR implements a sophisticated waterfall distribution system that automatically routes yields based on pre-defined priority rules:

- **Senior Tranche First**: Senior vault holders receive their fixed target APY first
- **Junior Tranche Second**: Remaining yields flow to junior vault for amplified returns
- **Automatic Rebalancing**: Smart contract-based distribution eliminates manual intervention
- **Transparent On-Chain**: All distribution logic is verifiable and immutable

**Why This Matters**: Unlike traditional pools where all participants share proportional yields, DOOR's waterfall ensures senior holders get predictable returns while junior holders capture upside potential.

### 2. **Dynamic Safety Module**

DOOR features an industry-first **real-time risk management system** that adapts to market conditions:

```
Safety Levels:
├── HEALTHY (≥15% junior ratio) → Normal operations
├── WARNING (10-15% junior ratio) → Monitoring mode
├── DANGER (5-10% junior ratio) → Restricted operations
└── CRITICAL (<5% junior ratio) → Emergency mode
```

**Unique Features**:

- **Automatic Deposit Pausing**: System auto-pauses deposits when risk thresholds are breached
- **Dynamic Caps**: Senior deposit caps adjust based on junior capital availability
- **Health Check Automation**: Keepers can trigger safety updates for immediate response
- **Configurable Thresholds**: Protocol can adapt to different risk environments

**Competitive Advantage**: Most DeFi protocols have static risk parameters. DOOR's dynamic safety module provides active risk management without sacrificing decentralization.

### 3. **Epoch-Based Liquidity Management**

DOOR introduces a **structured withdrawal system** through epoch management:

- **Defined Withdrawal Windows**: 7-day epochs with configurable parameters
- **Early Withdrawal Penalties**: Reduces liquidity risk (configurable 1-5%)
- **Queue-Based Processing**: Fair withdrawal order during high-demand periods
- **Capital Efficiency**: Allows protocol to optimize yield strategies without constant withdrawals

**Business Value**: This mechanism enables DOOR to deploy capital into longer-term, higher-yield strategies that would be impossible with instant withdrawals, resulting in better overall returns.

### 4. **Oracle-Driven Rate System (DOR)**

DOOR implements a **decentralized oracle rate (DOR)** mechanism for adaptive APY:

```
DOR Calculation:
DOR = Σ(Rate_i × Weight_i) / Σ(Weight_i)

Senior Target APY = DOR + Senior Premium (1%)
```

**Key Features**:

- **Multi-Source Aggregation**: Combines rates from multiple data sources
- **Challenge Mechanism**: 24-hour challenge period for large rate changes (>2%)
- **Authorized Updates**: Multi-signature oracle role for security
- **Staleness Detection**: Automatic flagging of outdated rate sources

**Why This is Better**: Static APY protocols either overpromise (leading to insolvency) or underpromise (reducing competitiveness). DOOR's dynamic oracle-based rates ensure sustainable, market-competitive yields.

### 5. **Junior Tranche Protection Model**

DOOR's junior tranche acts as a **first-loss capital buffer** that protects senior holders:

```
Loss Absorption Sequence:
1. Junior accumulated yields absorbed first
2. Junior principal slashed second
3. Junior deficit tracked for future recovery
4. Senior capital only affected in extreme scenarios
```

**Leverage Calculation**:

```
Junior Leverage = Total Assets / Junior Principal
Example: $100k total, $20k junior = 5x leverage on returns
```

**Value Proposition**: Junior holders accept higher risk in exchange for:

- Amplified returns (up to 5-10x senior APY)
- First access to excess yields
- Protocol fee sharing opportunities

### 6. **Flexible Strategy System**

DOOR supports **pluggable yield strategies** for capital deployment:

**Current Implementation**:

- mETH (Mantle Staked ETH) staking
- DeFi protocol integrations
- LP provision strategies
- Cross-protocol arbitrage

**Strategy Management**:

- Dynamic allocation adjustment
- Emergency withdrawal capabilities
- Performance tracking and reporting
- Strategy-level risk assessment

**Extensibility**: New strategies can be added without upgrading core contracts, allowing DOOR to adapt to emerging yield opportunities on Mantle Network.

---

## 🏗️ Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                        DOOR Protocol                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────┐           ┌─────────────┐                 │
│  │ SeniorVault │◄──────────┤ JuniorVault │                 │
│  │  (Fixed APY)│           │ (Leveraged) │                 │
│  └──────┬──────┘           └──────┬──────┘                 │
│         │                          │                         │
│         └──────────┬───────────────┘                        │
│                    ▼                                         │
│            ┌───────────────┐                                │
│            │   CoreVault   │                                │
│            │ (Coordination)│                                │
│            └───────┬───────┘                                │
│                    │                                         │
│    ┌───────────────┼───────────────┐                       │
│    ▼               ▼               ▼                        │
│ ┌────────┐  ┌──────────┐  ┌──────────────┐               │
│ │ Epoch  │  │  Safety  │  │ Rate Oracle  │               │
│ │Manager │  │  Module  │  │    (DOR)     │               │
│ └────────┘  └──────────┘  └──────────────┘               │
│                    │                                         │
│                    ▼                                         │
│            ┌───────────────┐                                │
│            │Yield Strategy │                                │
│            │   (mETH, LP)  │                                │
│            └───────────────┘                                │
└─────────────────────────────────────────────────────────────┘
```

### Smart Contract Overview

| Contract           | Purpose               | Key Functions                                                  |
| ------------------ | --------------------- | -------------------------------------------------------------- |
| **CoreVault**      | Central coordinator   | `harvest()`, `depositToStrategy()`, `syncSeniorRate()`         |
| **SeniorVault**    | Fixed-rate tranche    | `deposit()`, `withdraw()`, `addYield()`                        |
| **JuniorVault**    | Leveraged tranche     | `deposit()`, `withdraw()`, `slashPrincipal()`                  |
| **EpochManager**   | Withdrawal management | `requestWithdrawal()`, `processWithdrawal()`, `advanceEpoch()` |
| **SafetyModule**   | Risk management       | `performHealthCheck()`, `updateSafetyLevel()`                  |
| **DOORRateOracle** | APY calculation       | `updateRate()`, `getDOR()`, `getSeniorTargetAPY()`             |
| **VaultStrategy**  | Yield generation      | `allocate()`, `deallocate()`, `harvest()`                      |

---

## 🔄 How It Works

### For Senior Vault Users (Risk-Averse)

1. **Deposit USDC** into SeniorVault
2. **Receive sDOOR** tokens (ERC-4626 shares)
3. **Earn Fixed APY** based on oracle rate (DOR + 1% premium)
4. **Protected by Junior** capital acting as first-loss buffer
5. **Withdraw** at any time (subject to epoch constraints)

**Example**:

```
Deposit: 10,000 USDC
APY: 8% (DOR 7% + 1% premium)
Annual Yield: 800 USDC
Protection: Junior capital absorbs first losses
```

### For Junior Vault Users (Risk-Seeking)

1. **Deposit USDC** into JuniorVault
2. **Receive jDOOR** tokens (ERC-4626 shares)
3. **Earn Leveraged Returns** from excess yields after senior obligations
4. **Accept First-Loss** position to protect senior holders
5. **Potential High Returns** from yield amplification

**Example**:

```
Scenario: 100,000 USDC total, 20,000 USDC junior
Strategy Yields: 12% APY (12,000 USDC/year)
Senior Obligation: 8% on 80,000 = 6,400 USDC
Junior Gets: 12,000 - 6,400 = 5,600 USDC
Junior APY: 5,600 / 20,000 = 28% (3.5x senior rate)
```

### Yield Distribution Flow

```
1. VaultStrategy generates yield from mETH staking + DeFi
                    │
                    ▼
2. CoreVault.harvest() collects yields
                    │
                    ├─► Protocol Fee (2%) → Treasury
                    │
                    ▼
3. Calculate Senior Obligation (Principal × Rate × Time)
                    │
                    ├─► Senior Gets: Full obligation amount
                    │
                    ▼
4. Remaining Yield → Junior Vault
                    │
                    └─► Junior Gets: All excess yield
```

### Safety Module Response

```
Market Downturn → Junior Principal Slashed
                              │
                              ▼
                    Junior Ratio Drops
                              │
                              ▼
                ┌─────────────┴─────────────┐
                ▼                           ▼
         If ratio < 10%              If ratio < 5%
    WARNING level activated     CRITICAL level activated
  - Monitor closely             - Pause all deposits
  - Alert keepers               - Emergency mode
  - Prepare restrictions        - Withdrawal only
```

---

## 🛠️ Technical Specifications

### Technology Stack

- **Smart Contracts**: Solidity 0.8.26
- **Framework**: Foundry + Hardhat
- **Testing**: Forge (142 tests, 100% pass rate)
- **Standards**: ERC-4626 (Tokenized Vaults)
- **Network**: Mantle Network (L2)
- **Dependencies**: OpenZeppelin Contracts v5.0.0

### Key Parameters

| Parameter                    | Value         | Configurable          |
| ---------------------------- | ------------- | --------------------- |
| **Min Junior Ratio**         | 5%            | ✅ Yes (SafetyModule) |
| **Senior Premium**           | 1% above DOR  | ✅ Yes (Oracle)       |
| **Protocol Fee**             | 2%            | ✅ Yes (CoreVault)    |
| **Epoch Duration**           | 7 days        | ✅ Yes (EpochManager) |
| **Early Withdrawal Penalty** | 1%            | ✅ Yes (EpochManager) |
| **Max Rate Change**          | 2% per update | ✅ Yes (Oracle)       |
| **Challenge Period**         | 24 hours      | ✅ Yes (Oracle)       |
| **Senior Deposit Cap**       | Dynamic       | ✅ Yes (SafetyModule) |

### Gas Optimization

- **ERC-4626 Standard**: Efficient share-based accounting
- **Batch Operations**: Multiple deposits/withdrawals in single tx
- **Storage Packing**: Optimized struct layouts
- **View Functions**: Extensive use for off-chain calculations
- **Event Indexing**: Efficient historical data queries

---

## 📊 Testing & Security

### Test Coverage

```bash
npm run test:forge
```

**Results**:

- ✅ 142 tests passed
- ✅ 8 test suites (Unit, Integration, Fuzz)
- ✅ Core vault operations
- ✅ Waterfall distribution logic
- ✅ Safety module state transitions
- ✅ Oracle rate calculations
- ✅ Epoch management
- ✅ Edge cases and revert conditions

### Fuzz Testing

```bash
npm run test:forge:v
```

**Coverage**:

- ✅ 256 runs per fuzz test
- ✅ Junior/Senior deposit amounts
- ✅ Yield distribution scenarios
- ✅ Oracle rate updates
- ✅ Safety level calculations
- ✅ Slashing conditions

### Security Features

1. **Access Control**: Role-based permissions (OpenZeppelin)
2. **Reentrancy Guards**: All external calls protected
3. **Integer Overflow**: Solidity 0.8.26 built-in protection
4. **Emergency Controls**: Pause mechanisms and emergency withdrawals
5. **Rate Limiting**: Max rate changes and challenge periods
6. **Input Validation**: Comprehensive parameter checks

---

## 🚀 Getting Started

### Prerequisites

```bash
node >= 18.0.0
npm >= 9.0.0
foundry (forge, cast, anvil)
```

### Installation

```bash
# Clone the repository
git clone https://github.com/door-protocol/contract.git
cd contract

# Install dependencies
npm install

# Install Foundry dependencies
forge install
```

### Configuration

1. Copy environment template:

```bash
cp .env.example .env
```

2. Configure `.env`:

```env
PRIVATE_KEY=0xyour_private_key_here
MANTLE_TESTNET_RPC_URL=https://rpc.sepolia.mantle.xyz
MANTLESCAN_API_KEY=your_api_key_for_verification
```

### Compile

```bash
# Compile with Foundry
npm run compile:forge

# Or with Hardhat
npm run compile
```

### Test

```bash
# Run all tests
npm run test:forge

# Run with verbosity
npm run test:forge:v

# Run with gas report
npm run test:forge:gas

# Run coverage
npm run test:coverage:forge
```

### Deploy

DOOR Protocol provides two deployment modes for Mantle Sepolia testnet:

#### 🎯 Recommended: Mock Token Deployment

**Why Mock Tokens?**

Currently, **obtaining sufficient testnet USDC and mETH balance is extremely difficult** on Mantle Sepolia:

- 🚫 **No reliable USDC faucet** - can't get enough balance for meaningful testing
- 🚫 **mETH requires complex bridging** - Sepolia ETH → Mantle Bridge → contact Mantle team
- 🚫 **Limited supply** - even if you get tokens, balance is insufficient for testing
- ✅ **Mock tokens are instantly available** with unlimited balance
- ✅ **Full control** over token supply for comprehensive testing

**Use Mock tokens for:**

- Quick testing and development (need sufficient balance)
- Frontend integration testing (need to test multiple deposits/withdrawals)
- Protocol functionality testing (need large amounts)
- Demo and hackathon purposes (instant access)

---

#### Local Deployment (Anvil)

Perfect for local development and testing:

```bash
# Terminal 1: Start local Hardhat node
npm run anvil

# Terminal 2: Deploy with mock tokens (Viem)
npm run deploy:local:mock

# Or deploy with Ethers
npm run deploy:local:mock:ethers

# Or deploy with Forge
npm run deploy:forge:local
```

**Benefits:**

- ⚡ Instant deployments
- 🔄 Easy reset and redeploy
- 💰 Free gas
- 🛠️ Full debugging capabilities

---

#### Testnet Deployment (Mantle Sepolia)

##### Option 1: Using Mock Tokens (⭐ **RECOMMENDED**)

**This is the recommended approach** due to testnet token availability issues:

```bash
# Deploy with mock USDC and mETH (Viem - Recommended)
npm run deploy:testnet:mock

# Or deploy with Ethers
npm run deploy:testnet:mock:ethers

# Or deploy with Forge
npm run deploy:forge:testnet
```

**What happens:**

1. Deploys `MockUSDC` and `MockMETH` contracts **(with unlimited minting capability!)**
2. Deploys all DOOR Protocol contracts (CoreVault, SeniorVault, JuniorVault, etc.)
3. Initializes all contracts
4. **You get unlimited mock tokens for testing** - no balance limitations!

**Mock Token Features:**

```solidity
// MockUSDC functions
mint(address to, uint256 amount)  // Mint unlimited tokens to any address
burn(address from, uint256 amount) // Burn tokens (can always mint more!)
setYieldRate(uint256 rate)         // Simulate yield generation

// No balance limits - mint as much as you need for testing!
```

**Latest Mock Deployment:**

```
MockUSDC:    0xa9fd59bf5009da2d002a474309ca38a8d8686f6a
MockMETH:    0xac8fc1d5593ada635c5569e35534bfab1ab2fedc
```

See [Mock Token Deployment](#mock-token-deployment-for-testing-only) section for all addresses.

---

##### Option 2: Using Real Testnet Tokens (⚠️ **NOT RECOMMENDED**)

**Only use if you already have sufficient testnet USDC and mETH balance** (which is extremely rare and difficult to obtain).

```bash
# Deploy using real USDC and mETH on testnet (Viem)
npm run deploy:testnet

# Or deploy with Ethers
npm run deploy:testnet:ethers
```

**Real Token Addresses (Mantle Sepolia):**

```
USDC: 0x9a54bad93a00bf1232d4e636f5e53055dc0b8238
mETH: 0x4Ade8aAa0143526393EcadA836224EF21aBC6ac6
```

**⚠️ Challenges with Real Tokens:**

- **No public USDC faucet** - cannot obtain sufficient balance for testing
- **mETH requires complex bridging process** - time-consuming and unreliable
- **Very limited supply** - insufficient balance for meaningful protocol testing
- **Cannot easily reset state** - once tokens are used, can't get more
- **Testing limitations** - can't test edge cases with large amounts

**How to get real testnet tokens (if needed):**

1. **USDC**:
   - No reliable public faucet available
   - **Insufficient balance** even from alternative sources
   - **Recommendation: Use Mock tokens instead** ⭐

2. **mETH**:
   - Get Sepolia ETH from [Sepolia Faucet](https://sepoliafaucet.com/)
   - Bridge to Mantle Sepolia via [Mantle Bridge](https://app.mantle.xyz/bridge?network=sepolia)
   - Contact Mantle team for mETH tokens
   - **Problem: Still insufficient balance for comprehensive testing**

3. **Alternative**: Ask in Mantle Discord for testnet tokens
   - **Limitation: Balance is still very limited** and not suitable for repeated testing

---

#### 📝 Deployment Comparison

| Feature            | Mock Tokens                | Real Tokens                        |
| ------------------ | -------------------------- | ---------------------------------- |
| **Availability**   | ✅ Instant                 | ❌ Extremely difficult             |
| **Token Balance**  | ✅ Unlimited               | ❌ Insufficient for testing        |
| **Setup Time**     | ⚡ < 5 minutes             | ⏱️ Hours/Days                      |
| **Cost**           | 💰 Only gas                | 💰 Gas + bridging fees             |
| **Testing**        | ✅ Comprehensive           | ❌ Limited by insufficient balance |
| **Multiple Tests** | ✅ Unlimited               | ❌ Can't get more tokens           |
| **Edge Cases**     | ✅ Test with large amounts | ❌ Balance too small               |
| **Recommended**    | ✅ **YES**                 | ❌ Not practical                   |

---

#### 🎓 For Developers

**Use Mock tokens if:**

- ✅ You're developing or testing the protocol **(you need sufficient balance!)**
- ✅ You need quick iterations **(can't get more real tokens easily)**
- ✅ You want to test edge cases **(large amounts, multiple deposits/withdrawals)**
- ✅ You need to test yield generation **(requires significant balance)**
- ✅ You're doing a demo or hackathon **(instant access with no balance limits)**
- ✅ You need to test repeatedly **(unlimited token supply)**

**Use Real tokens only if:**

- You're doing final integration testing **(and have sufficient balance already)**
- You need to test with actual DeFi protocols on testnet
- You already have sufficient testnet token balance **(which is extremely rare)**
- **⚠️ Warning**: Even if you get real tokens, the balance will likely be insufficient for comprehensive testing

---

#### 🚀 Quick Start (Recommended Path)

```bash
# 1. Get testnet MNT for gas
# Visit: https://faucet.sepolia.mantle.xyz/

# 2. Deploy with mock tokens (includes unlimited USDC/mETH balance!)
npm run deploy:testnet:mock

# 3. Copy the deployed addresses to frontend
# Addresses are saved in: scripts/deployments/mantleTestnet-deployment.json

# 4. Start testing with unlimited token balance!
# Mock tokens give you full control - no balance limitations!
```

**That's it!** No need to:

- ❌ Hunt for testnet USDC (no faucet with sufficient balance)
- ❌ Bridge mETH tokens (complex and time-consuming)
- ❌ Worry about running out of tokens (unlimited supply with mock!)
- ✅ Just deploy and test immediately with unlimited balance!

### Verify Contracts

```bash
# Verify on Mantle Sepolia
npm run verify:testnet <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>

# Verify on Mantle Mainnet
npm run verify:mainnet <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

### Initialization Scripts

If deployment is interrupted or initialization fails, use these recovery scripts:

#### Initialize CoreVault and EpochManager

If these two core contracts failed to initialize during deployment:

```bash
# Initialize CoreVault and EpochManager on testnet
npm run init:core-epoch

# Or run directly
npx hardhat run scripts/hardhat/initialize-core-epoch.ts --network mantleTestnet
```

This script will:

- Check if CoreVault is initialized
- Check if EpochManager is initialized
- Initialize any uninitialized contracts
- Skip already initialized contracts

#### Recover Partial Deployment

If deployment was interrupted and multiple contracts need initialization:

```bash
# Recover partial deployment on testnet
npm run recover:deployment

# Or run directly
npx hardhat run scripts/hardhat/recover-partial-deployment.ts --network mantleTestnet
```

This script will:

- Check all contracts (SeniorVault, JuniorVault, CoreVault, EpochManager, VaultStrategy)
- Initialize any uninitialized contracts
- Configure roles and permissions
- Provide manual instructions if automatic initialization fails

**Note**: Update the contract addresses in these scripts before running them.

---

## 📝 Usage Examples

### Example 1: Senior Vault Deposit

```solidity
// Approve USDC
IERC20(usdc).approve(address(seniorVault), 10_000e6);

// Deposit to senior vault
uint256 shares = seniorVault.deposit(10_000e6, msg.sender);

// Check balance
uint256 balance = seniorVault.balanceOf(msg.sender);

// Check current APY
uint256 apy = seniorVault.currentAPY(); // Returns in basis points (800 = 8%)
```

### Example 2: Junior Vault Deposit

```solidity
// Approve USDC
IERC20(usdc).approve(address(juniorVault), 5_000e6);

// Deposit to junior vault
uint256 shares = juniorVault.deposit(5_000e6, msg.sender);

// Check leverage factor
uint256 leverage = juniorVault.calculateLeverage(); // Returns 5e18 for 5x leverage

// Check estimated APY
uint256 estimatedAPY = juniorVault.estimateAPY();
```

### Example 3: Withdrawal Request

```solidity
// Request withdrawal through epoch manager
epochManager.requestWithdrawal(
    address(seniorVault),
    5_000e6,  // amount
    msg.sender
);

// Check current epoch
(uint256 currentEpoch, , , ) = epochManager.getCurrentEpoch();

// Process withdrawal (after epoch ends)
epochManager.processWithdrawal(
    address(seniorVault),
    msg.sender,
    currentEpoch
);
```

### Example 4: Keeper Operations

```solidity
// Harvest yields (keeper role)
coreVault.harvest();

// Perform safety check (keeper role)
safetyModule.performHealthCheck();

// Update oracle rate (oracle role)
rateOracle.updateRate(sourceId, newRate);

// Advance epoch (keeper role)
epochManager.advanceEpoch();
```

---

## 🌐 Integration Guide

### Frontend Integration

```typescript
import { createPublicClient, createWalletClient } from 'viem';
import { mantleSepoliaTestnet } from 'viem/chains';

// Contract ABIs
import SeniorVaultABI from './abis/SeniorVault.json';
import JuniorVaultABI from './abis/JuniorVault.json';

// Initialize clients
const publicClient = createPublicClient({
  chain: mantleSepoliaTestnet,
  transport: http('https://rpc.sepolia.mantle.xyz'),
});

// Read senior vault stats (using latest mock deployment)
const seniorAPY = await publicClient.readContract({
  address: '0x03f4903c3fcf0cb23bee2c11531afb8a1307ce91',
  abi: SeniorVaultABI,
  functionName: 'currentAPY',
});

// Deposit to senior vault
const { hash } = await walletClient.writeContract({
  address: '0x03f4903c3fcf0cb23bee2c11531afb8a1307ce91',
  abi: SeniorVaultABI,
  functionName: 'deposit',
  args: [amount, userAddress],
});
```

### Subgraph Integration (Future)

DOOR Protocol is designed for easy subgraph integration with comprehensive event emissions:

```graphql
{
  deposits(first: 10, orderBy: timestamp, orderDirection: desc) {
    id
    user
    vault
    amount
    shares
    timestamp
  }

  harvests(first: 10, orderBy: timestamp, orderDirection: desc) {
    id
    totalYield
    seniorYield
    juniorYield
    protocolFee
    timestamp
  }
}
```

---

## 🗺️ Roadmap

### Phase 1: Core Protocol (✅ Completed)

- ✅ Dual-tranche vault system
- ✅ Waterfall distribution mechanism
- ✅ Dynamic safety module
- ✅ Oracle-based rate system
- ✅ Epoch management
- ✅ Comprehensive testing

### Phase 2: Strategy Expansion (Q2 2026)

- 🔄 Additional yield strategies (Curve, Aave, etc.)
- 🔄 Multi-asset support (WETH, wMNT)
- 🔄 Cross-protocol yield aggregation
- 🔄 Automated rebalancing

### Phase 3: Advanced Features (Q3 2026)

- 📋 Governance token launch
- 📋 DAO-based parameter adjustment
- 📋 Subgraph deployment
- 📋 Advanced analytics dashboard
- 📋 Third-party integrations

### Phase 4: Ecosystem Growth (Q4 2026)

- 📋 Mainnet launch on Mantle
- 📋 Liquidity mining programs
- 📋 Partnership integrations
- 📋 Multi-chain expansion

---

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Solidity style guide
- Write comprehensive tests for new features
- Update documentation
- Run linter before committing: `npm run lint`
- Ensure all tests pass: `npm run test:forge`

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🔗 Links

- **Website**: [https://door-protocol-frontend.vercel.app](https://door-protocol-frontend.vercel.app)
- **X (Twitter)**: [@door_protocol](https://x.com/door_protocol)

---

## 📞 Contact

- **Team**: DOOR Protocol Team
- **Email**: andy3638@naver.com
- **GitHub**: [@door-protocol](https://github.com/door-protocol)

---

## 🙏 Acknowledgments

- Built on [Mantle Network](https://mantle.xyz)
- Powered by [OpenZeppelin](https://openzeppelin.com)
- Developed with [Foundry](https://getfoundry.sh)
- Inspired by traditional finance structured products

---

## ⚠️ Disclaimer

DOOR Protocol is experimental software. Smart contracts have been tested but not audited. Use at your own risk. This is not financial advice.
