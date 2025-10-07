#!/usr/bin/env bash
# Docker environment cleanup script - handles remaining containers, images, and resources

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

# Source centralized environment configuration
source "$(dirname "$0")/../env.sh"

if command -v docker &> /dev/null; then
    # First, specifically clean all registry-related containers (common leftover)
    echo "  Cleaning registry containers..."
    docker ps -aq --filter "name=registry" | xargs -r docker rm -f 2>/dev/null || true
    docker ps -aq --filter "name=kind-registry" | xargs -r docker rm -f 2>/dev/null || true
    print_status "Registry containers cleaned"
    
    # Stop and remove all remaining containers (Kind/Terraform should have handled their own)
    if [ "$(docker ps -aq)" ]; then
        echo "  Stopping and removing remaining Docker containers..."
        echo "  Note: Infrastructure containers should have been removed in previous steps"
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        print_status "Remaining Docker containers cleaned"
    else
        print_status "No remaining Docker containers to clean"
    fi
    
    # Remove images (configurable - check CLEANUP_DOCKER_IMAGES)
    if [ "$CLEANUP_DOCKER_IMAGES" = "true" ] && [ "$(docker images -q)" ]; then
        echo "  Removing Docker images..."
        docker rmi $(docker images -q) --force 2>/dev/null || true
        print_status "Docker images cleaned"
    elif [ "$CLEANUP_DOCKER_IMAGES" = "false" ]; then
        print_status "Docker images preserved (CLEANUP_DOCKER_IMAGES=false)"
    else
        print_status "No Docker images to clean"
    fi
    
    # Clean specific networks that might cause conflicts
    echo "  Cleaning Docker networks..."
    docker network rm registry-proxies 2>/dev/null && echo "    ✅ Removed registry-proxies network" || true
    docker network rm kind 2>/dev/null && echo "    ✅ Removed kind network" || true
    docker network prune --force 2>/dev/null || true
    print_status "Docker networks cleaned"
    
    # Clean volumes (EXCLUDING the persistent registry cache)
    echo "  Cleaning Docker volumes (preserving registry cache)..."
    
    # Remove individual volumes that are NOT the registry cache
    # Note: service-nebula-registry-cache must be preserved across rebuilds
    docker volume ls -q | grep -v "service-nebula-registry-cache" | xargs -r docker volume rm 2>/dev/null || true
    
    print_info "Preserved: service-nebula-registry-cache volume (contains cached images)"
    
    # System prune WITHOUT --volumes flag to preserve our registry cache
    echo "  Cleaning Docker system resources (preserving volumes)..."
    docker system prune --force 2>/dev/null || true
    print_status "Docker system resources cleaned (registry cache preserved)"
else
    print_warning "Docker not available"
fi