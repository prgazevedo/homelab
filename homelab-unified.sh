#!/bin/bash
# Unified Homelab Management - Single solution for Discovery, Import, Sync, Monitor, Maintain

set -euo pipefail

echo "🏠 Unified Homelab Management (DISMM)"
echo "===================================="

# Get Proxmox password from keychain
PROXMOX_PASSWORD=$(security find-generic-password -a "proxmox" -s "homelab-proxmox" -w 2>/dev/null)

if [ -z "$PROXMOX_PASSWORD" ]; then
    echo "❌ Failed to retrieve Proxmox password from keychain"
    exit 1
fi

# Ensure Ansible is available
source venv/bin/activate

# Default action
ACTION="${1:-status}"

case "$ACTION" in
    "status"|"discover"|"sync")
        echo "🔍 Running unified infrastructure discovery and sync..."
        ansible-playbook \
            ansible/playbooks/unified-infrastructure.yml \
            -e "proxmox_password=$PROXMOX_PASSWORD" \
            --connection=local
        ;;
        
    "start")
        if [ $# -lt 3 ]; then
            echo "Usage: $0 start <vmid> <type>"
            echo "  type: qemu (for VMs) or lxc (for containers)"
            echo "Example: $0 start 100 lxc"
            exit 1
        fi
        VMID="$2"
        VM_TYPE="$3"
        echo "🚀 Starting $VM_TYPE $VMID..."
        ansible-playbook \
            ansible/playbooks/vm-operations.yml \
            -e "proxmox_password=$PROXMOX_PASSWORD" \
            -e "action=start" \
            -e "vmid=$VMID" \
            -e "vm_type=$VM_TYPE" \
            --connection=local
        ;;
        
    "stop")
        if [ $# -lt 3 ]; then
            echo "Usage: $0 stop <vmid> <type>"
            echo "  type: qemu (for VMs) or lxc (for containers)"
            echo "Example: $0 stop 100 lxc"
            exit 1
        fi
        VMID="$2"
        VM_TYPE="$3"
        echo "🛑 Stopping $VM_TYPE $VMID..."
        ansible-playbook \
            ansible/playbooks/vm-operations.yml \
            -e "proxmox_password=$PROXMOX_PASSWORD" \
            -e "action=stop" \
            -e "vmid=$VMID" \
            -e "vm_type=$VM_TYPE" \
            --connection=local
        ;;
        
    "restart")
        if [ $# -lt 3 ]; then
            echo "Usage: $0 restart <vmid> <type>"
            echo "  type: qemu (for VMs) or lxc (for containers)"
            echo "Example: $0 restart 103 qemu"
            exit 1
        fi
        VMID="$2"
        VM_TYPE="$3"
        echo "🔄 Restarting $VM_TYPE $VMID..."
        ansible-playbook \
            ansible/playbooks/vm-operations.yml \
            -e "proxmox_password=$PROXMOX_PASSWORD" \
            -e "action=restart" \
            -e "vmid=$VMID" \
            -e "vm_type=$VM_TYPE" \
            --connection=local
        ;;
        
    "k3s")
        echo "☸️  K3s Cluster Management..."
        ./k3s-management.sh
        ;;
        
    "help")
        echo "Unified Homelab Management Commands:"
        echo ""
        echo "📊 Discovery & Monitoring:"
        echo "  $0 status      - Complete infrastructure overview"
        echo "  $0 discover    - Same as status"
        echo "  $0 sync        - Update infrastructure state file"
        echo ""
        echo "🖥️  VM Management:"
        echo "  $0 start 103 qemu    - Start VM 103 (k3s-master)"
        echo "  $0 stop 101 qemu     - Stop VM 101 (W11-VM)"
        echo "  $0 restart 104 qemu  - Restart VM 104 (k3s-worker1)"
        echo ""
        echo "📦 Container Management:"
        echo "  $0 start 100 lxc     - Start container 100 (ai-dev)"
        echo "  $0 stop 102 lxc      - Stop container 102 (linux-devbox)"
        echo "  $0 restart 100 lxc   - Restart container 100"
        echo ""
        echo "☸️  K3s Cluster:"
        echo "  $0 k3s         - K3s cluster overview and management"
        echo ""
        echo "📋 Your Infrastructure:"
        echo "  VMs: 101(W11), 103(k3s-master), 104(worker1), 105(worker2)"
        echo "  Containers: 100(ai-dev), 102(linux-devbox)"
        ;;
        
    *)
        echo "❌ Unknown action: $ACTION"
        echo "Run: $0 help"
        exit 1
        ;;
esac

echo ""
echo "✅ Operation completed!"
echo "📋 Infrastructure state saved to: ./infrastructure-state.yml"