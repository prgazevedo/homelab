# K3s Homelab Manifests

This directory contains Kubernetes manifests and deployment scripts for managing applications on your K3s homelab cluster.

## Directory Structure

```
k3s/
├── README.md                    # This file
├── namespaces/                  # Namespace definitions
│   └── gitea-namespace.yml     # Gitea namespace
├── gitea/                      # Gitea Git service
│   ├── README.md              # Detailed Gitea documentation
│   ├── deploy-gitea.sh        # Automated deployment script
│   └── manifests/             # Kubernetes manifests
│       ├── gitea-configmap.yml
│       ├── gitea-deployment.yml
│       ├── gitea-ingress.yml
│       ├── gitea-pvc.yml
│       ├── gitea-secret.yml
│       ├── gitea-service.yml
│       └── gitea-servicemonitor.yml
├── monitoring/                 # Monitoring stack configurations
│   ├── prometheus/            # Prometheus configurations
│   └── grafana/              # Grafana dashboards
├── argocd/                    # ArgoCD GitOps configurations
│   └── manifests/
├── postgresql/                # Database configurations
│   └── manifests/
└── base/                      # Common configurations
    ├── kustomization/         # Kustomize configurations
    └── common/               # Shared resources
```

## Current Applications

### ✅ Deployed
- **PostgreSQL**: Database backend (assumed deployed)
- **Monitoring Stack**: Prometheus + Grafana (assumed deployed)
- **ArgoCD**: GitOps platform (assumed deployed)

### 🚧 Ready to Deploy
- **Gitea**: Git service with comprehensive manifests and deployment script

## Quick Start

### Deploy Gitea

1. **Prerequisites Check**:
   ```bash
   # Verify K3s cluster is accessible
   kubectl cluster-info
   
   # Check if PostgreSQL is running
   kubectl get pods -n postgresql
   ```

2. **Deploy Gitea**:
   ```bash
   cd gitea
   ./deploy-gitea.sh
   ```

3. **Post-Deployment**:
   ```bash
   # Add to /etc/hosts
   echo "$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}') gitea.local" | sudo tee -a /etc/hosts
   
   # Access Gitea
   open http://gitea.local:3000
   ```

## Security Notes

### Before Production Use

1. **Update Secret Values**: All secrets contain placeholder values that must be replaced:
   ```bash
   # Edit gitea secret
   kubectl edit secret gitea-secret -n gitea
   ```

2. **Generate Secure Tokens**:
   ```bash
   # Install Gitea locally to generate tokens
   gitea generate secret SECRET_KEY
   gitea generate secret INTERNAL_TOKEN
   ```

3. **Database Setup**:
   ```bash
   # Create Gitea database in PostgreSQL
   kubectl exec -n postgresql -it <postgres-pod> -- createdb -U postgres gitea
   ```

## Cluster Discovery

### Current State Analysis

Use the Ansible playbook to discover current cluster state:

```bash
# From project root
ansible-playbook ansible/playbooks/k3s-cluster-discovery.yml -i ansible/inventory.yml
```

This will generate `k3s-cluster-state.yml` with:
- Node status and information
- Deployed applications and services
- Storage utilization
- Namespace inventory
- Security overview

## Common Operations

### Application Management

```bash
# Check all applications
kubectl get all --all-namespaces

# Monitor specific namespace
kubectl get all -n gitea
kubectl logs -n gitea -l app.kubernetes.io/name=gitea

# Scale applications
kubectl scale deployment gitea -n gitea --replicas=2
```

### Storage Management

```bash
# Check storage usage
kubectl get pv
kubectl get pvc --all-namespaces

# Monitor disk usage in pods
kubectl exec -n gitea -it deployment/gitea -- df -h
```

### Networking

```bash
# Port forward for local access
kubectl port-forward -n gitea svc/gitea-http 3000:3000

# Test internal networking
kubectl exec -n gitea -it deployment/gitea -- nslookup postgresql.postgresql.svc.cluster.local
```

## GitOps Workflow (Post-Gitea)

Once Gitea is deployed, you can establish a complete GitOps workflow:

1. **Create Git Repository**: Use Gitea to host your manifests
2. **Configure ArgoCD**: Point ArgoCD to monitor your Git repository
3. **Automated Deployment**: Changes to Git automatically deploy to K3s

### Example GitOps Setup

```bash
# Create a new repository in Gitea for K3s manifests
# Configure ArgoCD Application
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: homelab-k3s
  namespace: argocd
spec:
  source:
    repoURL: http://gitea.local:3000/homelab/k3s-manifests.git
    targetRevision: main
    path: .
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

## Monitoring and Observability

### Prometheus Integration

All applications include ServiceMonitor configurations for Prometheus:

```bash
# Check if monitoring is working
kubectl get servicemonitors --all-namespaces

# Access Prometheus (assuming it's deployed)
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

### Grafana Dashboards

Custom dashboards for homelab monitoring should be added to:
- `monitoring/grafana/` directory
- Deployed via ConfigMap or GitOps

## Backup and Recovery

### Application Data

```bash
# Backup Gitea repositories
kubectl exec -n gitea -it deployment/gitea -- tar -czf /tmp/repos-backup.tar.gz /data/git/repositories

# Copy to local machine
kubectl cp gitea/<pod-name>:/tmp/repos-backup.tar.gz ./gitea-backup-$(date +%Y%m%d).tar.gz
```

### Database Backup

```bash
# Backup PostgreSQL (adjust for your setup)
kubectl exec -n postgresql -it <postgres-pod> -- pg_dump -U postgres gitea > gitea-db-backup-$(date +%Y%m%d).sql
```

## Troubleshooting

### Common Issues

1. **Pod Not Starting**:
   ```bash
   kubectl describe pod -n gitea <pod-name>
   kubectl logs -n gitea <pod-name>
   ```

2. **Storage Issues**:
   ```bash
   kubectl get events -n gitea
   kubectl describe pvc -n gitea
   ```

3. **Network Connectivity**:
   ```bash
   kubectl exec -n gitea -it deployment/gitea -- ping postgresql.postgresql.svc.cluster.local
   ```

4. **Resource Constraints**:
   ```bash
   kubectl top nodes
   kubectl top pods -n gitea
   ```

### Debug Commands

```bash
# Full cluster status
kubectl get all --all-namespaces
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Resource usage
kubectl describe nodes
kubectl get pods --all-namespaces -o wide

# Storage investigation
kubectl get pv,pvc --all-namespaces
```

## Future Applications

The following applications are planned for deployment:

### AI/ML Workloads
- NVIDIA GPU Operator
- JupyterHub
- MLflow
- Kubeflow

### Homelab Services
- Nextcloud
- Plex/Jellyfin
- Home Assistant
- Vaultwarden

### Infrastructure
- Nginx Ingress Controller
- Cert-Manager
- External DNS

## Contributing

When adding new applications:

1. Create a new directory under `k3s/`
2. Include comprehensive manifests
3. Add deployment script
4. Update this README
5. Include monitoring configuration
6. Document in main `CLAUDE.md`

## References

- [K3s Documentation](https://k3s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Gitea Documentation](https://docs.gitea.io/)