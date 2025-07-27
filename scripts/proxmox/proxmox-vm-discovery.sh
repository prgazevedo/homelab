#!/bin/bash
# Proxmox VM Discovery Script
# Discovers all VMs, their MAC addresses, and current IP addresses

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
PROXMOX_HOST="192.168.2.100"
PROXMOX_USER="root"
DISCOVERY_RESULTS_FILE="proxmox-vm-discovery.json"

# Function to print colored output
print_header() {
    echo -e "${BLUE}🔍 $1${NC}"
    echo "$(printf '=%.0s' {1..60})"
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

print_vm() {
    echo -e "${MAGENTA}🖥️  $1${NC}"
}

# Show usage
show_usage() {
    echo -e "${BLUE}🔍 Proxmox VM Discovery Tool${NC}"
    echo "=================================="
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "COMMANDS:"
    echo "  setup                     - Setup SSH authentication and required tools"
    echo "  discover                  - Discover all VMs and their IPs"
    echo "  list                      - List all VMs with basic info"
    echo "  running                   - Show only running VMs"
    echo "  network                   - Show network configuration for all VMs"
    echo "  export                    - Export discovery results to JSON"
    echo "  update-inventory          - Update Ansible inventory with discovered IPs"
    echo "  status <vmid>             - Show detailed status for specific VM"
    echo ""
    echo "Examples:"
    echo "  $0 discover               # Complete VM discovery"
    echo "  $0 running                # Show only running VMs"
    echo "  $0 status 103             # Show details for VM 103"
    echo "  $0 update-inventory       # Update Ansible inventory"
    echo ""
}

# Setup SSH authentication
setup_ssh_auth() {
    print_header "Setting up SSH Authentication"
    
    print_info "Testing SSH connection to Proxmox..."
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
        print_status "SSH key authentication already working"
        return 0
    fi
    
    print_warning "SSH key authentication not configured"
    print_info "Setting up SSH key authentication..."
    
    # Check if SSH key exists
    if [ ! -f "$HOME/.ssh/id_ed25519.pub" ] && [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
        print_info "Generating SSH key..."
        ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "homelab-$(whoami)@$(hostname)"
    fi
    
    # Copy SSH key
    local ssh_key_file=""
    if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
        ssh_key_file="$HOME/.ssh/id_ed25519.pub"
    elif [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        ssh_key_file="$HOME/.ssh/id_rsa.pub"
    fi
    
    if [ -n "$ssh_key_file" ]; then
        print_info "Installing SSH key on Proxmox (you'll be prompted for password)..."
        if ssh-copy-id -i "$ssh_key_file" "$PROXMOX_USER@$PROXMOX_HOST"; then
            print_status "SSH key authentication configured"
        else
            print_error "Failed to setup SSH key authentication"
            exit 1
        fi
    else
        print_error "No SSH key found"
        exit 1
    fi
}

# Install required tools on Proxmox
setup_proxmox_tools() {
    print_header "Setting up Proxmox Tools"
    
    print_info "Checking if net-tools (arp command) is installed..."
    if ssh "$PROXMOX_USER@$PROXMOX_HOST" "command -v arp >/dev/null 2>&1"; then
        print_status "net-tools already installed"
        return 0
    fi
    
    print_info "Installing net-tools on Proxmox..."
    if ssh "$PROXMOX_USER@$PROXMOX_HOST" "apt update && apt install -y net-tools"; then
        print_status "net-tools installed successfully"
    else
        print_error "Failed to install net-tools"
        exit 1
    fi
}

# Check Proxmox connectivity
check_proxmox() {
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
        print_error "Cannot connect to Proxmox host: $PROXMOX_HOST"
        print_info "Run with 'setup' command to configure SSH authentication"
        return 1
    fi
    
    # Check if arp command is available
    if ! ssh "$PROXMOX_USER@$PROXMOX_HOST" "command -v arp >/dev/null 2>&1"; then
        print_error "arp command not found on Proxmox"
        print_info "Run with 'setup' command to install required tools"
        return 1
    fi
    
    return 0
}

# Get all VMs from Proxmox
get_all_vms() {
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm list --full" | tail -n +2
}

# Get VM configuration
get_vm_config() {
    local vmid="$1"
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm config $vmid"
}

# Get VM network interfaces
get_vm_networks() {
    local vmid="$1"
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm config $vmid | grep '^net'"
}

# Get current IP for MAC address
get_ip_for_mac() {
    local mac="$1"
    # Convert MAC to lowercase for consistent matching
    local mac_lower=$(echo "$mac" | tr '[:upper:]' '[:lower:]')
    local result=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "arp -a | grep -i '$mac_lower'" 2>/dev/null)
    if [ -n "$result" ]; then
        echo "$result" | awk '{print $2}' | tr -d '()'
    else
        echo ""
    fi
}

# Parse MAC address from network config
parse_mac_from_netconfig() {
    local netconfig="$1"
    echo "$netconfig" | grep -o 'virtio=[^,]*' | cut -d'=' -f2
}

# Complete VM discovery
discover_vms() {
    print_header "Proxmox VM Discovery"
    
    check_proxmox
    
    print_info "Refreshing ARP table..."
    # Ping sweep to populate ARP table
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "
        for i in {1..254}; do 
            ping -c 1 -W 1 192.168.2.\$i >/dev/null 2>&1 & 
        done
        wait
    " >/dev/null 2>&1
    
    print_info "Discovering VMs..."
    echo ""
    
    # Get all VMs
    local vm_list=$(get_all_vms)
    local total_vms=$(echo "$vm_list" | wc -l)
    
    if [ "$total_vms" -eq 0 ]; then
        print_warning "No VMs found"
        return
    fi
    
    print_status "Found $total_vms VMs"
    echo ""
    
    # Header
    printf "%-6s %-15s %-10s %-16s %-16s %-15s\n" "VMID" "NAME" "STATUS" "MAC" "IP" "TYPE"
    printf "%-6s %-15s %-10s %-16s %-16s %-15s\n" "----" "----" "------" "---" "--" "----"
    
    # Process each VM
    while IFS= read -r vm_line <&3; do
        if [ -z "$vm_line" ] || [[ "$vm_line" =~ ^[[:space:]]*$ ]]; then 
            continue
        fi
        
        # Parse VM info more carefully
        local vmid=$(echo "$vm_line" | awk '{print $1}')
        local name=$(echo "$vm_line" | awk '{print $2}')
        local status=$(echo "$vm_line" | awk '{print $3}')
        
        # Get network configuration
        local net_configs=$(get_vm_networks "$vmid" 2>/dev/null)
        
        if [ -n "$net_configs" ]; then
            # Just take the first network interface (most VMs have only one)
            local net_line=$(echo "$net_configs" | head -1)
            
            if [ -n "$net_line" ]; then
                local mac=$(parse_mac_from_netconfig "$net_line")
                local ip=$(get_ip_for_mac "$mac")
                
                local vm_type="VM"
                
                # Determine VM type based on name
                case "$name" in
                    *k3s-master*|*master*) vm_type="K3s-Master" ;;
                    *k3s-worker*|*worker*) vm_type="K3s-Worker" ;;
                    *k3s*) vm_type="K3s" ;;
                    *W11*|*win*|*windows*) vm_type="Windows" ;;
                    *container*|*lxc*) vm_type="LXC" ;;
                    *) vm_type="VM" ;;
                esac
                
                # Format IP
                local ip_display="${ip:-'N/A'}"
                
                printf "%-6s %-15s %-10s %-16s %-16s %-15s\n" \
                    "$vmid" "$name" "$status" "$mac" "$ip_display" "$vm_type"
            fi
        else
            printf "%-6s %-15s %-10s %-16s %-16s %-15s\n" \
                "$vmid" "$name" "$status" "No network" "N/A" "Unknown"
        fi
        
    done 3<<< "$vm_list"
    
    echo ""
    print_status "VM discovery completed"
}

