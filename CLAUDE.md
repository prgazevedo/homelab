# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a homelab infrastructure-as-code project designed to manage a Proxmox homelab with K3s cluster through **discovery, import, and synchronization** workflows. The key principle is to import and sync existing infrastructure rather than recreate it.

## Infrastructure Layout

**Proxmox Host:** 192.168.2.100 (AMD Ryzen 9 3950X, 64GB RAM, RTX 2080)

**Existing VMs:**
- VM 101: W11-VM (Windows 11, 6 CPU, 16GB RAM, 250GB)
- VM 102: linux-devbox (Container, 4 CPU, 8GB RAM, 98GB)  
- VM 103: k3s-master (2 CPU, 4GB RAM, 100GB) - 192.168.2.103
- VM 104: k3s-worker1 (2 CPU, 4GB RAM, 100GB) - 192.168.2.104
- VM 105: k3s-worker2 (2 CPU, 4GB RAM, 100GB) - 192.168.2.105
- VM 100: ai-dev (Container, stopped, 8 CPU, 32GB RAM, 64GB)

**K3s Services:** Gitea, PostgreSQL, Monitoring stack, ArgoCD (all deployed)

## Common Commands

### Discovery and Initial Setup
```bash
# Discover current infrastructure
make discover

# Quick start workflow (discover -> import -> sync)
make quickstart

# Discover only Proxmox
make discover-proxmox

# Discover only K3s cluster
make discover-k3s
```

### Terraform Operations
```bash
# Initialize Terraform
make terraform-init

# Import existing VMs into Terraform state
make import

# Sync current state with IaC
make sync

# Plan changes
make terraform-plan

# Apply changes (use carefully!)
make terraform-apply

# Show current state
make terraform-show
```

### Health and Monitoring
```bash
# Run health checks
make health

# Get health status as JSON
make health-json

# Export K8s manifests
make export-k8s

# Create backup
make backup
```

### Validation and Testing
```bash
# Validate Terraform configs
make validate

# Run all tests (health + validation)
make test
```

## Project Architecture

### Directory Structure
- **discovery/**: Infrastructure discovery tools (proxmox-scanner.py, k3s-scanner.py)
- **sync/**: Synchronization tools (terraform-import/, k8s-export/)
- **terraform/**: Infrastructure management (imported/, new/, modules/)
- **monitoring/**: Observability (prometheus-rules/, grafana-dashboards/)
- **tools/**: Management utilities (health-check/, backup-scripts/)

### Key Scripts
- `discovery/proxmox-scanner.py`: Scans Proxmox API for VM/container inventory
- `discovery/k3s-scanner.py`: Discovers K3s cluster state and resources
- `sync/terraform-import/import-existing.sh`: Imports existing VMs into Terraform
- `sync/terraform-import/generate-configs.py`: Generates TF configs from discovery data
- `tools/health-check/health-check.py`: Comprehensive health monitoring

### Terraform Configuration
- **Provider:** telmate/proxmox ~> 2.9
- **Backend:** Local state (consider remote for production)
- **Variables:** Defined in variables.tf, use terraform.tfvars for values
- **Imported Resources:** All existing VMs have `prevent_destroy = true`

## Workflow Patterns

### Import Existing Infrastructure
1. Run discovery to scan current state
2. Import VMs into Terraform state
3. Generate matching Terraform configs
4. Validate no drift exists

### Adding New Infrastructure
1. Create configs in terraform/new/
2. Plan and apply changes
3. Update documentation

### Monitoring and Maintenance
1. Regular health checks via make health
2. Backup current state via make backup
3. Monitor for configuration drift

## Safety Guidelines

### Critical Safety Rules
- **NEVER** run `terraform destroy` - all resources have `prevent_destroy = true`
- **ALWAYS** run `terraform plan` before `terraform apply`
- **VERIFY** health checks pass before making changes
- **BACKUP** state before major changes

### Credential Management
- Proxmox credentials go in `terraform/terraform.tfvars` (gitignored)
- Never commit passwords or API tokens
- Use environment variables for CI/CD

### Change Management
- Test changes in development first
- Use `make validate` before applying
- Monitor infrastructure after changes
- Keep rollback plans ready

## Development Guidelines

### Adding New Discovery Scripts
- Follow the pattern in existing scanners
- Output JSON for programmatic processing
- Include summary and detailed modes
- Handle errors gracefully

### Extending Terraform Modules
- Create reusable modules in terraform/modules/
- Follow naming conventions: resource_type_purpose
- Include validation and documentation
- Test with plan before apply

### Adding Health Checks
- Extend tools/health-check/health-check.py
- Include timeout and error handling
- Provide both human and JSON output
- Test edge cases and failures

## Troubleshooting

### Common Issues
- **Terraform import fails:** Check VM exists and credentials are correct
- **Health check timeouts:** Verify network connectivity and service status  
- **Discovery script errors:** Ensure API access and proper credentials
- **Plan shows drift:** Review generated configs vs actual state

### Debug Commands
```bash
# Check Terraform state
terraform state list
terraform show <resource>

# Test connectivity
ping 192.168.2.100
kubectl cluster-info

# Verbose health check
python3 tools/health-check/health-check.py --config health-config.json

# Discovery with debug
python3 discovery/proxmox-scanner.py --host 192.168.2.100 --format summary
```

This project prioritizes safety and incremental changes over speed. Always verify current state before making modifications.