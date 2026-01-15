#!/bin/bash

# =============================================================================
# DOOR Protocol - Build Script
# =============================================================================
# Description: Build contracts using Forge and/or Hardhat
# Usage: ./scripts/shell/build.sh [options]
# Options:
#   --forge     Build with Forge only
#   --hardhat   Build with Hardhat only
#   --all       Build with both (default)
#   --clean     Clean before building
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
BUILD_FORGE=true
BUILD_HARDHAT=true
CLEAN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --forge)
            BUILD_FORGE=true
            BUILD_HARDHAT=false
            shift
            ;;
        --hardhat)
            BUILD_FORGE=false
            BUILD_HARDHAT=true
            shift
            ;;
        --all)
            BUILD_FORGE=true
            BUILD_HARDHAT=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   DOOR Protocol - Build${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    rm -rf out cache artifacts cache_hardhat typechain-types
    echo -e "${GREEN}Clean complete${NC}"
    echo ""
fi

# Build with Forge
if [ "$BUILD_FORGE" = true ]; then
    echo -e "${BLUE}Building with Forge...${NC}"
    forge build
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Forge build successful${NC}"
    else
        echo -e "${RED}Forge build failed${NC}"
        exit 1
    fi
    echo ""
fi

# Build with Hardhat
if [ "$BUILD_HARDHAT" = true ]; then
    echo -e "${BLUE}Building with Hardhat...${NC}"
    npx hardhat compile
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Hardhat build successful${NC}"
    else
        echo -e "${RED}Hardhat build failed${NC}"
        exit 1
    fi
    echo ""
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
