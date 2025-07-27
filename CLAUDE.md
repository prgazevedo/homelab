# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Important: Claude Code Network Limitations

**Claude Code is sandboxed and has no network access.** This means:
- Cannot SSH to Proxmox or VMs directly
- Cannot ping hosts or test connectivity 
- Cannot run network-dependent commands
- User must execute network scripts manually in terminal
- Claude Code can create and modify scripts but cannot test them with live infrastructure

## Project Overview

This is a homelab infrastructure-as-code project designed to manage a Proxmox homelab with K3s cluster through **unified Ansible-based automation**. The system provides complete DISMM (Discover, Import, Sync, Monitor, Maintain) workflow through a single command interface. The key principle is to import and sync existing infrastructure rather than recreate it.

## Infrastructure Layout

The system works with any Proxmox homelab configuration. Your specific infrastructure details should be configured in `homelab-config.yml` (see `homelab-config.yml.example` for template).

**Example Infrastructure:**
- **Proxmox Host:** 192.168.2.100 (static IP)
- **VMs with Static IPs:**
  - VM 101 (W11-VM): 192.168.2.101
  - VM 103 (K3s Master): 192.168.2.103  
  - VM 104 (K3s Worker1): 192.168.2.104
  - VM 105 (K3s Worker2): 192.168.2.105
- **Containers:** LXC containers with custom VM IDs (100, 102)
- **K3s Cluster:** 3-node cluster with sequential static IPs
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

#### Overview
K3s cluster access supports multiple connection modes:
- **Local Mode**: Direct kubectl access via SSH tunnel (recommended for development)
- **Remote Mode**: Ansible-based remote execution via Proxmox (recommended for automation)
- **Auto Mode**: Automatically detects best available method (default)

#### Connection Setup
```bash
# Option 1: SSH Tunnel for Local kubectl Access
./k3s-tunnel.sh start               # Setup SSH tunnel and kubeconfig
./k3s-tunnel.sh status              # Check tunnel status
./k3s-tunnel.sh stop                # Stop tunnel

# Option 2: Test Connectivity and Diagnostics
./k3s-diagnostic.sh all             # Comprehensive connectivity test
./k3s-diagnostic.sh network         # Basic network tests
./k3s-diagnostic.sh tunnel          # SSH tunnel tests
```

#### Unified K3s Management
```bash
# Default auto-mode (detects best connection method)
./k3s-unified.sh                    # Show cluster status
./k3s-unified.sh status             # Comprehensive cluster overview
./k3s-unified.sh discover           # Run Ansible cluster discovery
./k3s-unified.sh health             # Full health check

# Force specific connection modes
K3S_MODE=local ./k3s-unified.sh status    # Use kubectl directly
K3S_MODE=remote ./k3s-unified.sh status   # Use Ansible remote execution

# Application management
./k3s-unified.sh apps               # List all applications
./k3s-unified.sh deploy gitea       # Deploy Gitea application
./k3s-unified.sh logs gitea         # Show application logs
./k3s-unified.sh backup gitea       # Backup application data

# Monitoring and troubleshooting
./k3s-unified.sh metrics            # Show resource usage
./k3s-unified.sh events             # Recent cluster events
./k3s-unified.sh storage            # Storage information
./k3s-unified.sh network            # Network overview

# Utilities
./k3s-unified.sh port-forward gitea gitea-http 3000:3000
./k3s-unified.sh shell gitea <pod-name>
./k3s-unified.sh clean              # Clean up failed pods
```

#### Troubleshooting K3s Access
```bash
# Comprehensive diagnostics
./k3s-diagnostic.sh all

# Specific connectivity tests
./k3s-diagnostic.sh network         # Test Proxmox connectivity
./k3s-diagnostic.sh ssh             # Test SSH jump host access
./k3s-diagnostic.sh k3s             # Test K3s service status
./k3s-diagnostic.sh kubectl         # Test local kubectl setup
./k3s-diagnostic.sh ansible         # Test Ansible remote access

# Generate diagnostic report
./k3s-diagnostic.sh report
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
- **k3s/**: Kubernetes manifests for cluster applications
  - **gitea/**: Git service deployment manifests
  - **monitoring/**: Prometheus and Grafana configurations
  - **namespaces/**: Namespace definitions
  - **base/**: Common configurations and kustomizations
- **scripts/**: Organized management scripts
  - **k3s/**: K3s cluster management scripts
  - **proxmox/**: Proxmox VM discovery and operations
  - **setup/**: Infrastructure setup and configuration scripts
  - **diagnostic/**: Troubleshooting and diagnostic tools
- **homelab-unified.sh**: Main entry point for all operations
- **k3s.sh**: Quick K3s management wrapper
- **vm-discovery.sh**: Quick VM discovery wrapper
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

## Static IP Configuration

### Sequential IP Assignment
The homelab uses a sequential static IP scheme for predictable networking:

```bash
# View current IP assignment plan
./configure-static-ips.sh plan

# Configure static IPs for all VMs
./configure-static-ips.sh configure-all

# Configure specific VM only
./configure-static-ips.sh configure 103