# List VMs with basic info
list_vms() {
    print_header "Proxmox VM List"
    
    check_proxmox
    
    local vm_list=$(get_all_vms)
    
    printf "%-6s %-20s %-10s %-8s %-10s %-15s\n" "VMID" "NAME" "STATUS" "CPU" "MEMORY" "UPTIME"
    printf "%-6s %-20s %-10s %-8s %-10s %-15s\n" "----" "----" "------" "---" "------" "------"
    
    while IFS= read -r vm_line; do
        if [ -z "$vm_line" ]; then continue; fi
        
        local vmid=$(echo "$vm_line" | awk '{print $1}')
        local name=$(echo "$vm_line" | awk '{print $2}')
        local status=$(echo "$vm_line" | awk '{print $3}')
        local cpu=$(echo "$vm_line" | awk '{print $4}')
        local memory=$(echo "$vm_line" | awk '{print $5}')
        local uptime=$(echo "$vm_line" | awk '{print $6}')
        
        printf "%-6s %-20s %-10s %-8s %-10s %-15s\n" \
            "$vmid" "$name" "$status" "$cpu" "$memory" "${uptime:-'N/A'}"
            
    done <<< "$vm_list"
}

# Show only running VMs
show_running_vms() {
    print_header "Running VMs"
    
    check_proxmox
    
    local vm_list=$(get_all_vms | grep "running")
    
    if [ -z "$vm_list" ]; then
        print_warning "No running VMs found"
        return
    fi
    
    printf "%-6s %-20s %-16s %-15s\n" "VMID" "NAME" "IP" "TYPE"
    printf "%-6s %-20s %-16s %-15s\n" "----" "----" "--" "----"
    
    while IFS= read -r vm_line; do
        if [ -z "$vm_line" ]; then continue; fi
        
        local vmid=$(echo "$vm_line" | awk '{print $1}')
        local name=$(echo "$vm_line" | awk '{print $2}')
        
        # Get IP address
        local net_config=$(get_vm_networks "$vmid" 2>/dev/null | head -1)
        if [ -n "$net_config" ]; then
            local mac=$(parse_mac_from_netconfig "$net_config")
            local ip=$(get_ip_for_mac "$mac")
            
            local vm_type="VM"
            case "$name" in
                *k3s*) vm_type="K3s" ;;
                *master*) vm_type="K3s-Master" ;;
                *worker*) vm_type="K3s-Worker" ;;
                *) vm_type="VM" ;;
            esac
            
            printf "%-6s %-20s %-16s %-15s\n" \
                "$vmid" "$name" "${ip:-'N/A'}" "$vm_type"
        fi
        
    done <<< "$vm_list"
}

