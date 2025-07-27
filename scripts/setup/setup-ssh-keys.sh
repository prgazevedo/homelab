#!/bin/bash
# SSH Key Setup Script for Homelab Infrastructure
# Sets up passwordless SSH authentication for Proxmox and K3s nodes

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration - Static IP assignments
PROXMOX_HOST="192.168.2.100"
PROXMOX_USER="root"
K3S_MASTER_IP="192.168.2.103"   # Static IP for k3s-master
K3S_WORKER1_IP="192.168.2.104"  # Static IP for k3s-worker1
K3S_WORKER2_IP="192.168.2.105"  # Static IP for k3s-worker2
K3S_USER="k3s"
SSH_KEY_TYPE="ed25519"
SSH_KEY_FILE="$HOME/.ssh/id_${SSH_KEY_TYPE}"

# Function to print colored output
print_header() {
    echo -e "${BLUE}🔑 $1${NC}"
    echo "$(printf '=%.0s' {1..50})"
}

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Show usage
show_usage() {
    echo -e "${BLUE}🔑 SSH Key Setup for Homelab${NC}"
    echo "================================="
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "COMMANDS:"
    echo "  setup                     - Complete SSH key setup (recommended)"
    echo "  generate                  - Generate SSH key pair only"
    echo "  proxmox                   - Setup Proxmox SSH key"
    echo "  k3s                       - Setup K3s nodes SSH keys (via Proxmox)"
    echo "  test                      - Test SSH connectivity"
    echo "  remove                    - Remove SSH keys from remote hosts"
    echo ""
    echo "CONFIGURATION:"
    echo "  Proxmox Host: $PROXMOX_USER@$PROXMOX_HOST"
    echo "  K3s Master: $K3S_USER@$K3S_MASTER_IP"
    echo "  K3s Workers: $K3S_USER@$K3S_WORKER1_IP, $K3S_USER@$K3S_WORKER2_IP"
    echo "  SSH Key: $SSH_KEY_FILE (${SSH_KEY_TYPE})"
    echo ""
    echo "Examples:"
    echo "  $0 setup                  # Complete automated setup"
    echo "  $0 test                   # Test all connections"
    echo ""
}

# Generate SSH key pair
generate_ssh_key() {
    print_header "Generating SSH Key Pair"
    
    # Check if SSH key already exists
    if [ -f "$SSH_KEY_FILE" ]; then
        print_warning "SSH key already exists: $SSH_KEY_FILE"
        read -p "Regenerate SSH key? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing SSH key"
            return 0
        fi
    fi
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    # Generate SSH key
    print_info "Generating $SSH_KEY_TYPE SSH key pair..."
    ssh-keygen -t "$SSH_KEY_TYPE" -f "$SSH_KEY_FILE" -N "" -C "homelab-$(whoami)@$(hostname)"
    
    if [ -f "$SSH_KEY_FILE" ]; then
        print_status "SSH key generated: $SSH_KEY_FILE"
        print_info "Public key fingerprint:"
        ssh-keygen -lf "$SSH_KEY_FILE.pub"
    else
        print_error "Failed to generate SSH key"
        exit 1
    fi
}

# Setup SSH key for Proxmox
setup_proxmox_ssh() {
    print_header "Setting up Proxmox SSH Key"
    
    if [ ! -f "$SSH_KEY_FILE.pub" ]; then
        print_error "SSH public key not found: $SSH_KEY_FILE.pub"
        print_info "Run: $0 generate"
        exit 1
    fi
    
    print_info "Installing SSH key on Proxmox host..."
    print_warning "You will be prompted for the Proxmox root password"
    
    # Copy SSH key to Proxmox
    if ssh-copy-id -i "$SSH_KEY_FILE.pub" "$PROXMOX_USER@$PROXMOX_HOST"; then
        print_status "SSH key installed on Proxmox"
        
        # Test connection
        print_info "Testing passwordless connection..."
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" "echo 'SSH key authentication successful'"; then
            print_status "Proxmox SSH key authentication working"
        else
            print_error "Proxmox SSH key authentication failed"
            return 1
        fi
    else
        print_error "Failed to install SSH key on Proxmox"
        return 1
    fi
}

# Setup SSH keys for K3s nodes
setup_k3s_ssh() {
    print_header "Setting up K3s Nodes SSH Keys"
    
    if [ ! -f "$SSH_KEY_FILE.pub" ]; then
        print_error "SSH public key not found: $SSH_KEY_FILE.pub"
        exit 1
    fi
    
    # Test Proxmox connection first
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
        print_error "Cannot connect to Proxmox. Setup Proxmox SSH key first."
        print_info "Run: $0 proxmox"
        exit 1
    fi
    
    # Setup SSH keys for each K3s node
    for node_ip in "$K3S_MASTER_IP" "$K3S_WORKER1_IP" "$K3S_WORKER2_IP"; do
        local node_name=""
        case "$node_ip" in
            "$K3S_MASTER_IP") node_name="K3s Master" ;;
            "$K3S_WORKER1_IP") node_name="K3s Worker1" ;;
            "$K3S_WORKER2_IP") node_name="K3s Worker2" ;;
        esac
        
        print_info "Setting up SSH key for $node_name ($node_ip)..."
        
        # Copy SSH key through Proxmox jump host
        if ssh-copy-id -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" -i "$SSH_KEY_FILE.pub" "$K3S_USER@$node_ip" 2>/dev/null; then
            print_status "$node_name SSH key installed"
            
            # Test connection
            if ssh -o ConnectTimeout=5 -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" -o BatchMode=yes "$K3S_USER@$node_ip" "echo 'SSH connection successful'" 2>/dev/null; then
                print_status "$node_name SSH key authentication working"
            else
                print_warning "$node_name SSH key authentication may not be working"
            fi
        else
            print_error "Failed to install SSH key on $node_name"
            print_warning "Node may be offline or SSH service not running"
        fi
    done
}

