# Homelab Scripts Organization

## Directory Structure

### Root Level (Core Management)
- `homelab-unified.sh`: Main unified management interface
- `k3s.sh`: K3s cluster management wrapper  
- `vm-discovery.sh`: VM discovery and inventory wrapper

### scripts/management/
**Daily operational scripts**
- `git/git-service-manager.sh`: Git service (Forgejo) management
- `k3s/`: K3s cluster management scripts
- `infrastructure/`: Infrastructure management scripts

### scripts/diagnostic/
**Troubleshooting and monitoring**
- `check-proxmox-storage.sh`: Proxmox storage diagnostics
- `check-forgejo-repos.sh`: Git repository diagnostics
- `diagnose-argocd.sh`: ArgoCD troubleshooting
- `homelab-services-overview.sh`: Complete services overview

### scripts/setup/
**Configuration and setup scripts**
- `configure-argocd-forgejo.sh`: ArgoCD Git integration
- `fix-argocd-nodeport.sh`: ArgoCD network access fixes
- `cleanup-gitlab-k3s.sh`: GitLab cleanup
- `cleanup-failed-scripts.sh`: Script organization

### scripts/archive/
**Completed setup and reference scripts**
- `one-time-setup/`: LXC creation, Forgejo deployment, ArgoCD installation
- `failed-deployments/`: Archived troubleshooting attempts

## Usage Examples

```bash
# Core management (from project root)
./homelab-unified.sh status
./homelab-unified.sh git health
./k3s.sh

# Git service management
./scripts/management/git/git-service-manager.sh health

# Diagnostics
./scripts/diagnostic/homelab-services-overview.sh

# Setup tasks (as needed)
./scripts/setup/configure-argocd-forgejo.sh
```

## Integration with homelab-unified.sh

The main `homelab-unified.sh` script provides unified access to key functionality:
- Git service management via `git-service-manager.sh`
- K3s management via existing commands
- Infrastructure discovery and monitoring
