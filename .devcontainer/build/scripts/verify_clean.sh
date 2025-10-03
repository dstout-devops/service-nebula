#!/usr/bin/env bash
# Environment verification script

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

# Check Docker
if command -v docker &> /dev/null; then
    RUNNING_CONTAINERS=$(docker ps -q | wc -l)
    ALL_CONTAINERS=$(docker ps -aq | wc -l)
    if [ "$RUNNING_CONTAINERS" -eq 0 ] && [ "$ALL_CONTAINERS" -eq 0 ]; then
        print_status "Docker environment is clean"
    else
        print_warning "Docker environment may not be completely clean"
    fi
fi

# Check Kind
if command -v kind &> /dev/null; then
    KIND_CLUSTERS=$(kind get clusters 2>/dev/null | wc -l)
    if [ "$KIND_CLUSTERS" -eq 0 ]; then
        print_status "No Kind clusters present"
    else
        print_warning "Kind clusters still present"
    fi
fi

print_status "Environment verification completed"