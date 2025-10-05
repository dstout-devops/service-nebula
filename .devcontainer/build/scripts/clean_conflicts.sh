#!/usr/bin/env bash
# =============================================================================
# Conflict Resolution Script
# Handles specific resource conflicts that prevent Terraform/Terragrunt from running
# This script is idempotent and safe to run multiple times
# =============================================================================

set -e

# Source common functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/../env.sh"

print_section "Cleaning Resource Conflicts"

# =============================================================================
# Docker Registry Proxy Conflicts
# =============================================================================
clean_registry_proxies() {
    print_status "Checking for registry proxy conflicts..."
    
    # Check if registry proxy containers exist
    REGISTRY_CONTAINERS=$(docker ps -aq --filter "name=registry-proxy" 2>/dev/null || true)
    
    if [ -n "$REGISTRY_CONTAINERS" ]; then
        echo "  Found registry proxy containers, checking if they need removal..."
        
        # Check if Terraform state knows about them
        cd "$TERRAFORM_ROOT"
        STATE_CHECK=$(terragrunt state list 2>/dev/null | grep "docker_container.registry_proxy" | wc -l || echo "0")
        
        if [ "$STATE_CHECK" -eq "0" ]; then
            echo "  ⚠️  Registry containers exist but not in Terraform state"
            echo "  Removing conflicting containers..."
            
            # Stop containers
            docker ps -q --filter "name=registry-proxy" | xargs -r docker stop 2>/dev/null || true
            
            # Remove containers
            docker ps -aq --filter "name=registry-proxy" | xargs -r docker rm -f 2>/dev/null || true
            
            print_status "Removed orphaned registry proxy containers"
        else
            print_status "Registry containers are managed by Terraform (OK)"
        fi
    else
        print_status "No registry proxy containers found (OK)"
    fi
    
    # Check if registry-proxies network exists
    REGISTRY_NETWORK=$(docker network ls --filter "name=registry-proxies" --format "{{.Name}}" 2>/dev/null || true)
    
    if [ -n "$REGISTRY_NETWORK" ]; then
        echo "  Found registry-proxies network, checking if it needs removal..."
        
        cd "$TERRAFORM_ROOT"
        NETWORK_STATE_CHECK=$(terragrunt state list 2>/dev/null | grep "docker_network.registry_network" | wc -l || echo "0")
        
        if [ "$NETWORK_STATE_CHECK" -eq "0" ]; then
            echo "  ⚠️  Registry network exists but not in Terraform state"
            echo "  Disconnecting endpoints and removing network..."
            
            # Disconnect all endpoints
            for container in $(docker network inspect registry-proxies -f '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || true); do
                echo "    Disconnecting: $container"
                docker network disconnect registry-proxies "$container" --force 2>/dev/null || true
            done
            
            # Remove network
            docker network rm registry-proxies 2>/dev/null || true
            
            print_status "Removed orphaned registry-proxies network"
        else
            print_status "Registry network is managed by Terraform (OK)"
        fi
    else
        print_status "No registry-proxies network found (OK)"
    fi
}

# =============================================================================
# Kubernetes RBAC Conflicts
# =============================================================================
clean_rbac_conflicts() {
    print_status "Checking for Kubernetes RBAC conflicts..."
    
    # Check if kubectl is available and cluster exists
    if ! command -v kubectl &> /dev/null; then
        print_status "kubectl not available, skipping RBAC check"
        return 0
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_status "No Kubernetes cluster available, skipping RBAC check"
        return 0
    fi
    
    # Check for cert-manager-tokenrequest role conflict
    if kubectl get namespace cert-manager &> /dev/null; then
        if kubectl get role -n cert-manager cert-manager-tokenrequest &> /dev/null 2>&1; then
            echo "  Found cert-manager-tokenrequest role, checking if it needs removal..."
            
            # Check if this is managed by Terraform
            cd "$TERRAFORM_ROOT"
            ROLE_STATE_CHECK=$(terragrunt state list 2>/dev/null | grep "kubernetes_role.token_request" | wc -l || echo "0")
            
            if [ "$ROLE_STATE_CHECK" -eq "0" ]; then
                echo "  ⚠️  cert-manager-tokenrequest role exists but not in Terraform state"
                echo "  Removing conflicting role..."
                kubectl delete role -n cert-manager cert-manager-tokenrequest 2>/dev/null || true
                print_status "Removed orphaned cert-manager-tokenrequest role"
            else
                print_status "cert-manager-tokenrequest role is managed by Terraform (OK)"
            fi
        else
            print_status "No cert-manager-tokenrequest role conflict found (OK)"
        fi
    else
        print_status "cert-manager namespace does not exist (OK)"
    fi
    
    # Check for other common RBAC conflicts
    for rolebinding in cert-manager-tokenrequest; do
        if kubectl get rolebinding -n cert-manager "$rolebinding" &> /dev/null 2>&1; then
            cd "$TERRAFORM_ROOT"
            RB_STATE_CHECK=$(terragrunt state list 2>/dev/null | grep "kubernetes_role_binding.token_request" | wc -l || echo "0")
            
            if [ "$RB_STATE_CHECK" -eq "0" ]; then
                echo "  ⚠️  RoleBinding $rolebinding exists but not in Terraform state"
                kubectl delete rolebinding -n cert-manager "$rolebinding" 2>/dev/null || true
                print_status "Removed orphaned $rolebinding RoleBinding"
            fi
        fi
    done
}

# =============================================================================
# Helm Release Conflicts
# =============================================================================
clean_helm_conflicts() {
    print_status "Checking for Helm release conflicts..."
    
    if ! command -v helm &> /dev/null; then
        print_status "Helm not available, skipping Helm check"
        return 0
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_status "No Kubernetes cluster available, skipping Helm check"
        return 0
    fi
    
    # Check for failed/pending Helm releases
    FAILED_RELEASES=$(helm list -A --failed --pending -q 2>/dev/null || true)
    
    if [ -n "$FAILED_RELEASES" ]; then
        echo "  Found failed/pending Helm releases:"
        echo "$FAILED_RELEASES" | while read -r release; do
            if [ -n "$release" ]; then
                NAMESPACE=$(helm list -A | grep "^$release" | awk '{print $2}')
                echo "    $release (namespace: $NAMESPACE)"
                
                # Check if managed by Terraform
                cd "$TERRAFORM_ROOT"
                HELM_STATE_CHECK=$(terragrunt state list 2>/dev/null | grep "helm_release.$release" | wc -l || echo "0")
                
                if [ "$HELM_STATE_CHECK" -eq "0" ]; then
                    echo "    ⚠️  Unmanaged release, considering removal..."
                    # Don't auto-remove helm releases - too risky
                    echo "    ℹ️  Run: helm uninstall $release -n $NAMESPACE"
                fi
            fi
        done
    else
        print_status "No failed/pending Helm releases found (OK)"
    fi
}

# =============================================================================
# Terraform State Drift
# =============================================================================
check_state_drift() {
    print_status "Checking for Terraform state drift..."
    
    if [ ! -d "$TERRAFORM_ROOT" ]; then
        print_warning "Terraform directory not found: $TERRAFORM_ROOT"
        return 0
    fi
    
    cd "$TERRAFORM_ROOT"
    
    # Check if state file exists
    if ! terragrunt state list &> /dev/null; then
        print_status "No Terraform state found (OK - fresh start)"
        return 0
    fi
    
    # List resources in state
    STATE_RESOURCES=$(terragrunt state list 2>/dev/null || true)
    
    if [ -z "$STATE_RESOURCES" ]; then
        print_status "Terraform state is empty (OK)"
        return 0
    fi
    
    echo "  Resources in Terraform state:"
    echo "$STATE_RESOURCES" | head -5
    if [ $(echo "$STATE_RESOURCES" | wc -l) -gt 5 ]; then
        echo "  ... and $(( $(echo "$STATE_RESOURCES" | wc -l) - 5 )) more"
    fi
    
    print_status "Terraform state exists with $(echo "$STATE_RESOURCES" | wc -l) resources"
}

# =============================================================================
# Registry Directory Permissions
# =============================================================================
fix_registry_directory_permissions() {
    print_status "Checking registry directory permissions..."
    
    # Check if registry directories exist
    if [ -d "/tmp/kind-registry-mgmt" ]; then
        echo "  Found /tmp/kind-registry-mgmt, fixing permissions..."
        
        # Fix permissions on main directory
        sudo chmod 777 /tmp/kind-registry-mgmt 2>/dev/null || chmod 777 /tmp/kind-registry-mgmt 2>/dev/null || true
        
        # Fix permissions on subdirectories
        if [ -n "$(find /tmp/kind-registry-mgmt -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]; then
            find /tmp/kind-registry-mgmt -mindepth 1 -maxdepth 1 -type d -exec sh -c '
                for dir; do
                    sudo chmod 777 "$dir" 2>/dev/null || chmod 777 "$dir" 2>/dev/null || true
                done
            ' sh {} +
            print_status "Fixed permissions on registry directories"
        else
            print_status "No registry subdirectories found (OK)"
        fi
    else
        # Create directory if it doesn't exist
        mkdir -p /tmp/kind-registry-mgmt 2>/dev/null || sudo mkdir -p /tmp/kind-registry-mgmt
        sudo chmod 777 /tmp/kind-registry-mgmt 2>/dev/null || chmod 777 /tmp/kind-registry-mgmt 2>/dev/null || true
        print_status "Created and configured /tmp/kind-registry-mgmt"
    fi
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    echo ""
    echo "This script will check for and resolve common resource conflicts:"
    echo "  • Registry proxy containers and networks not in Terraform state"
    echo "  • Registry directory permissions (/tmp/kind-registry-mgmt)"
    echo "  • Kubernetes RBAC resources (roles, rolebindings)"
    echo "  • Helm Release failures"
    echo "  • Terraform state drift"
    echo ""
    echo "Note: Vault initialization is handled by Terraform (modules/vault/modules/init)"
    echo ""
    
    # Run all cleanup functions
    clean_registry_proxies
    echo ""
    
    fix_registry_directory_permissions
    echo ""
    
    clean_rbac_conflicts
    echo ""
    
    clean_helm_conflicts
    echo ""
    
    check_state_drift
    echo ""
    
    print_section "Conflict Resolution Complete"
    echo ""
    echo "✅ All resource conflicts have been checked and resolved"
    echo ""
    echo "Next steps:"
    echo "  1. Run: cd $TERRAFORM_ROOT && terragrunt plan"
    echo "  2. Review the plan for any remaining issues"
    echo "  3. Apply with: ./apply.sh or terragrunt apply"
    echo ""
}

# Run main function
main
