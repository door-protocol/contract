#!/bin/bash

# =============================================================================
# DOOR Protocol - Deploy Script
# =============================================================================
# Description: Deploy contracts to various networks
# Usage: ./scripts/shell/deploy.sh [options]
# Options:
#   --network <name>   Network to deploy to (local, testnet, mainnet)
#   --forge            Use Forge for deployment
#   --hardhat          Use Hardhat for deployment (default)
#   --ethers           Use Hardhat with ethers.js
#   --viem             Use Hardhat with viem (default)
#   --verify           Verify contracts after deployment
#   --testnet-mint     Mint test tokens (testnet only)
#   --dry-run          Simulate deployment without broadcasting
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Default options
NETWORK="local"
USE_FORGE=false
USE_ETHERS=false
VERIFY=false
TESTNET_MINT=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --forge)
            USE_FORGE=true
            shift
            ;;
        --hardhat)
            USE_FORGE=false
            shift
            ;;
        --ethers)
            USE_ETHERS=true
            shift
            ;;
        --viem)
            USE_ETHERS=false
            shift
            ;;
        --verify)
            VERIFY=true
            shift
            ;;
        --testnet-mint)
            TESTNET_MINT=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   DOOR Protocol - Deploy${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Network: ${YELLOW}$NETWORK${NC}"
echo -e "Tool: ${YELLOW}$([ "$USE_FORGE" = true ] && echo "Forge" || echo "Hardhat")${NC}"
if [ "$USE_FORGE" = false ]; then
    echo -e "Library: ${YELLOW}$([ "$USE_ETHERS" = true ] && echo "ethers.js" || echo "viem")${NC}"
fi
echo -e "Verify: ${YELLOW}$VERIFY${NC}"
echo ""

# Validate network
case $NETWORK in
    local|localhost)
        HARDHAT_NETWORK="localhost"
        FORGE_RPC="http://127.0.0.1:8545"
        ;;
    testnet|mantle-testnet)
        HARDHAT_NETWORK="mantleTestnet"
        FORGE_RPC="\$MANTLE_TESTNET_RPC_URL"
        if [ -z "$PRIVATE_KEY" ]; then
            echo -e "${RED}Error: PRIVATE_KEY environment variable not set${NC}"
            exit 1
        fi
        ;;
    mainnet|mantle)
        HARDHAT_NETWORK="mantle"
        FORGE_RPC="\$MANTLE_RPC_URL"
        if [ -z "$PRIVATE_KEY" ]; then
            echo -e "${RED}Error: PRIVATE_KEY environment variable not set${NC}"
            exit 1
        fi
        echo -e "${YELLOW}WARNING: Deploying to mainnet!${NC}"
        read -p "Are you sure you want to continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Deployment cancelled"
            exit 0
        fi
        ;;
    *)
        echo -e "${RED}Unknown network: $NETWORK${NC}"
        echo "Supported networks: local, testnet, mainnet"
        exit 1
        ;;
esac

# Deploy with Forge
if [ "$USE_FORGE" = true ]; then
    echo -e "${BLUE}Deploying with Forge...${NC}"

    FORGE_CMD="forge script scripts/forge/Deploy.s.sol"

    if [ "$TESTNET_MINT" = true ]; then
        FORGE_CMD="forge script scripts/forge/Deploy.s.sol:DeployTestnet"
    else
        FORGE_CMD="forge script scripts/forge/Deploy.s.sol:Deploy"
    fi

    FORGE_CMD="$FORGE_CMD --rpc-url $FORGE_RPC"

    if [ "$DRY_RUN" = false ]; then
        FORGE_CMD="$FORGE_CMD --broadcast"
    fi

    if [ "$VERIFY" = true ]; then
        FORGE_CMD="$FORGE_CMD --verify"
    fi

    echo -e "${YELLOW}Running: $FORGE_CMD${NC}"
    eval $FORGE_CMD

# Deploy with Hardhat
else
    echo -e "${BLUE}Deploying with Hardhat...${NC}"

    if [ "$USE_ETHERS" = true ]; then
        DEPLOY_SCRIPT="scripts/hardhat/deploy-ethers.ts"
    else
        DEPLOY_SCRIPT="scripts/hardhat/deploy-viem.ts"
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}Dry run - compiling only${NC}"
        npx hardhat compile
    else
        npx hardhat run "$DEPLOY_SCRIPT" --network "$HARDHAT_NETWORK"
    fi
fi

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Deployment Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"

    # Show deployment file location
    DEPLOYMENT_FILE="deployments/${HARDHAT_NETWORK}-deployment.json"
    if [ -f "$DEPLOYMENT_FILE" ]; then
        echo ""
        echo -e "Deployment saved to: ${BLUE}$DEPLOYMENT_FILE${NC}"
    fi
else
    echo -e "${RED}Deployment failed${NC}"
    exit 1
fi
