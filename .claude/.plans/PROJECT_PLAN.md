# Homelab Infrastructure Project Plan

## Overview
This is a unified Ansible-based homelab infrastructure project managing a Proxmox homelab with K3s cluster. The system provides complete DISMM (Discover, Import, Sync, Monitor, Maintain) workflow through a single command interface. The key principle is to import and sync existing infrastructure rather than recreate it.

## Architecture

### Current Infrastructure
- **Proxmox Host**: 192.168.2.100 (https://192.168.2.100:8006) configured via `homelab-config.yml`
- **K3s Cluster**: 3-node operational cluster (optimized for application workloads)
  - k3s-master (VM 103): 192.168.2.103 - Running
  - k3s-worker1 (VM 104): 192.168.2.104 - Running
  - k3s-worker2 (VM 105): 192.168.2.105 - Running
- **Virtual Machines**:
  - VM 101 (W11-VM): 192.168.2.101 - Windows 11 workstation
- **LXC Containers**:
  - Container 100 (AI-Dev): Stopped - RTX2080 GPU development environment
  - Container 102 (Linux-DevBox): Running - Linux development environment
  - ✅ Container 200 (Git-Service): Running - Forgejo Git service (192.168.2.200:3000)
- **Deployed Applications**:
  - ✅ Monitoring stack: Prometheus + Grafana (K3s) - Basic infrastructure monitoring
  - ✅ ArgoCD: GitOps platform (K3s) - http://192.168.2.103:30880
  - ✅ Forgejo: Git service (LXC Container) - http://192.168.2.200:3000
  - ✅ Linkding: Bookmark service (Proxmox Host) - http://192.168.2.100:9091 (nginx proxy + Django backend)
  - ✅ Nextcloud: Cloud file service (Proxmox Host) - http://192.168.2.100:9092 (nginx proxy + PHP-FPM backend)
- **Hardware Capabilities**:
  - RTX2080 GPU: Available for AI/ML workloads (Container 100 integration pending)
  - ✅ Hardware monitoring: Complete Proxmox thermal and performance monitoring with Grafana dashboard

### Technology Stack
- **Infrastructure**: Proxmox VE
- **Orchestration**: Ansible playbooks
- **Container Platform**: K3s (lightweight Kubernetes) + LXC containers
- **Database**: PostgreSQL (K3s), SQLite (Git service, Bookmark service, Nextcloud)
- **Monitoring**: Prometheus + Grafana (K3s)
- **GitOps**: ArgoCD (K3s)
- **Git Service**: Forgejo (LXC Container 200 - 192.168.2.200:3000)
- **Authentication**: Keychain-based credential management

### Components Integration
- Proxmox API integration via Ansible uri module
- K3s cluster managed through kubectl and Ansible (application workloads)
- LXC containers for infrastructure services (Git service isolation)
- Infrastructure state exported to YAML files
- GitOps workflow: ArgoCD (K3s) monitors Git repositories (LXC)
- Clean separation: Git infrastructure vs. application platform
- Secure credential management via macOS keychain
- **Hardware monitoring**: Complete Proxmox hardware monitoring with smart sensor filtering and Grafana dashboard
- **GPU integration**: RTX2080 passthrough for AI/ML development environments

## Development Setup
Steps needed to get the project running locally:
1. **Prerequisites**: Ansible, Python 3, kubectl, macOS keychain access
2. **Installation**: `pip install -r requirements.txt`
3. **Configuration**: Create `homelab-config.yml` from template
4. **Activation**: `source venv/bin/activate`
5. **Testing**: `./homelab-unified.sh status`

## Key Files & Directories
- `homelab-unified.sh` - Main entry point for all operations
- `ansible/` - Infrastructure automation and configuration
  - `playbooks/` - Ansible automation playbooks
  - `group_vars/all.yml` - Global configuration including security settings
  - `inventory.yml` - Infrastructure inventory definitions
- `k3s/` - Kubernetes manifests for K3s applications
- `scripts/` - Organized management scripts (see scripts/README.md)
  - `management/` - Daily operational scripts (git, k3s, infrastructure)
  - `diagnostic/` - Troubleshooting and monitoring tools
  - `setup/` - Configuration and setup scripts
  - `archive/` - Completed setup and reference scripts
- `monitoring/` - Observability stack (prometheus-rules/, grafana-dashboards/)
- `tools/` - Management utilities (health-check/, backup-scripts/)
- `homelab-config.yml` - Infrastructure configuration (gitignored)
- `infrastructure-state.yml` - Current infrastructure state export
- `CLAUDE.md` - Project guidance and operational procedures

## Development Workflow

### Daily Operations
1. `./homelab-unified.sh status` - Infrastructure overview
2. VM/container lifecycle management via unified script
3. K3s cluster management via `./homelab-unified.sh k3s`
4. Application deployment via ArgoCD GitOps

### Infrastructure Changes
1. Test Ansible playbooks with --check mode first
2. Use unified script for VM operations
3. Deploy K8s applications via manifest files
4. Monitor infrastructure state post-change
5. Update documentation after successful changes

### GitOps Workflow (Current Architecture)
1. Git repositories hosted in Forgejo (LXC Container 200 - 192.168.2.200:3000)
2. ArgoCD (K3s cluster) monitors Git repositories for changes
3. Automatic deployment of manifest changes to K3s
4. Infrastructure as Code versioning
5. Clean separation: Git infrastructure (LXC) vs. application platform (K3s)

## Important Context

### Safety Guidelines
- **ALWAYS** test VM operations on non-critical VMs first
- **VERIFY** infrastructure state before making changes
- **BACKUP** current state files before major changes
- **MONITOR** infrastructure after operations

### Credential Security
- Proxmox credentials stored in macOS keychain
- Never commit passwords or API tokens to version control
- Use `security add-generic-password` for credential storage
- Ansible playbooks retrieve credentials dynamically

### DISMM Workflow
1. **Discover**: Real-time infrastructure scanning via Proxmox API
2. **Import**: Capture current state without disrupting services
3. **Sync**: Export infrastructure state to versioned YAML files
4. **Monitor**: Continuous health monitoring and resource usage
5. **Maintain**: Automated alerts for stopped services and high usage

## TODO

### Completed (Git Service Architecture)
- [x] **Deploy Git Service** - Forgejo in dedicated LXC container
  - [x] Create LXC container (VM 200) with Ubuntu 22.04
  - [x] Deploy Forgejo with SQLite database
  - [x] Configure static IP 192.168.2.200
  - [x] Set up SSH access and networking
  - [x] Clean up failed K3s Git deployment attempts
  - [x] Update documentation with new architecture
- [x] **Git Service Integration** - Complete functional Git service
  - [x] Create administrator account (prgazevedo / GiteaJourney1)
  - [x] Test Git operations (clone, push, pull)
  - [x] Verify web interface access
  - [x] Set up GitHub repository mirroring
- [x] **ArgoCD Deployment** - GitOps platform operational
  - [x] Install ArgoCD in K3s cluster
  - [x] Configure NodePort access (http://192.168.2.103:30880)
  - [x] Establish ArgoCD admin access (admin / 5ygoY5iAG1cXmWZw)
- [x] **Script Organization** - Clean project structure
  - [x] Organize scripts into management/, diagnostic/, setup/, archive/
  - [x] Update homelab-unified.sh with Git service integration
  - [x] Create scripts/README.md documentation

### Completed Features (Hardware Monitoring)
- [x] **Hardware Monitoring Dashboard** - Proxmox temperature and fan speed monitoring
  - [x] Create Ansible playbook for hardware metrics collection
  - [x] Deploy working Grafana dashboard with refined sensor filtering
  - [x] Add enhanced hardware monitoring alerts to prometheus rules
  - [x] Implement sensor analysis and smart filtering (excludes temp5/fan4 bogus sensors)
  - [x] Create diagnostic scripts for ongoing monitoring troubleshooting
  - [x] Archive development/experimental dashboards and scripts

### Completed Features (Bookmark Service)
- [x] **Linkding Bookmark Service** - Self-hosted bookmark management solution
  - [x] Deploy Linkding service directly on Proxmox host for maximum availability
  - [x] Implement production-grade nginx reverse proxy architecture (port 9091)
  - [x] Configure Django backend with Gunicorn WSGI server (internal port 9090)
  - [x] Solve static file serving issues with nginx (proper CSS/JS loading)
  - [x] Create user account and API token (book / ProxBook1)
  - [x] Enable Tailscale remote access for Work Mac compatibility
  - [x] Configure browser extension integration (http://192.168.2.100:9091)
  - [x] Test comprehensive functionality (CSS styling, API access, health checks)
  - [x] Document production architecture and troubleshooting procedures
  - [x] Solve Work Mac IT restrictions with independent bookmark access

### Completed Features (Cloud File Service)
- [x] **Nextcloud Cloud File Service** - Self-hosted cloud storage and file synchronization
  - [x] Deploy Nextcloud directly on Proxmox host following Linkding architecture pattern
  - [x] Implement nginx reverse proxy with PHP-FPM backend (port 9092)
  - [x] Perform clean Nextcloud installation with SQLite database
  - [x] Fix nginx routing issues for dashboard and theming CSS endpoints
  - [x] Configure proper file permissions and PHP-FPM service setup
  - [x] Create admin account (admin / NextJourney1) with full access
  - [x] Enable WebDAV API for programmatic file access and applications
  - [x] Test core functionality (file upload/download, dashboard, theming)
  - [x] Configure storage directories (/storage/nextcloud-data/, /opt/nextcloud/)
  - [x] Solve theming CSS rewrite cycles and dashboard 403 forbidden errors
  - [x] Enable Tailscale remote access for cloud file service
  - [x] Document WebDAV endpoints for JSONL Claude Code files repository use case

### RTX2080 AI/ML Integration
- [ ] **GPU Development Environment** - AI/ML workload framework
  - [ ] Configure GPU passthrough for Container 100 (AI-Dev)
  - [ ] Deploy NVIDIA Docker runtime and CUDA toolkit
  - [ ] Create Jupyter Lab development environment
  - [ ] Document AI/ML development workflow and best practices
  - [ ] Add GPU monitoring to hardware dashboard

### GitOps Integration (Ongoing)
- [ ] **ArgoCD Application Configuration** - Complete GitOps workflow
  - [ ] Create ArgoCD application manifests in K3s
  - [ ] Configure ArgoCD to monitor Forgejo repositories
  - [ ] Test end-to-end GitOps deployment workflow
  - [ ] Set up automated application synchronization

### Future Roadmap

#### AI/ML Workload Expansion
- [ ] Deploy JupyterHub for multi-user data science environment
- [ ] Deploy MLflow for ML experiment tracking and model registry
- [ ] Implement Kubeflow for ML pipelines in K3s cluster
- [ ] Create AI model serving infrastructure
- [ ] Set up distributed training capabilities

#### Homelab Services
- [ ] Deploy Nextcloud for file sharing
- [ ] Set up Plex/Jellyfin media server
- [ ] Implement Home Assistant for IoT
- [ ] Deploy Vaultwarden password manager
- [ ] Set up Nginx reverse proxy

#### Infrastructure Improvements
- [ ] Backup W11 VM and AI container
- [ ] Implement automated backup strategies
- [ ] Enhanced monitoring and alerting
- [ ] Network segmentation and security hardening
- [ ] Disaster recovery procedures

### Development Environment Enhancement
- [ ] CI/CD pipeline integration
- [ ] Automated testing for infrastructure changes
- [ ] Enhanced security scanning and compliance
- [ ] Performance optimization and scaling strategies
