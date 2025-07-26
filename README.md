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
├── discovery/              # Infrastructure discovery tools
├── sync/                   # Synchronization tooling
├── terraform/             # Infrastructure management
├── monitoring/            # Observability stack
├── tools/                # Management utilities
└── docs/                 # Documentation
```

## Quick Start

```bash
# Discover current infrastructure
make discover

# Import existing resources into Terraform
make import

# Sync current state with IaC
make sync

# Deploy monitoring
make monitor
```

## Philosophy

This project **imports and syncs existing infrastructure** rather than recreating it. The goal is to establish IaC management for your running homelab without disruption.