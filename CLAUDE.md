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

This is a homelab infrastructure-as-code project designed to manage a Proxmox homelab with K3s cluster and LXC containers through **unified Ansible-based automation**. The system provides complete DISMM (Discover, Import, Sync, Monitor, Maintain) workflow through a single command interface. The key principle is to import and sync existing infrastructure rather than recreate it.

### Architecture Philosophy
- **Separation of Concerns**: Git infrastructure (LXC) vs. application platform (K3s)
- **Hardware Monitoring**: Proxmox thermal and performance monitoring with RTX2080 GPU integration
- **AI/ML Integration**: RTX2080 GPU utilization for machine learning workloads and development
- **Unified Management**: Single command interface for all infrastructure operations
- **GitOps Workflow**: ArgoCD (K3s) monitors Git repositories (LXC) for automated deployments

## Infrastructure Layout

The system works with any Proxmox homelab configuration. Your specific infrastructure details should be configured in `homelab-config.yml` (see `homelab-config.yml.example` for template).

**Current Infrastructure:**
- **Proxmox Host:** 192.168.2.100 (https://192.168.2.100:8006)
- **Virtual Machines:**
  - VM 101 (W11-VM): 192.168.2.101 - Windows 11 workstation
  - VM 103 (K3s Master): 192.168.2.103 - Kubernetes control plane
  - VM 104 (K3s Worker1): 192.168.2.104 - Kubernetes worker node
  - VM 105 (K3s Worker2): 192.168.2.105 - Kubernetes worker node
- **LXC Containers:**
  - Container 100 (AI-Dev): Stopped - RTX2080 GPU development environment
  - Container 102 (Linux-DevBox): Running - Linux development environment
  - Container 200 (Git-Service): Running - Forgejo Git service
- **Key Services:**
  - Forgejo Git: http://192.168.2.200:3000 (prgazevedo / GiteaJourney1)
  - ArgoCD GitOps: http://192.168.2.103:30880 (admin / 5ygoY5iAG1cXmWZw)
  - Linkding Bookmarks: http://192.168.2.100:9091 (book / ProxBook1) - Nginx proxy with CSS/JS
  - K3s Cluster: 3-node operational with local-path storage

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
./homelab-unified.sh start 100 lxc     # Start AI-Dev container
./homelab-unified.sh start 102 lxc     # Start Linux-DevBox container
./homelab-unified.sh start 200 lxc     # Start Git-Service container

# Stop container
./homelab-unified.sh stop 100 lxc      # Stop AI-Dev container
./homelab-unified.sh stop 102 lxc      # Stop Linux-DevBox container  
./homelab-unified.sh stop 200 lxc      # Stop Git-Service container

# Restart container
./homelab-unified.sh restart 200 lxc   # Restart Git-Service container
```

### Git Service Management (Forgejo in LXC)
```bash
# Git service unified management
./homelab-unified.sh git status        # Git service container status
./homelab-unified.sh git health        # Comprehensive health check
./homelab-unified.sh git shell         # SSH into Git service container
./homelab-unified.sh git service-status # Forgejo service status
./homelab-unified.sh git service-logs  # View Forgejo service logs

# Direct access methods
ssh git@192.168.2.200                  # Direct SSH access to Git service
curl -s http://192.168.2.200:3000/api/v1/version  # API health check

# Hardware monitoring and GPU management (NEW)
./homelab-unified.sh hardware status   # Proxmox hardware monitoring
./homelab-unified.sh hardware temps    # Temperature and fan speed dashboard
./homelab-unified.sh gpu status        # RTX2080 GPU utilization
./homelab-unified.sh gpu resources     # GPU memory and compute usage
```

### K3s Cluster Management

#### Cluster Status
K3s cluster is operational with 3 nodes:
- **Master**: k3s-master (192.168.2.103) - 4GB RAM, 2 CPU
- **Worker1**: k3s-worker1 (192.168.2.104) - 4GB RAM, 2 CPU  
- **Worker2**: k3s-worker2 (192.168.2.105) - 4GB RAM, 2 CPU
- **Total Resources**: 12GB RAM, 6 CPU cores
- **Storage**: local-path provisioner (working)

#### Deployment Guidelines
```bash
# Check cluster status
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl get nodes -o wide"

# Storage diagnostics
./diagnose-storage.sh

# Deploy applications using Ansible remote execution
ansible k3s-master -i ansible/inventory.yml -m copy -a "src=manifests/ dest=/tmp/"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl apply -f /tmp/"
```

#### Architecture Decision: Separated Git Service
**Git Service Architecture**: After extensive troubleshooting with K3s-hosted Git services, the architecture was redesigned:
- **Previous Issues**: GitLab CE Helm chart persistent 422 errors, Gitea container runtime incompatibility
- **Solution**: Dedicated LXC container (VM 200) running Forgejo Git service
- **Benefits**: Isolation from application workloads, simpler troubleshooting, reliable operation
- **GitOps Integration**: ArgoCD in K3s monitors Git repositories hosted in LXC container

**Storage Setup**: Local-path provisioner working correctly for application workloads:
- Directory: `/var/lib/rancher/k3s/storage` (auto-created by provisioner)
- **Optimized**: K3s cluster now focused on application deployment rather than Git infrastructure

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
./k3s-unified.sh deploy <app>       # Deploy applications to K3s
./k3s-unified.sh logs <app>         # Show application logs
./k3s-unified.sh backup <app>       # Backup application data

# Monitoring and troubleshooting
./k3s-unified.sh metrics            # Show resource usage
./k3s-unified.sh events             # Recent cluster events
./k3s-unified.sh storage            # Storage information
./k3s-unified.sh network            # Network overview

# Utilities
./k3s-unified.sh port-forward <app> <service> <port>:<port>
./k3s-unified.sh shell <app> <pod-name>
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
  - **monitoring/**: Prometheus and Grafana configurations
  - **namespaces/**: Namespace definitions
  - **base/**: Common configurations and kustomizations
- **scripts/**: Organized management scripts (see scripts/README.md)
  - **management/**: Daily operational scripts
    - **git/**: Git service (Forgejo) management
    - **k3s/**: K3s cluster management scripts
    - **infrastructure/**: Infrastructure management scripts
  - **diagnostic/**: Troubleshooting and monitoring
  - **setup/**: Configuration and setup scripts
  - **archive/**: Completed setup and reference scripts
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
- **192.168.2.200** - Container 200 (git-service) - Forgejo Git service

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

## Hardware Monitoring & Performance

The homelab includes comprehensive hardware monitoring for thermal management and performance optimization using Prometheus, Grafana, and node-exporter.

### Hardware Monitoring Setup
```bash
# Core hardware monitoring setup
./scripts/setup/setup-hardware-monitoring.sh        # Complete monitoring stack setup
./scripts/setup/install-proxmox-node-exporter.sh    # Install node-exporter on Proxmox

# Hardware monitoring diagnostics
./scripts/diagnostic/analyze-all-sensors.sh         # Analyze available sensors
./scripts/diagnostic/check-grafana-prometheus-connection.sh  # Test monitoring stack
```

### Monitoring Stack Components
- **Prometheus**: Hardware metrics collection via node-exporter (http://192.168.2.103:30090)
- **Grafana**: Hardware monitoring dashboards (http://192.168.2.103:30030)
- **Node Exporter**: Hardware metrics collector installed on Proxmox host
- **Dashboard**: `monitoring/grafana-dashboards/proxmox-hardware-refined.json` (working dashboard)

### Monitored Hardware Sensors
**✅ Temperature Sensors:**
- **NVMe SSD**: nvme_nvme0 - temp1 (typically 61-65°C)
- **CPU**: pci0000:00_0000:00:18_3 - temp1/temp3 (typically 65-67°C) 
- **Motherboard**: Various temp1/temp2/temp3/temp4/temp6 sensors (54-69°C range)
- **Filtered Out**: temp5 (216°C bogus reading automatically excluded)

**✅ Fan Sensors:**
- **Active Fans**: fan1 (520 RPM), fan2 (388 RPM), fan3 (2766 RPM - likely CPU fan)
- **Filtered Out**: fan4 (0 RPM inactive fan automatically excluded)

**✅ Storage Monitoring:**
- **Container 200 Disk**: /rpool/data/subvol-200-disk-0 (primary storage)
- **Root Filesystem**: / (system disk usage)
- **Filtered Out**: /var/lib/lxcfs (virtual filesystem automatically excluded)

**✅ System Metrics:**
- **Voltages**: Power supply rail monitoring (12V, 5V, 3.3V)
- **Current**: System power draw monitoring (~11A)
- **CPU/Memory**: Performance utilization monitoring
- **Network**: Interface throughput monitoring

### Grafana Dashboard Access
```bash
# Access Grafana dashboard
http://192.168.2.103:30030/dashboards

# Import working dashboard
Dashboard: "Proxmox Hardware Monitoring - Refined"
File: monitoring/grafana-dashboards/proxmox-hardware-refined.json
UID: proxmox-hardware-refined
```

### Hardware Monitoring Features
- **Smart Filtering**: Automatically excludes bogus sensors (temp5, fan4, virtual filesystems)
- **Real-time Monitoring**: 30-second refresh with 15-minute time window
- **Color-coded Thresholds**: Green/Yellow/Red alerts for temperature and performance
- **Multi-panel Layout**: Separate panels for temperatures, fans, storage, voltages, performance
- **Historical Data**: Time-series trend analysis for all metrics

## RTX2080 AI/ML Integration

The homelab includes RTX2080 GPU integration for AI/ML workloads and development environments.

### AI/ML Development Environment
```bash
# GPU-enabled container management
./homelab-unified.sh start 100 lxc      # Start AI-Dev container with GPU passthrough
./homelab-unified.sh gpu status         # Check GPU utilization and temperature
./homelab-unified.sh gpu resources      # GPU memory and compute usage

# AI/ML development access
ssh ai-dev@192.168.2.xxx               # Direct SSH to AI development container
http://192.168.2.xxx:8888               # Jupyter Lab interface (when deployed)
```

### RTX2080 GPU Capabilities
- **CUDA Cores**: 2944 CUDA cores for parallel computing
- **Memory**: 8GB GDDR6 for large model training
- **Architecture**: Turing with RT cores and Tensor cores
- **Use Cases**: Deep learning training, inference, computer vision, NLP
- **Integration**: Docker with NVIDIA runtime, Kubernetes GPU operator

### AI/ML Framework Support
- **TensorFlow**: GPU-accelerated training and inference
- **PyTorch**: CUDA support for neural network development
- **Jupyter Lab**: Interactive development environment
- **CUDA Toolkit**: Low-level GPU programming and optimization
- **Container Runtime**: NVIDIA Docker for isolated GPU environments

## Linkding Bookmark Service (Proxmox Host)

The Linkding bookmark service runs directly on the Proxmox host (192.168.2.100) as a foundational infrastructure service, providing web-based bookmark management accessible from any browser without dependency on Chrome sync or cloud storage.

### Architecture Decision: Nginx Proxy + Django Backend
**Service Architecture**: Nginx reverse proxy (port 9091) + Linkding backend (internal port 9090)
- **Frontend (Nginx)**: Serves static files (CSS/JS) directly for optimal performance
- **Backend (Linkding)**: Django application with Gunicorn WSGI server (internal access only)
- **Benefits**: Production-grade static file serving, security, proper CSS/JS loading
- **Ports**: External access via 9091, internal Django on 9090 (localhost only)

### Current Service Status
- **Service**: Linkding bookmark manager with nginx proxy
- **External Access**: http://192.168.2.100:9091 (nginx proxy)
- **Internal Backend**: http://127.0.0.1:9090 (Linkding Django app)
- **User**: book / ProxBook1 (created with API token)
- **Features**: Web interface, browser extensions, API access, import/export

### Linkding Service Management
```bash
# Deploy complete nginx + Linkding setup
./scripts/setup/configure-nginx-linkding.sh              # Complete nginx proxy setup
./scripts/setup/create-linkding-user-token.sh            # Create user and API token

# Service management
systemctl status linkding                    # Check Linkding service status
systemctl status nginx                       # Check nginx status
systemctl restart linkding                   # Restart Linkding backend
systemctl reload nginx                       # Reload nginx configuration

# Diagnostics and troubleshooting
./scripts/diagnostic/diagnose-nginx-linkding-issue.sh    # Comprehensive diagnostics
./scripts/diagnostic/test-nginx-linkding.sh              # Quick connectivity tests
```

### Linkding Service Access
```bash
# Web Interface (PRODUCTION - Use this URL)  
http://192.168.2.100:9091                   # Nginx proxy with proper CSS/JS
Login: book / ProxBook1                      # Created user account

# Tailscale Access (Remote access)
http://TAILSCALE_IP:9091                     # Same interface via Tailscale

# Internal Backend (Debugging only)
http://127.0.0.1:9090                       # Direct Django app (localhost only)

# Browser Extensions Setup
Firefox: Use http://192.168.2.100:9091 as server URL
Chrome: Use http://192.168.2.100:9091 as server URL
API Token: Generated for 'book' user (check user settings)

# API Access
http://192.168.2.100:9091/api/              # REST API endpoint via nginx
Authorization: Token YOUR_API_TOKEN_HERE    # Use token from user settings
```

### Working Architecture Details
```bash
# Nginx Configuration (Port 9091)
/etc/nginx/sites-available/linkding         # Nginx site configuration
/etc/nginx/sites-enabled/linkding           # Enabled site symlink

# Linkding Configuration  
/etc/systemd/system/linkding.service        # Systemd service (internal port 9090)
/opt/linkding/linkding/                      # Application directory
/opt/linkding/linkding/static/               # Static files served by nginx
/opt/linkding/linkding/data/                 # Bookmark database and media

# Service Architecture
Nginx (0.0.0.0:9091)          # External access, serves static files
  ↓ Proxy pass for dynamic content
Linkding (127.0.0.1:9090)     # Internal Django app, database operations
```

### Linkding Service Features
- **Production-Grade Performance**: Nginx serves CSS/JS, Django handles app logic
- **Cross-Platform Access**: Works on Mac, mobile, any browser with proper styling
- **No Cloud Dependency**: Self-hosted solution bypasses IT restrictions  
- **Browser Integration**: Extensions work with http://192.168.2.100:9091
- **Import/Export**: Migrate existing bookmarks from Chrome/Firefox
- **Search and Tags**: Fast bookmark organization and retrieval
- **API Access**: Full REST API with authentication tokens
- **Tailscale Ready**: Remote access via Tailscale network
- **Backup-Friendly**: SQLite database at /opt/linkding/linkding/data/

### Post-Deployment Verification
```bash
# 1. Test web interface with proper CSS styling
curl -s http://192.168.2.100:9091/static/theme-light.css | head -3

# 2. Test nginx health endpoint
curl -s http://192.168.2.100:9091/health

# 3. Verify API access
curl -H "Authorization: Token YOUR_TOKEN" http://192.168.2.100:9091/api/bookmarks/

# 4. Check service logs
journalctl -u linkding -f                   # Linkding application logs
tail -f /var/log/nginx/access.log           # Nginx access logs
tail -f /var/log/nginx/error.log            # Nginx error logs
```

## Git Service Management (LXC Container)

The Git service runs in a dedicated LXC container (VM 200) for reliability and isolation from the K3s cluster. This architecture decision was made after extensive troubleshooting with K3s-hosted Git services (GitLab CE, Gitea) to ensure stable, isolated Git infrastructure.

### Current Git Service Status
- **Service**: Forgejo (Gitea fork) running in LXC Container 200
- **Access**: http://192.168.2.200:3000
- **Admin**: prgazevedo / GiteaJourney1
- **Features**: Git repos, GitHub mirroring, issues, pull requests
- **Integration**: ArgoCD monitors repositories for GitOps deployments

### Git Service Operations
```bash
# Create and deploy Git service LXC container
./create-git-service-lxc.sh         # Create LXC container with Ubuntu 22.04
./deploy-forgejo-lxc.sh             # Deploy Forgejo Git service

# Service management via Ansible
ansible git-service -i ansible/inventory.yml -m shell -a "systemctl status forgejo"
ansible git-service -i ansible/inventory.yml -m shell -a "systemctl restart forgejo"
ansible git-service -i ansible/inventory.yml -m shell -a "systemctl stop forgejo"
ansible git-service -i ansible/inventory.yml -m shell -a "systemctl start forgejo"

# Direct container management
./homelab-unified.sh start 200 lxc   # Start Git service container
./homelab-unified.sh stop 200 lxc    # Stop Git service container
./homelab-unified.sh restart 200 lxc # Restart Git service container
```

### Git Service Access
```bash
# Web Interface
http://192.168.2.200:3000           # Forgejo web interface

# SSH Git Operations
git clone git@192.168.2.200:user/repo.git
git remote add origin git@192.168.2.200:user/repo.git

# Direct SSH Access
ssh git@192.168.2.200               # Direct SSH to Git service container
```

### Git Service Health Monitoring
```bash
# Check service status
curl -s http://192.168.2.200:3000/api/v1/version

# Monitor logs
ansible git-service -i ansible/inventory.yml -m shell -a "journalctl -u forgejo -f"

# Check disk usage
ansible git-service -i ansible/inventory.yml -m shell -a "df -h /var/lib/forgejo"

# Check process status
ansible git-service -i ansible/inventory.yml -m shell -a "ps aux | grep forgejo"
```

### Git Service Configuration
```bash
# Service configuration files
/etc/forgejo/app.ini                # Main Forgejo configuration
/var/lib/forgejo/forgejo.db         # SQLite database
/var/lib/forgejo/repositories       # Git repositories storage
/var/lib/forgejo/log               # Service logs
```

### GitOps Integration
```bash
# ArgoCD monitors Git repositories in LXC container
# Applications deployed to K3s cluster based on Git changes
# Clean separation: Git infrastructure vs. application platform

# Update ArgoCD to monitor LXC Git repositories
kubectl edit configmap argocd-cm -n argocd
# Add repository: http://192.168.2.200:3000/user/repo.git
```

## K3s Manifests Management

### Application Deployment
```bash
# Deploy applications to K3s cluster (application workloads only)
kubectl apply -f manifests/
kubectl apply -f k3s/monitoring/
kubectl apply -f k3s/argocd/

# GitOps-based deployment via ArgoCD
# ArgoCD monitors Git repositories in LXC container (192.168.2.200:3000)
# Applications automatically deployed based on Git changes
```

### K3s Cluster Operations
```bash
# Check cluster status
kubectl get nodes
kubectl get namespaces
kubectl get pods --all-namespaces

# Monitor applications
kubectl get all -n argocd
kubectl get all -n monitoring
kubectl get all -n postgresql

# View logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
kubectl describe pod -n argocd <pod-name>

# Access services locally
kubectl port-forward -n argocd svc/argocd-server 8080:80
```

### Secret Management
```bash
# View secret names (not values)
kubectl get secrets -n argocd
kubectl get secrets -n monitoring

# Update ArgoCD admin password (for production)
kubectl -n argocd patch secret argocd-initial-admin-secret \
  -p '{"stringData": {"password": "new-secure-password"}}'
```

### Storage Management
```bash
# Check persistent volumes
kubectl get pv
kubectl get pvc --all-namespaces

# Monitor storage usage for applications
kubectl exec -n argocd -it deployment/argocd-server -- df -h
kubectl top nodes
```

### Troubleshooting
```bash
# Debug networking
kubectl exec -n argocd -it deployment/argocd-server -- nslookup kubernetes.default.svc.cluster.local

# Test Git service connectivity from K3s
kubectl run test-pod --image=busybox --restart=Never -- wget -qO- http://192.168.2.200:3000/api/v1/version

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces
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

### Script Output Requirements - MANDATORY
- **LOG TO FILE**: ALL diagnostic and operational scripts MUST output results to timestamped log files
- **DUAL OUTPUT**: Scripts MUST use `tee` to write to both stdout and log files simultaneously
- **LOG DIRECTORY**: Store logs in `logs/` directory with descriptive filenames
- **TIMESTAMP FORMAT**: Use format: `logs/script-name-YYYYMMDD-HHMMSS.log`
- **STANDARD PATTERN**: Every script MUST include this logging setup:
  ```bash
  # Create logs directory if it doesn't exist
  mkdir -p logs
  
  # Set up logging
  LOGFILE="logs/script-name-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$LOGFILE")
  exec 2>&1
  
  echo "🔍 Script Title"
  echo "==============="
  echo "Log file: $LOGFILE"
  echo "Timestamp: $(date)"
  echo ""
  ```
- **NEVER CREATE SCRIPTS WITHOUT LOGGING**: This is mandatory for all homelab scripts

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
