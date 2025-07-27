#!/bin/bash
# K3s Cluster Management Script
# Provides comprehensive K3s cluster health monitoring and management

set -euo pipefail

echo "☸️  K3s Cluster Management"
echo "========================="

# Configuration
K3S_MASTER="192.168.2.103"
K3S_WORKER1="192.168.2.104"
K3S_WORKER2="192.168.2.105"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl to manage the K3s cluster."
    exit 1
fi

# Function to check node connectivity
check_node_connectivity() {
    local node=$1
    local name=$2
    
    if ping -c 1 -W 2 "$node" &> /dev/null; then
        echo "✅ $name ($node) - Network reachable"
        return 0
    else
        echo "❌ $name ($node) - Network unreachable"
        return 1
    fi
}

# Function to get K3s service status on a node
check_k3s_service() {
    local node=$1
    local name=$2
    local service=$3
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$node" "systemctl is-active $service" &> /dev/null; then
        status=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$node" "systemctl is-active $service" 2>/dev/null || echo "unknown")
        uptime=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$node" "systemctl show $service --property=ActiveEnterTimestamp --value" 2>/dev/null | cut -d' ' -f1-2 || echo "unknown")
        echo "✅ $name: $service is $status (since $uptime)"
    else
        echo "❌ $name: $service status unknown (SSH failed)"
    fi
}

echo "🔍 Checking K3s Cluster Health..."
echo

# Check network connectivity to all nodes
echo "📡 Network Connectivity:"
check_node_connectivity "$K3S_MASTER" "k3s-master"
check_node_connectivity "$K3S_WORKER1" "k3s-worker1"
check_node_connectivity "$K3S_WORKER2" "k3s-worker2"
echo

# Check K3s services on each node
echo "🔧 K3s Service Status:"
check_k3s_service "$K3S_MASTER" "k3s-master" "k3s"
check_k3s_service "$K3S_WORKER1" "k3s-worker1" "k3s-agent"
check_k3s_service "$K3S_WORKER2" "k3s-worker2" "k3s-agent"
echo

# Check kubectl connectivity and cluster info
echo "☸️  Cluster Information:"
if kubectl cluster-info &> /dev/null; then
    echo "✅ kubectl connectivity successful"
    
    # Get cluster info
    echo
    echo "📊 Cluster Details:"
    kubectl cluster-info | head -3
    
    echo
    echo "🖥️  Node Status:"
    kubectl get nodes -o wide 2>/dev/null || echo "❌ Failed to get node information"
    
    echo
    echo "📦 System Pods Status:"
    kubectl get pods -n kube-system --no-headers 2>/dev/null | while read -r line; do
        pod_name=$(echo "$line" | awk '{print $1}')
        pod_status=$(echo "$line" | awk '{print $3}')
        if [[ "$pod_status" == "Running" ]]; then
            echo "✅ $pod_name: $pod_status"
        else
            echo "⚠️  $pod_name: $pod_status"
        fi
    done
    
    echo
    echo "🔍 Resource Usage:"
    kubectl top nodes 2>/dev/null || echo "⚠️  Metrics server not available for resource usage"
    
    echo
    echo "📈 Application Namespaces:"
    kubectl get namespaces --no-headers 2>/dev/null | grep -v "kube-\|default" | while read -r line; do
        ns_name=$(echo "$line" | awk '{print $1}')
        pod_count=$(kubectl get pods -n "$ns_name" --no-headers 2>/dev/null | wc -l | xargs)
        echo "📦 $ns_name: $pod_count pods"
    done
    
else
    echo "❌ kubectl connectivity failed"
    echo "   Check if:"
    echo "   - K3s master (192.168.2.103) is running"
    echo "   - kubectl is configured with the correct kubeconfig"
    echo "   - Network connectivity to the cluster"
fi

echo
echo "🔧 Management Commands:"
echo "  kubectl get nodes                    # Check all nodes"
echo "  kubectl get pods --all-namespaces  # Check all pods"
echo "  kubectl describe node <node-name>  # Detailed node info"
echo "  kubectl logs -n kube-system <pod>  # Check system pod logs"
echo
echo "💡 For VM management of K3s nodes, use:"
echo "  ./homelab-unified.sh start 103 qemu   # Start k3s-master"
echo "  ./homelab-unified.sh start 104 qemu   # Start k3s-worker1"
echo "  ./homelab-unified.sh start 105 qemu   # Start k3s-worker2"

echo
echo "✅ K3s cluster check completed!"