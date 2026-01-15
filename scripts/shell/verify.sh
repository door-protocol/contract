#!/bin/bash

# =============================================================================
# DOOR Protocol - Verify Script
# =============================================================================
# Description: Verify deployed contracts on block explorer
# Usage: ./scripts/shell/verify.sh [options]
# Options:
#   --network <name>   Network to verify on (testnet, mainnet)
#   --address <addr>   Contract address to verify
#   --contract <name>  Contract name (e.g., CoreVault)
#   --all              Verify all contracts from deployment file
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
NETWORK=""
ADDRESS=""
CONTRACT=""
VERIFY_ALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --address)
            ADDRESS="$2"
            shift 2
            ;;
        --contract)
            CONTRACT="$2"
            shift 2
            ;;
        --all)
            VERIFY_ALL=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Validate network
if [ -z "$NETWORK" ]; then
    echo -e "${RED}Error: --network is required${NC}"
    echo "Usage: ./verify.sh --network <testnet|mainnet> [options]"
    exit 1
fi

case $NETWORK in
    testnet|mantle-testnet)
        HARDHAT_NETWORK="mantleTestnet"
        DEPLOYMENT_FILE="deployments/mantleTestnet-deployment.json"
        ;;
    mainnet|mantle)
        HARDHAT_NETWORK="mantle"
        DEPLOYMENT_FILE="deployments/mantle-deployment.json"
        ;;
    *)
        echo -e "${RED}Unknown network: $NETWORK${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   DOOR Protocol - Verify Contracts${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Network: ${YELLOW}$HARDHAT_NETWORK${NC}"
echo ""

# Verify all contracts
if [ "$VERIFY_ALL" = true ]; then
    if [ ! -f "$DEPLOYMENT_FILE" ]; then
        echo -e "${RED}Error: Deployment file not found: $DEPLOYMENT_FILE${NC}"
        exit 1
    fi

    echo -e "${BLUE}Verifying all contracts from deployment...${NC}"

    # Read deployment file and verify each contract
    CONTRACTS=$(cat "$DEPLOYMENT_FILE" | jq -r '.contracts | keys[]')

    for CONTRACT_NAME in $CONTRACTS; do
        CONTRACT_ADDRESS=$(cat "$DEPLOYMENT_FILE" | jq -r ".contracts.$CONTRACT_NAME")
        echo ""
        echo -e "${YELLOW}Verifying $CONTRACT_NAME at $CONTRACT_ADDRESS...${NC}"

        npx hardhat verify --network "$HARDHAT_NETWORK" "$CONTRACT_ADDRESS" || true
    done

# Verify single contract
else
    if [ -z "$ADDRESS" ] || [ -z "$CONTRACT" ]; then
        echo -e "${RED}Error: --address and --contract are required${NC}"
        echo "Usage: ./verify.sh --network <network> --address <addr> --contract <name>"
        exit 1
    fi

    echo -e "${BLUE}Verifying $CONTRACT at $ADDRESS...${NC}"
    npx hardhat verify --network "$HARDHAT_NETWORK" "$ADDRESS"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Verification Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
