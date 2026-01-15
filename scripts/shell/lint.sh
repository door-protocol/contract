#!/bin/bash

# =============================================================================
# DOOR Protocol - Lint Script
# =============================================================================
# Description: Run linting and formatting tools
# Usage: ./scripts/shell/lint.sh [options]
# Options:
#   --fix        Auto-fix issues where possible
#   --sol        Lint Solidity files only
#   --ts         Lint TypeScript files only
#   --check      Check only, don't fix (default)
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
FIX=false
LINT_SOL=true
LINT_TS=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            FIX=true
            shift
            ;;
        --sol)
            LINT_SOL=true
            LINT_TS=false
            shift
            ;;
        --ts)
            LINT_SOL=false
            LINT_TS=true
            shift
            ;;
        --check)
            FIX=false
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   DOOR Protocol - Lint${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

ERRORS=0

# Lint Solidity files
if [ "$LINT_SOL" = true ]; then
    echo -e "${BLUE}Linting Solidity files...${NC}"

    # Forge fmt
    echo -e "${YELLOW}Running forge fmt...${NC}"
    if [ "$FIX" = true ]; then
        forge fmt
        echo -e "${GREEN}Forge formatting applied${NC}"
    else
        if forge fmt --check; then
            echo -e "${GREEN}Forge format check passed${NC}"
        else
            echo -e "${RED}Forge format check failed${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    fi

    # Solhint
    echo -e "${YELLOW}Running solhint...${NC}"
    if npx solhint 'src/**/*.sol'; then
        echo -e "${GREEN}Solhint check passed${NC}"
    else
        echo -e "${RED}Solhint check failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi

    echo ""
fi

# Lint TypeScript files
if [ "$LINT_TS" = true ]; then
    echo -e "${BLUE}Linting TypeScript files...${NC}"

    # ESLint
    echo -e "${YELLOW}Running eslint...${NC}"
    if [ "$FIX" = true ]; then
        npx eslint 'scripts/**/*.ts' --fix || true
        echo -e "${GREEN}ESLint fixes applied${NC}"
    else
        if npx eslint 'scripts/**/*.ts'; then
            echo -e "${GREEN}ESLint check passed${NC}"
        else
            echo -e "${RED}ESLint check failed${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    fi

    # Prettier
    echo -e "${YELLOW}Running prettier...${NC}"
    if [ "$FIX" = true ]; then
        npx prettier --write 'scripts/**/*.ts'
        echo -e "${GREEN}Prettier formatting applied${NC}"
    else
        if npx prettier --check 'scripts/**/*.ts'; then
            echo -e "${GREEN}Prettier check passed${NC}"
        else
            echo -e "${RED}Prettier check failed${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    fi

    echo ""
fi

# Summary
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   All Lint Checks Passed!${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}   $ERRORS Lint Check(s) Failed${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
