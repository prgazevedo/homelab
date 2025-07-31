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
        ./scripts/k3s/k3s-unified.sh
        ;;
        
    "git")
        if [ $# -lt 2 ]; then
            echo "Usage: $0 git <command>"
            echo "Available commands: status, health, service-status, service-logs, shell"
            echo "Example: $0 git health"
            exit 1
        fi
        GIT_COMMAND="$2"
        echo "🔧 Git Service Management..."
        ./scripts/management/git/git-service-manager.sh "$GIT_COMMAND"
        ;;
        
    "hardware")
        if [ $# -lt 2 ]; then
            echo "Usage: $0 hardware <command>"
            echo "Available commands: status, temps, fans, deploy, grafana, dashboard"
            echo "Example: $0 hardware status"
            exit 1
        fi
        HARDWARE_COMMAND="$2"
        echo "🌡️ Hardware Monitoring Management..."
        case "$HARDWARE_COMMAND" in
            "deploy")
                echo "🚀 Deploying hardware monitoring infrastructure..."
                ansible-playbook \
                    ansible/playbooks/hardware-monitoring.yml \
                    -e "proxmox_password=$PROXMOX_PASSWORD" \
                    --connection=local
                ;;
            "grafana")
                echo "📊 Deploying Grafana monitoring stack to K3s..."
                ./scripts/setup/deploy-grafana-monitoring.sh
                ;;
            "status"|"temps"|"fans"|"dashboard")
                if [ ! -f "scripts/management/infrastructure/hardware-monitor.sh" ]; then
                    mkdir -p scripts/management/infrastructure
                fi
                ./scripts/management/infrastructure/hardware-monitor.sh "$HARDWARE_COMMAND" 2>/dev/null || echo "Hardware monitor script will be created on first run"
                ;;
            *)
                echo "❌ Unknown hardware command: $HARDWARE_COMMAND"
                echo "Available commands: status, temps, fans, deploy, grafana, dashboard"
                exit 1
                ;;
        esac
        ;;
        
    "gpu")
        if [ $# -lt 2 ]; then
            echo "Usage: $0 gpu <command>"
            echo "Available commands: status, resources, setup, monitor"
            echo "Example: $0 gpu status"
            exit 1
        fi
        GPU_COMMAND="$2"
        echo "🎮 RTX2080 GPU Management..."
        case "$GPU_COMMAND" in
            "status"|"resources"|"setup"|"monitor")
                if [ ! -f "scripts/management/infrastructure/gpu-manager.sh" ]; then
                    mkdir -p scripts/management/infrastructure
                fi
                ./scripts/management/infrastructure/gpu-manager.sh "$GPU_COMMAND" 2>/dev/null || echo "GPU manager script will be created on first run"
                ;;
            *)
                echo "❌ Unknown GPU command: $GPU_COMMAND"
                echo "Available commands: status, resources, setup, monitor"
                exit 1
                ;;
        esac
        ;;
        
    "linkding")
        if [ $# -lt 2 ]; then
            echo "Usage: $0 linkding <command>"
            echo "Available commands: deploy, status, backup, create-user, access, logs"
            echo "Example: $0 linkding deploy"
            exit 1
        fi
        LINKDING_COMMAND="$2"
        echo "🔖 Linkding Bookmark Service Management..."
        case "$LINKDING_COMMAND" in
            "deploy")
                echo "🚀 Deploying Linkding bookmark service natively to Proxmox host..."
                ./scripts/setup/deploy-linkding-native.sh "${3:-changeme123}"
                ;;
            "status")
                echo "📊 Checking Linkding service status..."
                ansible proxmox -i ansible/inventory.yml -m shell -a "systemctl status linkding" || \
                echo "Run './homelab-unified.sh linkding deploy' to install"
                ;;
            "backup")
                echo "💾 Creating Linkding data backup..."
                BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
                ansible proxmox -i ansible/inventory.yml -m shell -a "cp -r /var/lib/linkding /var/lib/linkding-backup-$BACKUP_DATE"
                echo "Backup created: /var/lib/linkding-backup-$BACKUP_DATE"
                ;;
            "create-user")
                echo "👤 Creating Linkding superuser account..."
                echo "Follow the prompts to create your admin account:"
                ansible proxmox -i ansible/inventory.yml -m shell -a "sudo -u linkding bash -c 'cd /opt/linkding/linkding && source venv/bin/activate && python manage.py createsuperuser'"
                ;;
            "access")
                echo "🌐 Linkding Access Information:"
                PROXMOX_IP=$(ansible proxmox -i ansible/inventory.yml -m setup -a "filter=ansible_default_ipv4" | grep -o '"address": "[^"]*"' | cut -d'"' -f4)
                echo "  Web Interface: http://$PROXMOX_IP:9090"
                echo "  Default Admin: admin / changeme123 (change on first login)"
                echo "  Browser Extensions:"
                echo "    - Firefox: https://addons.mozilla.org/firefox/addon/linkding-extension/"
                echo "    - Chrome: https://chrome.google.com/webstore/detail/linkding-extension/"
                ;;
            "logs")
                echo "📋 Viewing Linkding service logs..."
                ansible proxmox -i ansible/inventory.yml -m shell -a "journalctl -u linkding --tail 50 --no-pager"
                ;;
            *)
                echo "❌ Unknown linkding command: $LINKDING_COMMAND"
                echo "Available commands: deploy, status, backup, create-user, access, logs"
                exit 1
                ;;
        esac
        ;;
        
    "help")
        echo "Unified Homelab Management Commands:"
        echo ""
        echo "⚙️  Configuration:"
        echo "  cp homelab-config.yml.example homelab-config.yml"
        echo "  # Edit homelab-config.yml with your specific Proxmox details"
        echo ""
        echo "📊 Discovery & Monitoring:"
        echo "  $0 status      - Complete infrastructure overview"
        echo "  $0 discover    - Same as status"
        echo "  $0 sync        - Update infrastructure state file"
        echo ""
        echo "🖥️  VM Management (use your actual VM IDs):"
        echo "  $0 start 101 qemu    - Start VM 101"
        echo "  $0 stop 102 qemu     - Stop VM 102"
        echo "  $0 restart 103 qemu  - Restart VM 103"
        echo ""
        echo "📦 Container Management (use your actual container IDs):"
        echo "  $0 start 200 lxc     - Start container 200"
        echo "  $0 stop 201 lxc      - Stop container 201"
        echo "  $0 restart 200 lxc   - Restart container 200"
        echo ""
        echo "☸️  K3s Cluster:"
        echo "  $0 k3s         - K3s cluster overview and management"
        echo ""
        echo "🔧 Git Service (LXC Container 200):"
        echo "  $0 git health  - Comprehensive Git service health check"
        echo "  $0 git status  - Git service container status"
        echo "  $0 git shell   - SSH into Git service container"
        echo ""
        echo "🌡️ Hardware Monitoring:"
        echo "  $0 hardware deploy    - Deploy hardware monitoring infrastructure"
        echo "  $0 hardware grafana   - Deploy Grafana monitoring stack to K3s"
        echo "  $0 hardware status    - Hardware monitoring status overview"
        echo "  $0 hardware temps     - Temperature monitoring dashboard info"
        echo "  $0 hardware fans      - Fan speed monitoring dashboard info"
        echo "  $0 hardware dashboard - Grafana dashboard information"
        echo ""
        echo "🎮 RTX2080 GPU Management:"
        echo "  $0 gpu status     - GPU status and capabilities"
        echo "  $0 gpu resources  - GPU specifications and AI/ML capabilities"
        echo "  $0 gpu setup      - GPU setup and configuration instructions"
        echo "  $0 gpu monitor    - GPU monitoring dashboard info"
        echo ""
        echo "🔖 Linkding Bookmark Service:"
        echo "  $0 linkding deploy       - Deploy Linkding service to Proxmox host"
        echo "  $0 linkding status       - Check Linkding service status"
        echo "  $0 linkding access       - Show access URL and browser extension info"
        echo "  $0 linkding create-user  - Create admin user account"
        echo "  $0 linkding backup       - Backup bookmark data"
        echo "  $0 linkding logs         - View service logs"
        echo ""
        echo "📋 Configuration File:"
        echo "  homelab-config.yml - Your specific infrastructure details (gitignored)"
        echo "  See homelab-config.yml.example for template"
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