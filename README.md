# Homelab Infrastructure Management

Infrastructure-as-Code project for managing a Proxmox homelab with K3s cluster through discovery, import, and synchronization workflows.

## Current Infrastructure

**Proxmox Host:** 192.168.2.100 (AMD Ryzen 9 3950X, 64GB RAM, RTX 2080)

**VMs:**
- VM 101: W11-VM (Windows 11, 6 CPU, 16GB RAM, 250GB)
- VM 102: linux-devbox (Container, 4 CPU, 8GB RAM, 98GB)
- VM 103: k3s-master (2 CPU, 4GB RAM, 100GB) - 192.168.2.103
- VM 104: k3s-worker1 (2 CPU, 4GB RAM, 100GB) - 192.168.2.104
- VM 105: k3s-worker2 (2 CPU, 4GB RAM, 100GB) - 192.168.2.105
- VM 100: ai-dev (Container, stopped, 8 CPU, 32GB RAM, 64GB)

**K3s Cluster Services:**
- Gitea (ready to deploy)
- PostgreSQL (deployed)
- Monitoring stack (deployed)
- ArgoCD (deployed)

## Project Structure

```
homelab-infra/
├── homelab-unified.sh       # Single command for all operations
├── ansible/                 # Unified infrastructure management
│   ├── inventory.yml        # Infrastructure inventory
│   └── playbooks/           # Automation playbooks
├── discovery/              # Infrastructure discovery tools
├── monitoring/            # Observability stack (Grafana/Prometheus)
├── tools/                # Health checks and utilities
└── docs/                 # Documentation
```

## Prerequisites

1. **Proxmox API Access**: Store credentials in macOS keychain:
   ```bash
   security add-generic-password -a "proxmox" -s "homelab-proxmox" -D "Proxmox API (root@192.168.2.100:8006)" -w
   ```

2. **Dependencies**: Python 3.11+, Ansible
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

## Unified Management

**Single command for everything:**

```bash
# Complete infrastructure overview
./homelab-unified.sh

# See all available operations
./homelab-unified.sh help
```

## Operations

### 📊 **Discovery & Monitoring**
```bash
./homelab-unified.sh status      # Complete infrastructure overview
./homelab-unified.sh discover    # Same as status
./homelab-unified.sh sync        # Update infrastructure state file
```

### 🖥️ **VM Management**
```bash
./homelab-unified.sh start 103 qemu    # Start k3s-master
./homelab-unified.sh stop 101 qemu     # Stop W11-VM
./homelab-unified.sh restart 104 qemu  # Restart k3s-worker1
```

### 📦 **Container Management**
```bash
./homelab-unified.sh start 100 lxc     # Start ai-dev container
./homelab-unified.sh stop 102 lxc      # Stop linux-devbox
./homelab-unified.sh restart 100 lxc   # Restart ai-dev
```

### ☸️ **K3s Cluster**
```bash
./homelab-unified.sh k3s         # K3s cluster management
```

## Philosophy

This project **imports and syncs existing infrastructure** rather than recreating it. The goal is to establish IaC management for your running homelab without disruption.