#!/bin/bash

# =============================================================================
# DOOR Protocol - Setup Script
# =============================================================================
# Description: Initialize the development environment
# Usage: ./scripts/shell/setup.sh
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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   DOOR Protocol - Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check for required tools
echo -e "${BLUE}Checking required tools...${NC}"

# Check Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓ Node.js ${NODE_VERSION}${NC}"
else
    echo -e "${RED}✗ Node.js not found${NC}"
    echo "Please install Node.js: https://nodejs.org/"
    exit 1
fi

# Check npm/yarn
if command -v yarn &> /dev/null; then
    YARN_VERSION=$(yarn --version)
    echo -e "${GREEN}✓ Yarn ${YARN_VERSION}${NC}"
    PKG_MANAGER="yarn"
elif command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}✓ npm ${NPM_VERSION}${NC}"
    PKG_MANAGER="npm"
else
    echo -e "${RED}✗ npm/yarn not found${NC}"
    exit 1
fi

# Check Foundry
if command -v forge &> /dev/null; then
    FORGE_VERSION=$(forge --version | head -n 1)
    echo -e "${GREEN}✓ Forge installed${NC}"
else
    echo -e "${YELLOW}✗ Foundry not found${NC}"
    echo "Installing Foundry..."
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc
    foundryup
fi

echo ""

# Install dependencies
echo -e "${BLUE}Installing dependencies...${NC}"

# Install npm dependencies
echo -e "${YELLOW}Installing npm packages...${NC}"
if [ "$PKG_MANAGER" = "yarn" ]; then
    yarn install
else
    npm install
fi

# Install Forge dependencies
echo -e "${YELLOW}Installing Forge libraries...${NC}"
if [ ! -d "lib/forge-std" ]; then
    forge install foundry-rs/forge-std --no-commit
fi

if [ ! -d "lib/openzeppelin-contracts" ]; then
    forge install OpenZeppelin/openzeppelin-contracts --no-commit
fi

echo ""

# Setup environment
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file from .env.example...${NC}"
    cp .env.example .env
    echo -e "${GREEN}Created .env file${NC}"
    echo -e "${YELLOW}Please update .env with your configuration${NC}"
fi

echo ""

# Build contracts
echo -e "${BLUE}Building contracts...${NC}"
forge build
npx hardhat compile

echo ""

# Run tests
echo -e "${BLUE}Running tests...${NC}"
forge test

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Update .env with your configuration"
echo "  2. Run 'forge test' to run tests"
echo "  3. Run './scripts/shell/deploy.sh --network local' to deploy locally"
echo ""
