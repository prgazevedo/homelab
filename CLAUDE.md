# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a homelab infrastructure-as-code project designed to manage a Proxmox homelab with K3s cluster through **unified Ansible-based automation**. The system provides complete DISMM (Discover, Import, Sync, Monitor, Maintain) workflow through a single command interface. The key principle is to import and sync existing infrastructure rather than recreate it.

## Infrastructure Layout

The system works with any Proxmox homelab configuration. Your specific infrastructure details should be configured in `homelab-config.yml` (see `homelab-config.yml.example` for template).

**Example Infrastructure:**
- **Proxmox Host:** YOUR_PROXMOX_IP (configure in homelab-config.yml)
- **VMs:** Any number of virtual machines with custom VM IDs
- **Containers:** Any number of LXC containers with custom VM IDs
- **K3s Cluster:** Optional Kubernetes cluster with configurable nodes
- **Services:** Customizable service deployments based on your needs

**Configuration File:** `homelab-config.yml` (gitignored, contains your specific details)

## Unified Management Commands

### Single Entry Point
```bash
# Complete infrastructure overview (default action)
./homelab-unified.sh
./homelab-unified.sh status
./homelab-unified.sh discover

# Update infrastructure state file
./homelab-unified.sh sync

# Show all available commands
./homelab-unified.sh help
```

### VM Operations
```bash
# Start VM (qemu type) - use your actual VM IDs
./homelab-unified.sh start 101 qemu    # Start VM 101
./homelab-unified.sh start 102 qemu    # Start VM 102

# Stop VM
./homelab-unified.sh stop 101 qemu     # Stop VM 101
./homelab-unified.sh stop 102 qemu     # Stop VM 102

# Restart VM
./homelab-unified.sh restart 101 qemu  # Restart VM 101
```

### Container Operations
```bash
# Start container (lxc type) - use your actual container IDs
./homelab-unified.sh start 200 lxc     # Start container 200
./homelab-unified.sh start 201 lxc     # Start container 201

# Stop container
./homelab-unified.sh stop 200 lxc      # Stop container 200
./homelab-unified.sh stop 201 lxc      # Stop container 201

# Restart container
./homelab-unified.sh restart 200 lxc   # Restart container 200
```

### K3s Cluster Management
```bash
# K3s cluster overview and management
./homelab-unified.sh k3s
```

### Direct Ansible Execution
```bash
# Run specific playbooks directly
ansible-playbook ansible/playbooks/unified-infrastructure.yml -e "proxmox_password=PASSWORD"
ansible-playbook ansible/playbooks/vm-operations.yml -e "proxmox_password=PASSWORD" -e "action=start" -e "vmid=103" -e "vm_type=qemu"
```

## Project Architecture

