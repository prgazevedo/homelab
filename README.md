# Homelab Infrastructure Management

Infrastructure-as-Code project for managing any Proxmox homelab with optional K3s cluster through unified discovery, import, sync, monitor, and maintain (DISMM) workflows.

## What This Project Does

This project provides a **unified command-line interface** for managing Proxmox-based homelabs through Ansible automation. It discovers your existing infrastructure without disruption and provides operational management for VMs, containers, and Kubernetes clusters.

### Key Capabilities
- **🔍 Discovery**: Real-time infrastructure scanning via Proxmox API
- **📊 Monitoring**: Resource usage tracking and health checks
- **🚀 Operations**: VM/container lifecycle management (start/stop/restart)
- **☸️ K3s Support**: Kubernetes cluster health monitoring and management
- **🔒 Security**: Secure credential management via macOS keychain
- **📋 State Management**: Infrastructure state exported to version-controlled files

## Project Structure

```
homelab-infra/
├── homelab-unified.sh       # Single command for all operations
├── k3s-management.sh        # K3s cluster management and health checks
├── ansible/                 # Unified infrastructure management
│   ├── inventory.yml        # Infrastructure inventory
│   ├── group_vars/          # Global configuration
│   └── playbooks/           # Automation playbooks
├── monitoring/              # Observability stack (Grafana/Prometheus)
├── tools/                   # Health checks and utilities
├── archive/                 # Legacy tools (Terraform, old scripts)
└── docs/                    # Documentation
```

## Quick Start

### 1. Configure Your Homelab

Copy the configuration template and customize for your environment:
```bash
cp homelab-config.yml.example homelab-config.yml
# Edit homelab-config.yml with your specific Proxmox details
```

### 2. Setup Prerequisites

**Proxmox API Access**: Store credentials securely in macOS keychain:
```bash
security add-generic-password -a "proxmox" -s "homelab-proxmox" -D "Proxmox API" -w
```
When prompted, enter your Proxmox root password.

**Dependencies**: Install Python and Ansible:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**Network Access**: Test connectivity to your Proxmox host:
```bash
ping YOUR_PROXMOX_IP
curl -k https://YOUR_PROXMOX_IP:8006/api2/json/version
```

### 3. Discover Your Infrastructure

Run your first discovery:
```bash
./homelab-unified.sh status
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
./homelab-unified.sh start 101 qemu    # Start VM 101
./homelab-unified.sh stop 102 qemu     # Stop VM 102
./homelab-unified.sh restart 103 qemu  # Restart VM 103
```

### 📦 **Container Management**
```bash
./homelab-unified.sh start 200 lxc     # Start container 200
./homelab-unified.sh stop 201 lxc      # Stop container 201
./homelab-unified.sh restart 200 lxc   # Restart container 200
```

### ☸️ **K3s Cluster**
```bash
./homelab-unified.sh k3s         # K3s cluster management and health checks
```

## Key Features

- **Unified Interface**: Single command for all infrastructure operations
- **Non-Disruptive**: Imports and syncs existing infrastructure without changes
- **Real-Time Discovery**: Live infrastructure state via Proxmox API
- **Secure Credentials**: macOS keychain integration for API authentication
- **Comprehensive Monitoring**: Resource usage, health checks, and alerting
- **State Management**: Infrastructure state exported to versioned YAML files

## Troubleshooting

### Common Issues

**Connection Problems:**
- Ensure network connectivity: `ping YOUR_PROXMOX_IP`
- Test API access: `curl -k https://YOUR_PROXMOX_IP:8006/api2/json/version`
- Verify keychain credentials: `security find-generic-password -a "proxmox" -s "homelab-proxmox"`

**Configuration Issues:**
- Verify `homelab-config.yml` has correct Proxmox host IP and credentials
- Check Ansible configuration in `ansible/group_vars/all.yml`
- Ensure VM IDs in commands match your actual infrastructure

**VM Operations:**
- Check VM exists and is accessible via Proxmox web interface
- Verify VM ID and type (qemu for VMs, lxc for containers)
- Monitor Ansible logs for detailed error information

**K3s Cluster (if enabled):**
- Ensure k3s-management.sh script exists and is executable
- Check cluster connectivity: `kubectl cluster-info`
- Verify worker nodes are reachable: `kubectl get nodes`

### Getting Help

Run `./homelab-unified.sh help` for complete command reference and examples.

## Philosophy

This project **imports and syncs existing infrastructure** rather than recreating it. The goal is to establish IaC management for your running homelab without disruption.