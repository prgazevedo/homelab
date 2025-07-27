#!/bin/bash
# Gitea Deployment Script for K3s Homelab
# This script deploys Gitea with PostgreSQL integration

set -euo pipefail

echo "🐙 Deploying Gitea to K3s Homelab"
echo "=================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if kubectl is available and cluster is accessible
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to K3s cluster. Please check your kubeconfig."
    exit 1
fi

print_status "K3s cluster is accessible"

# Check if PostgreSQL is available
if ! kubectl get service postgresql -n postgresql &> /dev/null; then
    print_warning "PostgreSQL service not found in postgresql namespace"
    print_warning "Gitea requires PostgreSQL. Please ensure it's deployed first."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create namespace
echo "📁 Creating Gitea namespace..."
kubectl apply -f ../namespaces/gitea-namespace.yml
print_status "Namespace created/updated"

# Deploy secrets (with warning about placeholder values)
echo "🔐 Deploying secrets..."
print_warning "IMPORTANT: Update secret values in gitea-secret.yml before production use!"
print_warning "Current secrets contain placeholder values that must be replaced."
kubectl apply -f manifests/gitea-secret.yml
print_status "Secrets deployed (remember to update values!)"

# Deploy ConfigMap
echo "⚙️  Deploying configuration..."
kubectl apply -f manifests/gitea-configmap.yml
print_status "ConfigMap deployed"

# Deploy PVC
echo "💾 Creating persistent storage..."
kubectl apply -f manifests/gitea-pvc.yml
print_status "Persistent volumes created"

# Deploy Deployment
echo "🚀 Deploying Gitea application..."
kubectl apply -f manifests/gitea-deployment.yml
print_status "Gitea deployment created"

# Deploy Services
echo "🌐 Creating services..."
kubectl apply -f manifests/gitea-service.yml
print_status "Services created"

# Deploy Ingress
echo "🔗 Setting up ingress..."
kubectl apply -f manifests/gitea-ingress.yml
print_status "Ingress configured"

# Deploy ServiceMonitor (if Prometheus is available)
echo "📊 Setting up monitoring..."
if kubectl get crd servicemonitors.monitoring.coreos.com &> /dev/null; then
    kubectl apply -f manifests/gitea-servicemonitor.yml
    print_status "ServiceMonitor deployed"
else
    print_warning "Prometheus ServiceMonitor CRD not found - skipping monitoring setup"
fi

# Wait for deployment to be ready
echo "⏳ Waiting for Gitea to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/gitea -n gitea
print_status "Gitea deployment is ready!"

# Display access information
echo ""
echo "🎉 Gitea Deployment Complete!"
echo "=============================="
echo ""
echo "Access Information:"
echo "  Web UI: http://gitea.local:3000"
echo "  SSH:    ssh://git@<node-ip>:30022"
echo ""
echo "Next Steps:"
echo "1. Add 'gitea.local' to your /etc/hosts file:"
echo "   sudo echo '<node-ip> gitea.local' >> /etc/hosts"
echo ""
echo "2. Visit http://gitea.local:3000 to complete setup"
echo ""
echo "3. Update secret values in gitea-secret.yml:"
echo "   - Database password"
echo "   - Gitea secret key"
echo "   - Admin credentials"
echo ""
echo "4. Create Gitea database in PostgreSQL:"
echo "   kubectl exec -it -n postgresql <postgres-pod> -- createdb -U postgres gitea"
echo ""
echo "Security Notes:"
echo "- Default secrets contain placeholder values"
echo "- Update all passwords before production use"
echo "- Consider using external secret management"

# Show pod status
echo ""
echo "Current Pod Status:"
kubectl get pods -n gitea

echo ""
echo "Service Status:"
kubectl get services -n gitea