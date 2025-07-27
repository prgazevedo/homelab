# Gitea Deployment for K3s Homelab

This directory contains Kubernetes manifests and deployment scripts for running Gitea on your K3s homelab cluster.

## Overview

Gitea is a lightweight Git service that provides:
- Git repository hosting
- Web-based Git interface
- Issue tracking
- Pull/merge requests
- Wiki functionality
- CI/CD integration (with ArgoCD)

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   User/Browser  │    │  Gitea Service   │    │   PostgreSQL    │
│                 │    │                  │    │    Database     │
│  gitea.local    │◄──►│  K3s Namespace   │◄──►│  (postgresql)   │
│  :3000          │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │ Persistent Storage│
                       │                  │
                       │ Git Repositories │
                       │ Configuration    │
                       └──────────────────┘
```

## Prerequisites

1. **K3s cluster running** with at least one node
2. **PostgreSQL deployed** in the `postgresql` namespace
3. **kubectl configured** to access your cluster
4. **Storage class available** (K3s includes `local-path` by default)

## Quick Deployment

```bash
# Navigate to the gitea directory
cd k3s/gitea

# Run the deployment script
./deploy-gitea.sh
```

## Manual Deployment

If you prefer to deploy manually:

```bash
# 1. Create namespace
kubectl apply -f ../namespaces/gitea-namespace.yml

# 2. Update secrets (IMPORTANT!)
# Edit manifests/gitea-secret.yml and replace placeholder values
kubectl apply -f manifests/gitea-secret.yml

# 3. Deploy configuration
kubectl apply -f manifests/gitea-configmap.yml

# 4. Create storage
kubectl apply -f manifests/gitea-pvc.yml

# 5. Deploy application
kubectl apply -f manifests/gitea-deployment.yml

# 6. Create services
kubectl apply -f manifests/gitea-service.yml

# 7. Set up ingress
kubectl apply -f manifests/gitea-ingress.yml

# 8. Optional: Set up monitoring
kubectl apply -f manifests/gitea-servicemonitor.yml
```

## Configuration

### Required Secret Updates

Before deploying to production, update these values in `manifests/gitea-secret.yml`:

```yaml
stringData:
  # Generate secure passwords
  gitea-db-password: "your_secure_database_password"
  admin-password: "your_secure_admin_password"
  
  # Generate with: gitea generate secret SECRET_KEY
  gitea-secret-key: "your_64_character_secret_key"
  
  # Generate with: gitea generate secret INTERNAL_TOKEN
  gitea-internal-token: "your_internal_token"
```

### Database Setup

Create the Gitea database in PostgreSQL:

```bash
# Connect to PostgreSQL pod
kubectl exec -it -n postgresql <postgres-pod-name> -- bash

# Create database
createdb -U postgres gitea

# Create user and grant permissions
psql -U postgres -c "CREATE USER gitea WITH PASSWORD 'your_password';"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;"
```

### Host File Setup

Add Gitea to your local `/etc/hosts` file:

```bash
# Get a node IP
kubectl get nodes -o wide

# Add to /etc/hosts
echo "<node-ip> gitea.local" | sudo tee -a /etc/hosts
```

## Access

Once deployed and configured:

- **Web Interface**: http://gitea.local:3000
- **SSH Access**: ssh://git@<node-ip>:30022
- **API**: http://gitea.local:3000/api/v1

## Initial Setup

1. Visit http://gitea.local:3000
2. Complete the installation wizard
3. Create your first repository
4. Configure SSH keys for Git operations

## GitOps Integration

After Gitea is running, you can integrate it with ArgoCD:

1. Create a Git repository in Gitea
2. Configure ArgoCD to monitor the repository
3. Set up automatic deployments from Git commits

## Monitoring

If Prometheus is deployed, Gitea metrics will be automatically collected via the ServiceMonitor.

Access metrics at: http://gitea.local:3000/metrics

## Storage

Gitea uses two persistent volumes:
- **Data Volume** (20Gi): Git repositories and application data
- **Config Volume** (1Gi): Configuration files

Storage is provided by K3s's default `local-path` storage class.

## Security Considerations

1. **Change default passwords** in secrets
2. **Use proper TLS** certificates (not implemented in this basic setup)
3. **Restrict network access** if needed
4. **Regular backups** of persistent volumes
5. **Keep Gitea updated** to latest security patches

## Troubleshooting

### Common Issues

1. **Pod not starting**:
   ```bash
   kubectl logs -n gitea deployment/gitea
   kubectl describe pod -n gitea <pod-name>
   ```

2. **Database connection issues**:
   - Verify PostgreSQL is running
   - Check database credentials in secrets
   - Ensure network policies allow communication

3. **Storage issues**:
   ```bash
   kubectl get pvc -n gitea
   kubectl describe pvc -n gitea gitea-data-pvc
   ```

4. **Ingress not working**:
   - Verify Traefik is running (K3s default)
   - Check /etc/hosts configuration
   - Test with port-forward: `kubectl port-forward -n gitea svc/gitea-http 3000:3000`

### Debug Commands

```bash
# Check all Gitea resources
kubectl get all -n gitea

# View logs
kubectl logs -n gitea -l app.kubernetes.io/name=gitea

# Debug networking
kubectl exec -n gitea -it deployment/gitea -- nslookup postgresql.postgresql.svc.cluster.local

# Test database connection
kubectl exec -n gitea -it deployment/gitea -- nc -zv postgresql.postgresql.svc.cluster.local 5432
```

## Backup and Recovery

### Backup

```bash
# Backup Git repositories
kubectl exec -n gitea -it deployment/gitea -- tar -czf /tmp/gitea-repos.tar.gz /data/git/repositories

# Copy backup to local machine
kubectl cp gitea/<pod-name>:/tmp/gitea-repos.tar.gz ./gitea-repos-backup.tar.gz
```

### Database Backup

```bash
# Backup PostgreSQL database
kubectl exec -n postgresql -it <postgres-pod> -- pg_dump -U postgres gitea > gitea-db-backup.sql
```

## Uninstalling

```bash
# Remove all Gitea resources
kubectl delete namespace gitea

# Clean up persistent volumes if needed
kubectl delete pv <gitea-pv-names>
```

## References

- [Gitea Documentation](https://docs.gitea.io/)
- [K3s Documentation](https://k3s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)