# Test connectivity after configuration
./configure-static-ips.sh check-connectivity
```

### IP Assignment Scheme
- **192.168.2.100** - Proxmox host (gateway for all VMs)
- **192.168.2.101** - VM 101 (W11-VM) - Windows 11 workstation
- **192.168.2.102** - Reserved for future VM expansion
- **192.168.2.103** - VM 103 (k3s-master) - Kubernetes master node
- **192.168.2.104** - VM 104 (k3s-worker1) - Kubernetes worker node 1
- **192.168.2.105** - VM 105 (k3s-worker2) - Kubernetes worker node 2

### Network Configuration
- **Gateway:** 192.168.2.1 (router)
- **DNS:** 1.1.1.1, 8.8.8.8 (Cloudflare, Google)
- **Subnet:** /24 (255.255.255.0)
- **Method:** Netplan for Ubuntu VMs, manual for Windows VMs

### Configuration Process
1. **Backup current configs:** `./configure-static-ips.sh backup-configs`
2. **Configure Ubuntu VMs:** Automated via netplan and SSH
3. **Configure Windows VMs:** Manual configuration with guided instructions
4. **Update inventory:** `./proxmox-vm-discovery.sh update-inventory`
5. **Verify connectivity:** SSH and ping tests for all VMs

## K3s Manifests Management

### Application Deployment
```bash
# Deploy Gitea (requires PostgreSQL)
cd k3s/gitea
./deploy-gitea.sh

# Manual deployment steps
kubectl apply -f ../namespaces/gitea-namespace.yml
kubectl apply -f manifests/gitea-secret.yml      # Update secrets first!
kubectl apply -f manifests/gitea-configmap.yml
kubectl apply -f manifests/gitea-pvc.yml
kubectl apply -f manifests/gitea-deployment.yml
kubectl apply -f manifests/gitea-service.yml
kubectl apply -f manifests/gitea-ingress.yml
kubectl apply -f manifests/gitea-servicemonitor.yml
```

### K3s Cluster Operations
```bash
# Check cluster status
kubectl get nodes
kubectl get namespaces
kubectl get pods --all-namespaces

# Monitor applications
kubectl get all -n gitea
kubectl get all -n postgresql
kubectl get all -n argocd

# View logs
kubectl logs -n gitea -l app.kubernetes.io/name=gitea
kubectl describe pod -n gitea <pod-name>

# Access services locally
kubectl port-forward -n gitea svc/gitea-http 3000:3000
```

### Secret Management
```bash
# View secret names (not values)
kubectl get secrets -n gitea

# Update secret values (for production)
kubectl create secret generic gitea-secret \
  --from-literal=gitea-db-password='secure_password' \
  --from-literal=gitea-secret-key='generated_64_char_key' \
  --from-literal=gitea-internal-token='generated_token' \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Storage Management
```bash
# Check persistent volumes
kubectl get pv
kubectl get pvc -n gitea

# Monitor storage usage
kubectl exec -n gitea -it deployment/gitea -- df -h /data
```

### Troubleshooting
```bash
# Debug networking
kubectl exec -n gitea -it deployment/gitea -- nslookup postgresql.postgresql.svc.cluster.local

# Test database connectivity
kubectl exec -n gitea -it deployment/gitea -- nc -zv postgresql.postgresql.svc.cluster.local 5432

# Check resource usage
kubectl top nodes
kubectl top pods -n gitea
```

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

### Claude Code Network Limitations
- **NETWORK SANDBOXED**: Claude Code cannot access local network resources (Proxmox, K3s cluster, VMs)
- **MANUAL TESTING REQUIRED**: All scripts and playbooks must be tested manually by the user
- **SCRIPT VALIDATION ONLY**: Claude Code can create and validate scripts but cannot execute network operations
- **USER EXECUTION**: User must run `./homelab-unified.sh`, ansible-playbook commands, and kubectl manually

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

# PROJECT_PLAN Integration
# Added by Claude Config Manager Extension

When working on this project, always refer to and maintain the project plan located at `.claude/.plans/PROJECT_PLAN.md`.

**Instructions for Claude Code:**
1. **Read the project plan first** - Always check `.claude/.plans/PROJECT_PLAN.md` when starting work to understand the project context, architecture, and current priorities.
2. **Update the project plan regularly** - When making significant changes, discoveries, or completing major features, update the relevant sections in PROJECT_PLAN.md to keep it current.
3. **Use it for context** - Reference the project plan when making architectural decisions, understanding dependencies, or explaining code to ensure consistency with project goals.

**Plan Mode Integration:**
- **When entering plan mode**: Read the current PROJECT_PLAN.md to understand existing context and priorities
- **During plan mode**: Build upon and refine the existing project plan structure
- **When exiting plan mode**: ALWAYS update PROJECT_PLAN.md with your new plan details, replacing or enhancing the relevant sections (Architecture, TODO, Development Workflow, etc.)
- **Plan persistence**: The PROJECT_PLAN.md serves as the permanent repository for all planning work - plan mode should treat it as the single source of truth

This ensures better code quality and maintains project knowledge continuity across different Claude Code sessions and plan mode iterations.
