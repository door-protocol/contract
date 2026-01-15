#!/bin/bash

# =============================================================================
# DOOR Protocol - Local Node Script
# =============================================================================
# Description: Start a local development node
# Usage: ./scripts/shell/node.sh [options]
# Options:
#   --anvil      Use Anvil (default)
#   --hardhat    Use Hardhat node
#   --fork       Fork from testnet
#   --accounts   Number of accounts to create (default: 10)
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
USE_ANVIL=true
FORK=false
ACCOUNTS=10

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --anvil)
            USE_ANVIL=true
            shift
            ;;
        --hardhat)
            USE_ANVIL=false
            shift
            ;;
        --fork)
            FORK=true
            shift
            ;;
        --accounts)
            ACCOUNTS="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   DOOR Protocol - Local Node${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$USE_ANVIL" = true ]; then
    echo -e "${BLUE}Starting Anvil...${NC}"
    echo ""

    ANVIL_CMD="anvil --accounts $ACCOUNTS"

    if [ "$FORK" = true ]; then
        if [ -z "$MANTLE_TESTNET_RPC_URL" ]; then
            echo -e "${RED}Error: MANTLE_TESTNET_RPC_URL not set${NC}"
            echo "Please set the environment variable or create a .env file"
            exit 1
        fi
        ANVIL_CMD="$ANVIL_CMD --fork-url $MANTLE_TESTNET_RPC_URL"
        echo -e "${YELLOW}Forking from Mantle Testnet...${NC}"
    fi

    echo -e "${GREEN}Node running at: http://127.0.0.1:8545${NC}"
    echo ""
    echo "Default accounts (each with 10000 ETH):"
    echo "  Account #0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    echo "  Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    echo ""
    echo "Press Ctrl+C to stop the node"
    echo ""

    eval $ANVIL_CMD

else
    echo -e "${BLUE}Starting Hardhat node...${NC}"
    echo ""

    if [ "$FORK" = true ]; then
        echo -e "${YELLOW}Note: Edit hardhat.config.ts to enable forking${NC}"
    fi

    echo -e "${GREEN}Node running at: http://127.0.0.1:8545${NC}"
    echo ""
    echo "Press Ctrl+C to stop the node"
    echo ""

    npx hardhat node
fi