# Test SSH connectivity
test_ssh_connectivity() {
    print_header "Testing SSH Connectivity"
    
    # Test Proxmox
    print_info "Testing Proxmox connection..."
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" "echo 'Proxmox SSH: OK'" 2>/dev/null; then
        print_status "Proxmox SSH authentication working"
    else
        print_error "Proxmox SSH authentication failed"
        return 1
    fi
    
    # Test K3s nodes
    for node_ip in "$K3S_MASTER_IP" "$K3S_WORKER1_IP" "$K3S_WORKER2_IP"; do
        local node_name=""
        case "$node_ip" in
            "$K3S_MASTER_IP") node_name="K3s Master" ;;
            "$K3S_WORKER1_IP") node_name="K3s Worker1" ;;
            "$K3S_WORKER2_IP") node_name="K3s Worker2" ;;
        esac
        
        print_info "Testing $node_name connection..."
        if ssh -o ConnectTimeout=5 -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" -o BatchMode=yes "$K3S_USER@$node_ip" "echo '$node_name SSH: OK'" 2>/dev/null; then
            print_status "$node_name SSH authentication working"
        else
            print_error "$node_name SSH authentication failed"
        fi
    done
    
    echo ""
    print_info "SSH connectivity test completed"
    print_info "You can now use the K3s management scripts without passwords"
}

# Remove SSH keys from remote hosts
remove_ssh_keys() {
    print_header "Removing SSH Keys from Remote Hosts"
    
    print_warning "This will remove your SSH key from all remote hosts"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        return 0
    fi
    
    local public_key_content=""
    if [ -f "$SSH_KEY_FILE.pub" ]; then
        public_key_content=$(cat "$SSH_KEY_FILE.pub")
    else
        print_error "Public key not found: $SSH_KEY_FILE.pub"
        return 1
    fi
    
    # Remove from Proxmox
    print_info "Removing SSH key from Proxmox..."
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "sed -i.backup '\\|$public_key_content|d' ~/.ssh/authorized_keys" 2>/dev/null || print_warning "Failed to remove key from Proxmox"
    
    # Remove from K3s nodes
    for node_ip in "$K3S_MASTER_IP" "$K3S_WORKER1_IP" "$K3S_WORKER2_IP"; do
        local node_name=""
        case "$node_ip" in
            "$K3S_MASTER_IP") node_name="K3s Master" ;;
            "$K3S_WORKER1_IP") node_name="K3s Worker1" ;;
            "$K3S_WORKER2_IP") node_name="K3s Worker2" ;;
        esac
        
        print_info "Removing SSH key from $node_name..."
        ssh -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" "$K3S_USER@$node_ip" "sed -i.backup '\\|$public_key_content|d' ~/.ssh/authorized_keys" 2>/dev/null || print_warning "Failed to remove key from $node_name"
    done
    
    print_status "SSH key removal completed"
}

# Complete setup
complete_setup() {
    print_header "Complete SSH Key Setup for Homelab"
    
    print_info "This will setup passwordless SSH authentication for:"
    print_info "- Proxmox host ($PROXMOX_USER@$PROXMOX_HOST)"
    print_info "- K3s Master ($K3S_USER@$K3S_MASTER_IP)"
    print_info "- K3s Worker1 ($K3S_USER@$K3S_WORKER1_IP)"
    print_info "- K3s Worker2 ($K3S_USER@$K3S_WORKER2_IP)"
    echo ""
    
    read -p "Continue with setup? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Setup cancelled"
        exit 0
    fi
    
    # Step 1: Generate SSH key
    generate_ssh_key
    
    # Step 2: Setup Proxmox
    echo ""
    setup_proxmox_ssh
    
    # Step 3: Setup K3s nodes
    echo ""
    setup_k3s_ssh
    
    # Step 4: Test connectivity
    echo ""
    test_ssh_connectivity
    
    echo ""
    print_header "Setup Complete!"
    print_status "SSH key authentication is now configured"
    print_info "You can now use these commands without passwords:"
    echo "  ./k3s-diagnostic.sh all"
    echo "  ./k3s-tunnel.sh start"
    echo "  K3S_MODE=remote ./k3s-unified.sh status"
    echo ""
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi
    
    local command="$1"
    
    case "$command" in
        "help"|"-h"|"--help")
            show_usage
            ;;
        "setup")
            complete_setup
            ;;
        "generate")
            generate_ssh_key
            ;;
        "proxmox")
            generate_ssh_key
            setup_proxmox_ssh
            ;;
        "k3s")
            setup_k3s_ssh
            ;;
        "test")
            test_ssh_connectivity
            ;;
        "remove")
            remove_ssh_keys
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"