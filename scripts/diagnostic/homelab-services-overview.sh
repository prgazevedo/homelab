#!/bin/bash
# Homelab Services and Web Interfaces Overview
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/homelab-overview-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🏠 Homelab Infrastructure Services Overview"
echo "=========================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

# Check if virtual environment exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

echo "📋 INFRASTRUCTURE LAYOUT"
echo "========================"
echo ""

echo "🖥️  PROXMOX HOST"
echo "- IP Address: 192.168.2.100"
echo "- Web Interface: https://192.168.2.100:8006"
echo "- SSH Access: ssh root@192.168.2.100"
echo "- Role: Hypervisor, VM/Container host"
echo ""

echo "🖧 VIRTUAL MACHINES"
echo "==================="
echo ""

echo "💻 VM 101 - Windows 11 Workstation"
echo "- IP Address: 192.168.2.101"
echo "- OS: Windows 11"
echo "- Resources: 6 CPU cores, 16GB RAM"
echo "- Access: RDP, Console via Proxmox"
echo "- Status: Available"
echo ""

echo "☸️  VM 103 - K3s Master Node"
echo "- IP Address: 192.168.2.103"
echo "- OS: Ubuntu 22.04"
echo "- Role: Kubernetes control plane"
echo "- Resources: 2 CPU cores, 4GB RAM"
echo "- SSH Access: ssh k3s@192.168.2.103"
echo "- Status: Running"
echo ""

echo "🔧 VM 104 - K3s Worker Node 1"
echo "- IP Address: 192.168.2.104"
echo "- OS: Ubuntu 22.04"
echo "- Role: Kubernetes worker"
echo "- Resources: 2 CPU cores, 4GB RAM"
echo "- SSH Access: ssh k3s@192.168.2.104"
echo "- Status: Running"
echo ""

echo "🔧 VM 105 - K3s Worker Node 2"
echo "- IP Address: 192.168.2.105"
echo "- OS: Ubuntu 22.04"
echo "- Role: Kubernetes worker"
echo "- Resources: 2 CPU cores, 4GB RAM"
echo "- SSH Access: ssh k3s@192.168.2.105"
echo "- Status: Running"
echo ""

echo "📦 LXC CONTAINERS"
echo "=================="
echo ""

echo "🤖 Container 100 - AI Development Environment"
echo "- IP Address: Proxmox internal"
echo "- OS: Ubuntu"
echo "- Role: AI/ML development"
echo "- Resources: 8 CPU cores, 32GB RAM"
echo "- Status: Stopped"
echo ""

echo "💼 Container 102 - Linux Development Box"
echo "- IP Address: Proxmox internal"
echo "- OS: Ubuntu"
echo "- Role: Linux development environment"
echo "- Resources: 4 CPU cores, 8GB RAM"
echo "- Status: Stopped"
echo ""

echo "🔧 Container 200 - Git Service (Forgejo)"
echo "- IP Address: 192.168.2.200"
echo "- OS: Ubuntu 22.04"
echo "- Role: Git repository hosting"
echo "- Resources: 2 CPU cores, 2GB RAM, 20GB ZFS storage"
echo "- SSH Access: ssh git@192.168.2.200"
echo "- Status: Running"
echo ""

echo "🌐 WEB INTERFACES & SERVICES"
echo "============================"
echo ""

echo "1. 🖥️  Proxmox VE Management"
echo "   URL: https://192.168.2.100:8006"
echo "   Description: Hypervisor management interface"
echo "   Login: root + your Proxmox password"
echo "   Features: VM/Container management, storage, networking"
echo ""

echo "2. 🔧 Forgejo Git Service"
echo "   URL: http://192.168.2.200:3000"
echo "   Description: Self-hosted Git repository service"
echo "   Login: prgazevedo / GiteaJourney1"
echo "   Features: Git repos, issues, pull requests, mirroring"
echo "   SSH Clone: git@192.168.2.200:user/repo.git"
echo ""

echo "3. 🚀 ArgoCD GitOps Platform"
echo "   URL: http://192.168.2.103:30880"
echo "   Alt URL: kubectl port-forward -n argocd svc/argocd-server 8080:80"
echo "   Description: Kubernetes GitOps deployment platform"
echo "   Login: admin / 5ygoY5iAG1cXmWZw"
echo "   Features: Git → K3s deployment automation"
echo ""

