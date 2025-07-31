#!/bin/bash
# Configure ArgoCD to monitor Forgejo Git service instead of GitHub
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/configure-argocd-forgejo-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🔧 Configuring ArgoCD to Monitor Forgejo Git Service"
echo "=================================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

# Check if virtual environment exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

echo "This script configures ArgoCD in your K3s cluster to monitor the"
echo "Forgejo Git service (LXC container) instead of GitHub directly."
echo ""

echo "🎯 GitOps Architecture:"
echo "GitHub → Forgejo (Mirror) → ArgoCD (Monitor) → K3s (Deploy)"
echo ""

echo "1. Check ArgoCD deployment status:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl get pods -n argocd"
echo ""

echo "2. Check current ArgoCD configuration:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl get configmap argocd-cm -n argocd -o yaml | grep -A10 -B5 'url:' || echo 'No repositories configured yet'"
echo ""

echo "3. Create ArgoCD repository configuration for Forgejo:"
cat <<'ARGOCD_REPO' > /tmp/argocd-forgejo-repo.yaml
apiVersion: v1
kind: Secret
metadata:
  name: forgejo-homelab-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: http://192.168.2.200:3000/prgazevedo/homelab-infra.git
  username: prgazevedo
  password: GiteaJourney1
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: homelab-infrastructure
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://192.168.2.200:3000/prgazevedo/homelab-infra.git
    targetRevision: HEAD
    path: k3s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
ARGOCD_REPO

echo "4. Apply ArgoCD repository configuration:"
ansible k3s-master -i ansible/inventory.yml -m copy -a "src=/tmp/argocd-forgejo-repo.yaml dest=/tmp/"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl apply -f /tmp/argocd-forgejo-repo.yaml"
echo ""

echo "5. Wait for ArgoCD to sync:"
sleep 15
echo ""

echo "6. Check ArgoCD applications:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl get applications -n argocd"
echo ""

echo "7. Get ArgoCD admin password:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo ""

echo "8. Check ArgoCD service access:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl get svc -n argocd | grep argocd-server"
echo ""

echo "9. Test Forgejo connectivity from K3s cluster:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "curl -s -o /dev/null -w 'Forgejo HTTP: %{http_code}' http://192.168.2.200:3000/api/v1/version"
echo ""

echo "10. Check ArgoCD repository connection:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl get secrets -n argocd | grep forgejo"
echo ""

echo "✅ ARGOCD FORGEJO INTEGRATION COMPLETED"
echo "======================================="
echo ""
echo "🌐 Access ArgoCD:"
echo "1. Port forward to access ArgoCD UI:"
echo "   kubectl port-forward -n argocd svc/argocd-server 8080:80"
echo ""
echo "2. Access ArgoCD at: http://localhost:8080"
echo "   Username: admin"
echo "   Password: (from step 7 above)"
echo ""
echo "🔧 GitOps Workflow Now Active:"
echo "- GitHub mirrors to Forgejo (LXC container)"
echo "- ArgoCD monitors Forgejo repositories"  
echo "- Applications deployed to K3s automatically"
echo "- Complete separation of Git infrastructure and applications"
echo ""
echo "📋 Verify Setup:"
echo "1. Check ArgoCD UI shows homelab-infrastructure application"
echo "2. Verify repository connection is healthy"
echo "3. Test sync by making a change in your GitHub repo"
echo ""
echo "💡 Benefits:"
echo "- Faster sync (local Git service)"
echo "- More reliable (no external dependencies)"
echo "- Better security (internal network only)"
echo "- Enterprise architecture (Git infrastructure separation)"

# Cleanup
rm -f /tmp/argocd-forgejo-repo.yaml