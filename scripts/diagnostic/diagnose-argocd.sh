#!/bin/bash
# Diagnose ArgoCD installation and accessibility
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/diagnose-argocd-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🔍 Diagnosing ArgoCD Installation and Access"
echo "==========================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

# Check if virtual environment exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

echo "1. Check ArgoCD namespace and pods:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl get pods -n argocd"
echo ""

echo "2. Check ArgoCD services:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl get svc -n argocd"
echo ""

echo "3. Check ArgoCD server deployment status:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl describe deployment argocd-server -n argocd | grep -A10 'Conditions:'"
echo ""

echo "4. Check ArgoCD server pod logs:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=20"
echo ""

echo "5. Check if NodePort is properly configured:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl get svc argocd-server -n argocd -o yaml | grep -A5 -B5 nodePort"
echo ""

echo "6. Test internal access from master node:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "curl -s -o /dev/null -w 'Internal ArgoCD: %{http_code}' http://localhost:30880 || echo 'Internal access failed'"
echo ""

echo "7. Check what's listening on port 30880:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "ss -tlnp | grep :30880 || echo 'Port 30880 not listening'"
echo ""

echo "8. Test from each K3s node:"
echo "From master node:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "curl -s -I http://localhost:30880 | head -3 || echo 'Master node access failed'"

echo "From worker1:"
ansible k3s-worker1 -i ansible/inventory.yml -m shell -a "curl -s -I http://192.168.2.103:30880 | head -3 || echo 'Worker1 access failed'"

echo "From worker2:"
ansible k3s-worker2 -i ansible/inventory.yml -m shell -a "curl -s -I http://192.168.2.103:30880 | head -3 || echo 'Worker2 access failed'"
echo ""

echo "9. Check ArgoCD server service type and ports:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.type}:{.spec.ports[0].nodePort}:{.spec.ports[0].port}:{.spec.ports[0].targetPort}'"
echo ""
echo ""

echo "10. Try to patch ArgoCD service if it's not NodePort:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "
kubectl patch svc argocd-server -n argocd -p '{\"spec\":{\"type\":\"NodePort\",\"ports\":[{\"name\":\"server\",\"port\":80,\"targetPort\":8080,\"nodePort\":30880,\"protocol\":\"TCP\"}]}}'
" || echo "Service patch failed or already configured"
echo ""

echo "11. Wait a moment and test again:"
sleep 10
ansible k3s-master -i ansible/inventory.yml -m shell -a "curl -s -o /dev/null -w 'ArgoCD after patch: %{http_code}' http://localhost:30880 || echo 'Still not accessible'"
echo ""

echo "12. Get ArgoCD admin password:"
ansible k3s-master -i ansible/inventory.yml -m shell -a "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo" || echo "Password secret not available"
echo ""

echo "13. Check K3s cluster external access:"
echo "Testing external access to K3s master..."
ping -c 2 192.168.2.103 || echo "K3s master not reachable from this host"
echo ""

echo "📊 DIAGNOSIS SUMMARY"
echo "==================="
echo ""
echo "🔍 Check the following:"
echo "1. Are all ArgoCD pods running?"
echo "2. Is the argocd-server service type NodePort?"
echo "3. Is port 30880 listening on the K3s master?"
echo "4. Can you access the K3s master from your machine?"
echo ""
echo "🔧 Possible fixes:"
echo "1. If pods are not ready, wait longer (5-10 minutes)"
echo "2. If service is not NodePort, the patch above should fix it"
echo "3. If port is not listening, restart the argocd-server deployment"
echo "4. If network is blocked, check firewall settings"
echo ""
echo "🌐 Access URLs to try:"
echo "- http://192.168.2.103:30880 (from your browser)"
echo "- kubectl port-forward -n argocd svc/argocd-server 8080:80 (then http://localhost:8080)"