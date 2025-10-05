#!/usr/bin/env bash
# =============================================================================
# Traefik Module Test Script
# Tests the Traefik ingress controller module configuration
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Traefik Module Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Step 1: Initialize
echo -e "${YELLOW}Step 1: Running terragrunt init...${NC}"
if terragrunt init -upgrade; then
    echo -e "${GREEN}✓ Initialization successful${NC}"
else
    echo -e "${RED}✗ Initialization failed${NC}"
    exit 1
fi
echo

# Step 2: Validate configuration
echo -e "${YELLOW}Step 2: Validating configuration...${NC}"
if terragrunt validate; then
    echo -e "${GREEN}✓ Configuration is valid${NC}"
else
    echo -e "${RED}✗ Configuration validation failed${NC}"
    exit 1
fi
echo

# Step 3: Check for errors
echo -e "${YELLOW}Step 3: Checking module structure...${NC}"
echo "Traefik main module files:"
ls -lh "${SCRIPT_DIR}/modules/traefik"/*.tf
echo
echo "Traefik submodule directories:"
ls -d "${SCRIPT_DIR}/modules/traefik/modules"/*
echo

# Step 4: Format check
echo -e "${YELLOW}Step 4: Checking formatting...${NC}"
if terragrunt fmt -check -recursive; then
    echo -e "${GREEN}✓ All files are properly formatted${NC}"
else
    echo -e "${YELLOW}⚠ Some files need formatting, running fmt...${NC}"
    terragrunt fmt -recursive
    echo -e "${GREEN}✓ Files formatted${NC}"
fi
echo

# Step 5: Create a targeted plan for Traefik only
echo -e "${YELLOW}Step 5: Creating plan for Traefik module...${NC}"
if terragrunt plan -target=module.mgmt_traefik -out=tfplan-traefik 2>&1 | tee plan-output.txt; then
    echo -e "${GREEN}✓ Plan created successfully${NC}"
    echo
    echo -e "${BLUE}Plan Summary:${NC}"
    grep -E "Plan:|No changes" plan-output.txt || true
else
    echo -e "${RED}✗ Plan creation failed${NC}"
    echo
    echo "Last 30 lines of output:"
    tail -30 plan-output.txt
    exit 1
fi
echo

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ All tests passed!${NC}"
echo -e "${BLUE}========================================${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the plan: terragrunt show tfplan-traefik"
echo "2. Apply Traefik: terragrunt apply tfplan-traefik"
echo "3. Check pods: kubectl get pods -n traefik"
echo "4. Check service: kubectl get svc -n traefik"
echo

# Cleanup
rm -f plan-output.txt