# Show network configuration for all VMs
show_network_config() {
    print_header "VM Network Configuration"
    
    check_proxmox
    
    local vm_list=$(get_all_vms)
    
    while IFS= read -r vm_line; do
        if [ -z "$vm_line" ]; then continue; fi
        
        local vmid=$(echo "$vm_line" | awk '{print $1}')
        local name=$(echo "$vm_line" | awk '{print $2}')
        local status=$(echo "$vm_line" | awk '{print $3}')
        
        print_vm "VM $vmid: $name ($status)"
        
        local net_configs=$(get_vm_networks "$vmid" 2>/dev/null)
        if [ -n "$net_configs" ]; then
            while IFS= read -r net_line; do
                if [ -z "$net_line" ]; then continue; fi
                
                local mac=$(parse_mac_from_netconfig "$net_line")
                local ip=$(get_ip_for_mac "$mac")
                
                echo "  Network: $net_line"
                echo "  MAC: $mac"
                echo "  Current IP: ${ip:-'Not found'}"
                
            done <<< "$net_configs"
        else
            echo "  No network interfaces configured"
        fi
        echo ""
        
    done <<< "$vm_list"
}

# Export results to JSON
export_to_json() {
    print_header "Exporting VM Discovery to JSON"
    
    check_proxmox
    
    print_info "Refreshing ARP table..."
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "
        for i in {1..254}; do 
            ping -c 1 -W 1 192.168.2.\$i >/dev/null 2>&1 & 
        done
        wait
    " >/dev/null 2>&1
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "{" > "$DISCOVERY_RESULTS_FILE"
    echo "  \"discovery_timestamp\": \"$timestamp\"," >> "$DISCOVERY_RESULTS_FILE"
    echo "  \"proxmox_host\": \"$PROXMOX_HOST\"," >> "$DISCOVERY_RESULTS_FILE"
    echo "  \"vms\": [" >> "$DISCOVERY_RESULTS_FILE"
    
    local vm_list=$(get_all_vms)
    local first_vm=true
    
    while IFS= read -r vm_line; do
        if [ -z "$vm_line" ]; then continue; fi
        
        local vmid=$(echo "$vm_line" | awk '{print $1}')
        local name=$(echo "$vm_line" | awk '{print $2}')
        local status=$(echo "$vm_line" | awk '{print $3}')
        
        if [ "$first_vm" = false ]; then
            echo "    }," >> "$DISCOVERY_RESULTS_FILE"
        fi
        first_vm=false
        
        echo "    {" >> "$DISCOVERY_RESULTS_FILE"
        echo "      \"vmid\": $vmid," >> "$DISCOVERY_RESULTS_FILE"
        echo "      \"name\": \"$name\"," >> "$DISCOVERY_RESULTS_FILE"
        echo "      \"status\": \"$status\"," >> "$DISCOVERY_RESULTS_FILE"
        
        local net_configs=$(get_vm_networks "$vmid" 2>/dev/null)
        if [ -n "$net_configs" ]; then
            local net_line=$(echo "$net_configs" | head -1)
            local mac=$(parse_mac_from_netconfig "$net_line")
            local ip=$(get_ip_for_mac "$mac")
            
            echo "      \"mac_address\": \"$mac\"," >> "$DISCOVERY_RESULTS_FILE"
            echo "      \"ip_address\": \"${ip:-null}\"," >> "$DISCOVERY_RESULTS_FILE"
            echo "      \"network_config\": \"$net_line\"" >> "$DISCOVERY_RESULTS_FILE"
        else
            echo "      \"mac_address\": null," >> "$DISCOVERY_RESULTS_FILE"
            echo "      \"ip_address\": null," >> "$DISCOVERY_RESULTS_FILE"
            echo "      \"network_config\": null" >> "$DISCOVERY_RESULTS_FILE"
        fi
        
    done <<< "$vm_list"
    
    echo "    }" >> "$DISCOVERY_RESULTS_FILE"
    echo "  ]" >> "$DISCOVERY_RESULTS_FILE"
    echo "}" >> "$DISCOVERY_RESULTS_FILE"
    
    print_status "Discovery results exported to: $DISCOVERY_RESULTS_FILE"
}