### Directory Structure
- **ansible/**: Unified infrastructure automation and configuration
  - **playbooks/**: Ansible automation playbooks
  - **group_vars/**: Global configuration variables
  - **inventory.yml**: Infrastructure inventory definitions
- **homelab-unified.sh**: Single command interface for all operations
- **monitoring/**: Observability stack (prometheus-rules/, grafana-dashboards/)
- **tools/**: Management utilities (health-check/, backup-scripts/)
- **archive/**: Deprecated Terraform attempts (preserved for reference)

### Core Components
- `homelab-unified.sh`: Main entry point providing unified DISMM interface
- `ansible/playbooks/unified-infrastructure.yml`: Complete infrastructure discovery and monitoring
- `ansible/playbooks/vm-operations.yml`: VM/container lifecycle management (start/stop/restart)
- `ansible/group_vars/all.yml`: Global configuration including security settings
- `ansible.cfg`: Ansible configuration optimized for homelab environment

### Ansible Configuration
- **API Integration:** Direct Proxmox API calls via uri module
- **Authentication:** Secure keychain-based credential management
- **Security:** Proper certificate validation with justified exceptions for self-signed certificates
- **State Management:** Infrastructure state exported to YAML files
- **Error Handling:** Comprehensive validation and timeout management

## Workflow Patterns

### DISMM Workflow (Discover, Import, Sync, Monitor, Maintain)
1. **Discover**: Real-time infrastructure scanning via Proxmox API
2. **Import**: Capture current state without disrupting running services
3. **Sync**: Export infrastructure state to versioned YAML files
4. **Monitor**: Continuous health monitoring and resource usage tracking
5. **Maintain**: Automated alerts for stopped services and high resource usage

### Daily Operations
1. Run `./homelab-unified.sh status` for infrastructure overview
2. Use VM/container operations for lifecycle management
3. Monitor exported state files for configuration changes
4. Check K3s cluster health via `./homelab-unified.sh k3s`

### Infrastructure Changes
1. Use Ansible playbooks for configuration changes
2. Test changes against non-production VMs first
3. Update documentation after successful changes
4. Monitor infrastructure state post-change

## Safety Guidelines

### Critical Safety Rules
- **ALWAYS** test VM operations on non-critical VMs first
- **VERIFY** infrastructure state before making changes via `./homelab-unified.sh status`
- **BACKUP** current state files before major changes
- **MONITOR** infrastructure after operations for unexpected behavior

### Credential Management
- Proxmox credentials stored securely in macOS keychain
- Never commit passwords or API tokens to version control
- Use `security add-generic-password` for credential storage
- Ansible playbooks retrieve credentials dynamically from keychain

### Change Management
- Test Ansible playbooks on single VMs before mass operations
- Review infrastructure-state.yml for configuration drift
- Monitor resource usage after VM operations
- Keep K3s cluster health in mind when managing worker nodes

## Development Guidelines

### Extending Ansible Playbooks
- Follow existing patterns in ansible/playbooks/
- Use proper error handling with register and failed_when
- Include no_log: true for sensitive operations
- Test playbooks with --check mode first
- Document security exceptions with checkov:skip comments

### Adding New VM Operations
- Extend ansible/playbooks/vm-operations.yml
- Follow Proxmox API patterns for authentication
- Include proper task status monitoring
- Handle both qemu (VMs) and lxc (containers) types
- Test operations on non-critical VMs first

### Modifying Infrastructure Discovery
- Extend ansible/playbooks/unified-infrastructure.yml
- Use uri module for Proxmox API integration
- Include proper error handling and timeouts
- Update state file generation for new data points
- Test discovery against different infrastructure states

## Troubleshooting

### Common Issues

- **Ansible playbook fails:** Check Proxmox API connectivity and credentials in keychain
- **VM operations timeout:** Verify VM exists and Proxmox service is running
- **Authentication errors:** Ensure keychain contains valid Proxmox credentials
- **Certificate validation errors:** Review proxmox_validate_certs setting in group_vars/all.yml
- **K3s management fails:** Check k3s-management.sh script exists and is executable

### Debug Commands

```bash
# Test Proxmox connectivity (replace with your IP)
curl -k https://YOUR_PROXMOX_IP:8006/api2/json/version

# Check keychain credentials
security find-generic-password -a "proxmox" -s "homelab-proxmox"

# Run Ansible with verbose output
ansible-playbook ansible/playbooks/unified-infrastructure.yml -v -e "proxmox_password=PASSWORD"

# Test specific VM operation (use your VM IDs)
./homelab-unified.sh status
./homelab-unified.sh start 101 qemu

# Check infrastructure state file
cat infrastructure-state.yml

# Verify K3s cluster (if configured)
kubectl cluster-info
kubectl get nodes
```

### Network Connectivity Issues

If you receive "No route to host" errors, this typically indicates network configuration issues:

1. Verify Proxmox host is accessible: `ping YOUR_PROXMOX_IP`
2. Check firewall settings on Proxmox host
3. Ensure you're on the same network as the Proxmox server
4. Test API access directly with curl before running Ansible
5. Verify `homelab-config.yml` has correct IP addresses

This project prioritizes safety and non-disruptive operations. Always verify infrastructure state before making modifications.