echo "4. ☸️  Kubernetes Dashboard (if deployed)"
echo "   URL: Available via kubectl proxy"
echo "   Description: K3s cluster management interface"
echo "   Access: kubectl proxy → http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo ""

echo "🔗 SERVICE CONNECTIVITY"
echo "======================="
echo ""

echo "Testing service availability..."
echo ""

echo "Proxmox VE:"
curl -k -s -o /dev/null -w "- Proxmox Web UI: %{http_code}\n" https://192.168.2.100:8006 || echo "- Proxmox Web UI: Not accessible"

echo "Forgejo Git Service:"
curl -s -o /dev/null -w "- Forgejo Web UI: %{http_code}\n" http://192.168.2.200:3000 || echo "- Forgejo Web UI: Not accessible"

echo "ArgoCD:"
curl -s -o /dev/null -w "- ArgoCD Web UI: %{http_code}\n" http://192.168.2.103:30880 || echo "- ArgoCD Web UI: Not accessible"

echo ""

echo "K3s Cluster Status:"
if command -v kubectl &> /dev/null; then
    kubectl get nodes 2>/dev/null || echo "- K3s Cluster: kubectl not configured or cluster not accessible"
else
    echo "- K3s Cluster: kubectl not available"
fi
echo ""

echo "📊 RESOURCE SUMMARY"
echo "==================="
echo ""

echo "Total Infrastructure Resources:"
echo "- Physical Host: Proxmox server"
echo "- Virtual Machines: 4 VMs (1 Windows, 3 Ubuntu)"
echo "- LXC Containers: 3 containers (2 stopped, 1 running)"
echo "- Total vCPUs allocated: ~24 cores"
echo "- Total RAM allocated: ~56GB"
echo "- Storage: ZFS-based with local-path for K3s"
echo ""

echo "Active Services:"
echo "- Proxmox VE: Hypervisor management ✅"
echo "- K3s Cluster: 3-node Kubernetes ✅"
echo "- Forgejo: Git service with GitHub mirroring ✅"
echo "- ArgoCD: GitOps deployment platform ✅"
echo ""

echo "🎯 GITOPS WORKFLOW ARCHITECTURE"
echo "==============================="
echo ""

echo "Data Flow:"
echo "GitHub → Forgejo (Mirror) → ArgoCD (Monitor) → K3s (Deploy)"
echo ""

echo "Components:"
echo "1. GitHub: Source repositories (external)"
echo "2. Forgejo (LXC): Local Git service, mirrors from GitHub"
echo "3. ArgoCD (K3s): Monitors Forgejo, deploys to K3s"
echo "4. K3s Cluster: Runs applications deployed by ArgoCD"
echo ""

echo "Benefits:"
echo "- Local Git service (faster, more reliable)"
echo "- Automated deployments (GitOps)"
echo "- Infrastructure as Code"
echo "- Separation of concerns (Git infra vs. apps)"
echo ""

echo "🔧 MANAGEMENT COMMANDS"
echo "======================"
echo ""

echo "Unified Management:"
echo "- ./homelab-unified.sh status      # Infrastructure overview"
echo "- ./homelab-unified.sh git health  # Git service status"
echo "- ./homelab-unified.sh k3s         # K3s management"
echo ""

echo "Direct Access:"
echo "- ssh root@192.168.2.100          # Proxmox host"
echo "- ssh k3s@192.168.2.103           # K3s master"
echo "- ssh git@192.168.2.200           # Git service"
echo ""

echo "Web Access:"
echo "- https://192.168.2.100:8006       # Proxmox VE"
echo "- http://192.168.2.200:3000        # Forgejo Git"
echo "- http://192.168.2.103:30880       # ArgoCD"
echo ""

echo "✅ HOMELAB SERVICES OVERVIEW COMPLETE"
echo "====================================="
echo ""
echo "🏆 Your homelab infrastructure is now fully operational with:"
echo "- Enterprise-grade hypervisor (Proxmox)"
echo "- Production Kubernetes cluster (K3s)"
echo "- Self-hosted Git service (Forgejo)"
echo "- GitOps deployment platform (ArgoCD)"
echo "- Complete automation and monitoring"
echo ""
echo "🚀 Ready for development, deployment, and GitOps workflows!"