# Update Ansible inventory with discovered IPs
update_inventory() {
    print_header "Updating Ansible Inventory"
    
    if [ ! -f "ansible/inventory.yml" ]; then
        print_error "Ansible inventory not found: ansible/inventory.yml"
        exit 1
    fi
    
    print_info "Updating inventory with static IP addresses..."
    
    # Backup inventory
    cp ansible/inventory.yml ansible/inventory.yml.backup
    
    # Expected static IPs (matching our configuration plan)
    local expected_ips=(
        "192.168.2.101:w11-vm"
        "192.168.2.103:k3s-master" 
        "192.168.2.104:k3s-worker1"
        "192.168.2.105:k3s-worker2"
    )
    
    print_info "Updating to static IP assignments:"
    
    # Update each VM to its planned static IP
    for ip_mapping in "${expected_ips[@]}"; do
        IFS=':' read -r static_ip vm_name <<< "$ip_mapping"
        
        case "$vm_name" in
            "w11-vm")
                # Update Windows VM IP (if different)
                if grep -q "ansible_host: 192\.168\.2\.101" ansible/inventory.yml; then
                    print_status "W11-VM already configured with static IP: $static_ip"
                else
                    sed -i.tmp "s/ansible_host: [0-9\.]*  # Assuming IP/ansible_host: $static_ip/" ansible/inventory.yml
                    print_status "Updated W11-VM IP to: $static_ip"
                fi
                ;;
            "k3s-master")
                # K3s master should already be correct, but verify
                if grep -q "ansible_host: $static_ip" ansible/inventory.yml; then
                    print_status "K3s master already configured with static IP: $static_ip"
                else
                    sed -i.tmp "s/ansible_host: 192\.168\.2\.[0-9]*/ansible_host: $static_ip/" ansible/inventory.yml
                    print_status "Updated K3s master IP to: $static_ip"
                fi
                ;;
            "k3s-worker1")
                # K3s worker1 should already be correct, but verify
                if grep -q "ansible_host: $static_ip" ansible/inventory.yml; then
                    print_status "K3s worker1 already configured with static IP: $static_ip"
                else
                    sed -i.tmp "s/ansible_host: 192\.168\.2\.104/ansible_host: $static_ip/" ansible/inventory.yml
                    print_status "Updated K3s worker1 IP to: $static_ip"
                fi
                ;;
            "k3s-worker2")
                # K3s worker2 should already be correct, but verify
                if grep -q "ansible_host: $static_ip" ansible/inventory.yml; then
                    print_status "K3s worker2 already configured with static IP: $static_ip"
                else
                    sed -i.tmp "s/ansible_host: 192\.168\.2\.105/ansible_host: $static_ip/" ansible/inventory.yml
                    print_status "Updated K3s worker2 IP to: $static_ip"
                fi
                ;;
        esac
    done
    
    # Clean up temp files
    rm -f ansible/inventory.yml.tmp
    
    print_status "Ansible inventory updated with static IP assignments"
    print_info "Backup saved as: ansible/inventory.yml.backup"
    print_info "Static IP plan implemented:"
    echo "  • W11-VM:      192.168.2.101"
    echo "  • K3s Master:  192.168.2.103"
    echo "  • K3s Worker1: 192.168.2.104" 
    echo "  • K3s Worker2: 192.168.2.105"
}

