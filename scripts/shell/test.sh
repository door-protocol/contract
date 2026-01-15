#!/bin/bash

# =============================================================================
# DOOR Protocol - Test Script
# =============================================================================
# Description: Run tests using Forge and/or Hardhat
# Usage: ./scripts/shell/test.sh [options]
# Options:
#   --forge       Run Forge tests only
#   --hardhat     Run Hardhat tests only
#   --all         Run all tests (default)
#   --unit        Run unit tests only (Forge)
#   --integration Run integration tests only (Forge)
#   --fuzz        Run fuzz tests only (Forge)
#   --coverage    Run with coverage
#   --gas         Run with gas report
#   -v            Verbose output
#   -vv           More verbose output
#   -vvv          Most verbose output
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
RUN_FORGE=true
RUN_HARDHAT=true
TEST_TYPE="all"
COVERAGE=false
GAS_REPORT=false
VERBOSITY=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --forge)
            RUN_FORGE=true
            RUN_HARDHAT=false
            shift
            ;;
        --hardhat)
            RUN_FORGE=false
            RUN_HARDHAT=true
            shift
            ;;
        --all)
            RUN_FORGE=true
            RUN_HARDHAT=true
            shift
            ;;
        --unit)
            TEST_TYPE="unit"
            RUN_HARDHAT=false
            shift
            ;;
        --integration)
            TEST_TYPE="integration"
            RUN_HARDHAT=false
            shift
            ;;
        --fuzz)
            TEST_TYPE="fuzz"
            RUN_HARDHAT=false
            shift
            ;;
        --coverage)
            COVERAGE=true
            shift
            ;;
        --gas)
            GAS_REPORT=true
            shift
            ;;
        -v)
            VERBOSITY="-v"
            shift
            ;;
        -vv)
            VERBOSITY="-vv"
            shift
            ;;
        -vvv)
            VERBOSITY="-vvv"
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   DOOR Protocol - Tests${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Run Forge tests
if [ "$RUN_FORGE" = true ]; then
    echo -e "${BLUE}Running Forge tests...${NC}"

    FORGE_CMD="forge test"

    # Add verbosity
    if [ -n "$VERBOSITY" ]; then
        FORGE_CMD="$FORGE_CMD $VERBOSITY"
    fi

    # Add gas report
    if [ "$GAS_REPORT" = true ]; then
        FORGE_CMD="$FORGE_CMD --gas-report"
    fi

    # Filter by test type
    case $TEST_TYPE in
        unit)
            FORGE_CMD="$FORGE_CMD --match-path 'test/unit/*'"
            echo -e "${YELLOW}Running unit tests only${NC}"
            ;;
        integration)
            FORGE_CMD="$FORGE_CMD --match-path 'test/integration/*'"
            echo -e "${YELLOW}Running integration tests only${NC}"
            ;;
        fuzz)
            FORGE_CMD="$FORGE_CMD --match-path 'test/fuzz/*'"
            echo -e "${YELLOW}Running fuzz tests only${NC}"
            ;;
    esac

    # Coverage
    if [ "$COVERAGE" = true ]; then
        echo -e "${YELLOW}Running with coverage...${NC}"
        forge coverage
    else
        eval $FORGE_CMD
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Forge tests passed${NC}"
    else
        echo -e "${RED}Forge tests failed${NC}"
        exit 1
    fi
    echo ""
fi

# Run Hardhat tests
if [ "$RUN_HARDHAT" = true ]; then
    echo -e "${BLUE}Running Hardhat tests...${NC}"

    if [ "$COVERAGE" = true ]; then
        npx hardhat coverage
    else
        npx hardhat test
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Hardhat tests passed${NC}"
    else
        echo -e "${RED}Hardhat tests failed${NC}"
        exit 1
    fi
    echo ""
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   All Tests Passed!${NC}"
echo -e "${GREEN}========================================${NC}"
