#!/bin/bash
# Diagnose SSH Jump Host Issues
# Helps troubleshoot connectivity to VMs via Proxmox

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PROXMOX_HOST="192.168.2.100"
PROXMOX_USER="root"
K3S_USER="ubuntu"

# Function to print colored output
print_header() {
    echo -e "${BLUE}🔍 $1${NC}"
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

# Step 1: Check Proxmox connectivity
check_proxmox() {
    print_header "Step 1: Testing Proxmox Connectivity"
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" "echo 'Proxmox connection OK'" 2>/dev/null; then
        print_status "Proxmox SSH working"
        return 0
    else
        print_error "Cannot connect to Proxmox"
        return 1
    fi
}

# Step 2: Get VM status from Proxmox
check_vm_status() {
    print_header "Step 2: Checking VM Status on Proxmox"
    
    echo ""
    print_info "VM Status from Proxmox:"
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm list" | grep -E "(VMID|103|104|105)" || true
    
    echo ""
    print_info "Checking specific VMs:"
    for vmid in 103 104 105; do
        local status=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm status $vmid" 2>/dev/null || echo "not found")
        echo "  VM $vmid: $status"
    done
}

# Step 3: Get network information
check_vm_networks() {
    print_header "Step 3: VM Network Configuration"
    
    echo ""
    for vmid in 103 104 105; do
        print_info "VM $vmid network config:"
        ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm config $vmid | grep '^net'" 2>/dev/null || echo "  No network config found"
        echo ""
    done
}

# Step 4: Check ARP table for VM IPs
check_arp_table() {
    print_header "Step 4: Checking ARP Table for VM IPs"
    
    echo ""
    print_info "Current ARP table on Proxmox:"
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "arp -a" | head -20
    
    echo ""
    print_info "Looking for K3s VM MAC addresses:"
    
    # Get MAC addresses from VM configs
    for vmid in 103 104 105; do
        local vm_name=""
        case "$vmid" in
            103) vm_name="k3s-master" ;;
            104) vm_name="k3s-worker1" ;;
            105) vm_name="k3s-worker2" ;;
        esac
        
        local mac=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm config $vmid | grep '^net' | head -1" 2>/dev/null | grep -o 'virtio=[^,]*' | cut -d'=' -f2 || echo "")
        
        if [ -n "$mac" ]; then
            echo "  VM $vmid ($vm_name): MAC $mac"
            local ip=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "arp -a | grep -i '$mac'" 2>/dev/null | awk '{print $2}' | tr -d '()' || echo "")
            if [ -n "$ip" ]; then
                echo "    Current IP: $ip"
            else
                echo "    IP: Not found in ARP table"
            fi
        else
            echo "  VM $vmid ($vm_name): No MAC address found"
        fi
        echo ""
    done
}

# Step 5: Test SSH to discovered IPs
test_ssh_to_discovered_ips() {
    print_header "Step 5: Testing SSH to Discovered IPs"
    
    echo ""
    print_info "Testing SSH connectivity to discovered VMs..."
    
    # Get current IPs and test SSH
    for vmid in 103 104 105; do
        local vm_name=""
        case "$vmid" in
            103) vm_name="k3s-master" ;;
            104) vm_name="k3s-worker1" ;;
            105) vm_name="k3s-worker2" ;;
        esac
        
        # Get MAC and current IP
        local mac=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm config $vmid | grep '^net' | head -1" 2>/dev/null | grep -o 'virtio=[^,]*' | cut -d'=' -f2 || echo "")
        local current_ip=""
        
        if [ -n "$mac" ]; then
            current_ip=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "arp -a | grep -i '$mac'" 2>/dev/null | awk '{print $2}' | tr -d '()' || echo "")
        fi
        
        echo "VM $vmid ($vm_name):"
        if [ -n "$current_ip" ]; then
            echo "  Testing SSH to $current_ip via Proxmox jump host..."
            
            # Test basic connectivity first
            if ssh -o ConnectTimeout=5 -o BatchMode=yes -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" "$K3S_USER@$current_ip" "echo 'SSH connection successful'" 2>/dev/null; then
                print_status "  SSH working to $current_ip"
                
                # Get some basic info
                local hostname=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" "$K3S_USER@$current_ip" "hostname" 2>/dev/null || echo "unknown")
                local uptime=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" "$K3S_USER@$current_ip" "uptime | cut -d',' -f1" 2>/dev/null || echo "unknown")
                echo "    Hostname: $hostname"
                echo "    Uptime: $uptime"
            else
                print_error "  SSH failed to $current_ip"
                
                # Try different usernames
                print_info "  Trying alternative usernames..."
                for test_user in "root" "admin" "user"; do
                    if ssh -o ConnectTimeout=3 -o BatchMode=yes -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" "$test_user@$current_ip" "echo 'SSH connection successful'" 2>/dev/null; then
                        print_status "    SSH working with user: $test_user"
                        break
                    fi
                done
            fi
        else
            print_error "  No IP found - VM may be offline"
        fi
        echo ""
    done
}

# Step 6: Network troubleshooting from Proxmox
network_troubleshooting() {
    print_header "Step 6: Network Troubleshooting from Proxmox"
    
    echo ""
    print_info "Testing network connectivity from Proxmox to VMs..."
    
    # Try pinging the planned static IPs
    local planned_ips=(192.168.2.103 192.168.2.104 192.168.2.105)
    
    for ip in "${planned_ips[@]}"; do
        echo "Testing ping to $ip from Proxmox:"
        if ssh "$PROXMOX_USER@$PROXMOX_HOST" "ping -c 2 $ip" 2>/dev/null; then
            print_status "  Ping successful to $ip"
        else
            print_error "  Ping failed to $ip"
        fi
        echo ""
    done
    
    print_info "Proxmox network interfaces:"
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "ip addr show" | grep -E "(inet |^[0-9]+:)" || true
    
    echo ""
    print_info "Proxmox routing table:"
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "ip route" || true
}

# Main diagnostics
main() {
    print_header "SSH Jump Host Diagnostics"
    print_info "Diagnosing SSH connectivity from Mac -> Proxmox -> VMs"
    echo ""
    
    # Run all diagnostic steps
    if check_proxmox; then
        echo ""
        check_vm_status
        echo ""
        check_vm_networks
        echo ""
        check_arp_table
        echo ""
        test_ssh_to_discovered_ips
        echo ""
        network_troubleshooting
        
        echo ""
        print_header "Summary and Next Steps"
        print_info "Based on the diagnostics above:"
        echo "1. If VMs are stopped -> Start them with: ./homelab-unified.sh start <vmid> qemu"
        echo "2. If VMs have different IPs -> Note the current IPs for static IP configuration"
        echo "3. If SSH fails with 'ubuntu' user -> Try the working username found above"
        echo "4. If no IPs found -> VMs may need DHCP/network configuration"
        echo "5. If network issues -> Check Proxmox VM network settings"
        echo ""
    else
        print_error "Cannot proceed - Proxmox connection failed"
        echo "Please ensure SSH keys are set up for Proxmox first"
    fi
}

# Run diagnostics
main "$@"