# Show detailed status for specific VM
show_vm_status() {
    local vmid="$1"
    
    print_header "VM $vmid Detailed Status"
    
    check_proxmox
    
    # Get VM basic info
    local vm_info=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm list | grep '^[[:space:]]*$vmid[[:space:]]'" || echo "")
    
    if [ -z "$vm_info" ]; then
        print_error "VM $vmid not found"
        exit 1
    fi
    
    local name=$(echo "$vm_info" | awk '{print $2}')
    local status=$(echo "$vm_info" | awk '{print $3}')
    
    print_vm "VM $vmid: $name"
    echo "Status: $status"
    echo ""
    
    # Get configuration
    print_info "Configuration:"
    get_vm_config "$vmid" | grep -E '^(cores|memory|sockets|name|ostype|boot)'
    echo ""
    
    # Get network info
    print_info "Network Configuration:"
    local net_configs=$(get_vm_networks "$vmid" 2>/dev/null)
    if [ -n "$net_configs" ]; then
        while IFS= read -r net_line; do
            if [ -z "$net_line" ]; then continue; fi
            
            local mac=$(parse_mac_from_netconfig "$net_line")
            local ip=$(get_ip_for_mac "$mac")
            
            echo "Interface: $net_line"
            echo "MAC: $mac"
            echo "Current IP: ${ip:-'Not found'}"
            echo ""
            
        done <<< "$net_configs"
    else
        echo "No network interfaces configured"
    fi
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
            setup_ssh_auth
            setup_proxmox_tools
            print_status "Setup completed! You can now run discovery commands."
            ;;
        "discover")
            if ! check_proxmox; then
                print_error "Prerequisites not met. Run: $0 setup"
                exit 1
            fi
            discover_vms
            ;;
        "list")
            if ! check_proxmox; then
                print_error "Prerequisites not met. Run: $0 setup"
                exit 1
            fi
            list_vms
            ;;
        "running")
            if ! check_proxmox; then
                print_error "Prerequisites not met. Run: $0 setup"
                exit 1
            fi
            show_running_vms
            ;;
        "network")
            if ! check_proxmox; then
                print_error "Prerequisites not met. Run: $0 setup"
                exit 1
            fi
            show_network_config
            ;;
        "export")
            if ! check_proxmox; then
                print_error "Prerequisites not met. Run: $0 setup"
                exit 1
            fi
            export_to_json
            ;;
        "update-inventory")
            if ! check_proxmox; then
                print_error "Prerequisites not met. Run: $0 setup"
                exit 1
            fi
            update_inventory
            ;;
        "status")
            if [ $# -lt 2 ]; then
                print_error "VM ID required for status command"
                exit 1
            fi
            if ! check_proxmox; then
                print_error "Prerequisites not met. Run: $0 setup"
                exit 1
            fi
            show_vm_status "$2"
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