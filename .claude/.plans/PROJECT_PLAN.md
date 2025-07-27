# Homelab Infrastructure Project Plan

## Overview
This is a unified Ansible-based homelab infrastructure project managing a Proxmox homelab with K3s cluster. The system provides complete DISMM (Discover, Import, Sync, Monitor, Maintain) workflow through a single command interface. The key principle is to import and sync existing infrastructure rather than recreate it.

## Architecture

### Current Infrastructure
- **Proxmox Host**: Configured via `homelab-config.yml`
- **K3s Cluster**: 3-node operational cluster
  - k3s-master (VM 103): Running
  - k3s-worker1 (VM 104): Running
  - k3s-worker2 (VM 105): Running
- **Deployed Applications**:
  - ✅ PostgreSQL: Database backend
  - ✅ Monitoring stack: Prometheus + Grafana
  - ✅ ArgoCD: GitOps platform
  - 🚧 Gitea: Git service (in progress)

### Technology Stack
- **Infrastructure**: Proxmox VE
- **Orchestration**: Ansible playbooks
- **Container Platform**: K3s (lightweight Kubernetes)
- **Database**: PostgreSQL
- **Monitoring**: Prometheus + Grafana
- **GitOps**: ArgoCD
- **Git Service**: Gitea (deploying)
- **Authentication**: Keychain-based credential management

### Components Integration
- Proxmox API integration via Ansible uri module
- K3s cluster managed through kubectl and Ansible
- Infrastructure state exported to YAML files
- GitOps workflow with ArgoCD for application deployment
- Secure credential management via macOS keychain

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
- `k8s/` - Kubernetes manifests (to be created)
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

### GitOps Workflow (Post-Gitea)
1. Git repositories hosted in Gitea
2. ArgoCD monitors Git repositories for changes
3. Automatic deployment of manifest changes
4. Infrastructure as Code versioning

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

### Immediate Priorities
- [ ] **Deploy Gitea** (final component for development platform)
  - Create K8s manifests directory structure
  - Deploy Gitea with PostgreSQL integration
  - Configure persistent storage
  - Set up monitoring and health checks

### Post-Gitea Configuration
- [ ] Set up first Git repository in Gitea
- [ ] Configure GitOps workflow with ArgoCD
- [ ] Add /etc/hosts entries for service access (gitea.local, grafana.local, argocd.local)
- [ ] Document K8s manifests management in CLAUDE.md

### Future Roadmap

#### AI/ML Workloads
- [ ] Deploy NVIDIA GPU operator
- [ ] Set up JupyterHub for data science
- [ ] Deploy MLflow for ML experiment tracking
- [ ] Implement Kubeflow for ML pipelines
- [ ] Deploy AI Research Environment (VM 106) with GPU passthrough

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
