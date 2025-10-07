#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Install Cilium and Hubble CLI tools
# Uses webinstall.dev for Cilium, traditional install for Hubble
# =============================================================================

# Source common functions for consistent output
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/common.sh"

# Source centralized environment configuration
source "$(dirname "$0")/../env.sh"

# Install Cilium CLI
install_cilium_cli() {
  print_status "Installing Cilium CLI..."
  
  if command -v cilium &>/dev/null; then
    local installed_version
    installed_version=$(cilium version --client 2>/dev/null | grep 'cilium-cli:' | awk '{print $2}' || echo "unknown")
    print_status "Cilium CLI already installed (version: $installed_version)"
    return 0
  fi
  
  local cilium_version
  cilium_version=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
  
  local os arch
  os=$(go env GOOS)
  arch=$(go env GOARCH)
  
  local temp_dir
  temp_dir=$(mktemp -d)
  cd "$temp_dir"
  
  print_status "Downloading Cilium CLI $cilium_version for $os-$arch..."
  curl -L --fail --remote-name-all "https://github.com/cilium/cilium-cli/releases/download/${cilium_version}/cilium-${os}-${arch}.tar.gz"{,.sha256sum}
  
  # Verify checksum
  sha256sum --check "cilium-${os}-${arch}.tar.gz.sha256sum" >/dev/null
  
  # Extract and install
  tar -xzf "cilium-${os}-${arch}.tar.gz"
  sudo install cilium /usr/local/bin/cilium
  
  # Cleanup
  cd - >/dev/null
  rm -rf "$temp_dir"
  
  # Verify installation
  if command -v cilium &>/dev/null; then
    local new_version
    new_version=$(cilium version --client 2>/dev/null | grep 'cilium-cli:' | awk '{print $2}' || echo "installed")
    print_success "Cilium CLI installed successfully (version: $new_version)"
  else
    print_error "Failed to install Cilium CLI"
    return 1
  fi
}

# Install Hubble CLI
install_hubble_cli() {
  print_status "Installing Hubble CLI..."
  
  local current_version
  current_version=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
  
  if command -v hubble &>/dev/null; then
    local installed_version
    installed_version=$(hubble version --client 2>/dev/null | head -n1 | awk '{print $2}' | cut -d'@' -f1 || echo "unknown")
    
    if [[ "$installed_version" == "$current_version" ]]; then
      print_success "Hubble CLI already up-to-date (version: $installed_version)"
      return 0
    else
      print_status "Hubble CLI version mismatch (installed: $installed_version, latest: $current_version)"
      print_status "Updating to latest version..."
    fi
  fi
  
  # Download and install Hubble CLI
  local os arch
  os=$(go env GOOS)
  arch=$(go env GOARCH)
  
  local temp_dir
  temp_dir=$(mktemp -d)
  cd "$temp_dir"
  
  print_status "Downloading Hubble CLI $current_version for $os-$arch..."
  curl -L --fail --remote-name-all "https://github.com/cilium/hubble/releases/download/${current_version}/hubble-${os}-${arch}.tar.gz"{,.sha256sum}
  
  # Verify checksum
  sha256sum --check "hubble-${os}-${arch}.tar.gz.sha256sum" >/dev/null
  
  # Extract and install
  tar -xzf "hubble-${os}-${arch}.tar.gz"
  sudo install hubble /usr/local/bin/hubble
  
  # Cleanup
  cd - >/dev/null
  rm -rf "$temp_dir"
  
  # Verify installation
  if command -v hubble &>/dev/null; then
    local new_version
    new_version=$(hubble version --client 2>/dev/null | head -n1 | awk '{print $2}' | cut -d'@' -f1 || echo "installed")
    print_success "Hubble CLI installed successfully (version: $new_version)"
  else
    print_error "Failed to install Hubble CLI"
    return 1
  fi
}

# Main installation function
main() {
  print_header "Installing Cilium and Hubble CLI Tools"
  
  # Install Cilium CLI using webinstall.dev
  install_cilium_cli
  echo ""
  
  # Install Hubble CLI using traditional method
  install_hubble_cli
  echo ""
  
  print_success "All CLI tools installed successfully!"
  
  # Show installed versions
  echo ""
  print_status "Installed tool versions:"
  if command -v cilium &>/dev/null; then
    echo "  • Cilium CLI: $(cilium version --client 2>/dev/null | grep 'cilium-cli:' | awk '{print $2}' || echo "installed")"
  fi
  if command -v hubble &>/dev/null; then
    echo "  • Hubble CLI: $(hubble version --client 2>/dev/null | head -n1 | awk '{print $2}' | cut -d'@' -f1 || echo "installed")"
  fi
}

# Run installation if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi