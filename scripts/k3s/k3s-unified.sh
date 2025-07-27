#!/bin/bash
# K3s Unified Management Script - Comprehensive K3s cluster operations
# Companion to homelab-unified.sh for Kubernetes-specific tasks

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}🎯 $1${NC}"
    echo "$(printf '=%.0s' {1..50})"
}

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Check prerequisites and connection mode
check_prerequisites() {
    local mode="${K3S_MODE:-auto}"
    
    # Check for basic tools
    if ! command -v helm &> /dev/null; then
        print_warning "helm not found - some features will be limited"
    fi
    
    # Determine connection mode
    if [ "$mode" = "remote" ] || [ "$mode" = "auto" ]; then
        # Check for Ansible (remote mode)
        if command -v ansible-playbook &> /dev/null || [ -f "venv/bin/ansible-playbook" ]; then
            CONNECTION_MODE="remote"
            print_info "Using remote mode (Ansible via Proxmox)"
            return 0
        elif [ "$mode" = "remote" ]; then
            print_error "Remote mode requested but Ansible not available"
            exit 1
        fi
    fi
    
    # Check for kubectl (local mode)
    if [ "$mode" = "local" ] || [ "$mode" = "auto" ]; then
        if command -v kubectl &> /dev/null; then
            # Test cluster connectivity
            if kubectl cluster-info &> /dev/null; then
                CONNECTION_MODE="local"
                print_info "Using local mode (kubectl direct)"
                return 0
            elif [ "$mode" = "local" ]; then
                print_error "Local mode requested but kubectl cannot connect"
                print_info "Try: ./k3s-tunnel.sh start"
                exit 1
            fi
        elif [ "$mode" = "local" ]; then
            print_error "Local mode requested but kubectl not available"
            exit 1
        fi
    fi
    
    # Auto mode - no connection available
    if [ "$mode" = "auto" ]; then
        print_error "Cannot establish connection to K3s cluster"
        print_info "Options:"
        print_info "1. Setup SSH tunnel: ./k3s-tunnel.sh start"
        print_info "2. Use remote mode: K3S_MODE=remote ./k3s-unified.sh <command>"
        print_info "3. Install kubectl and setup kubeconfig"
        exit 1
    fi
}

# Show usage information
show_usage() {
    echo -e "${BLUE}🏠 K3s Unified Management${NC}"
    echo "=========================="
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "CLUSTER OPERATIONS:"
    echo "  status                    - Show comprehensive cluster status"
    echo "  discover                  - Run cluster discovery (Ansible)"
    echo "  nodes                     - Show detailed node information"
    echo "  resources                 - Show resource usage across cluster"
    echo ""
    echo "APPLICATION MANAGEMENT:"
    echo "  apps                      - List all applications across namespaces"
    echo "  deploy <app>             - Deploy application (gitea, monitoring, etc.)"
    echo "  logs <namespace> [pod]   - Show logs for namespace or specific pod"
    echo "  describe <namespace> <resource> <name> - Describe resource"
    echo ""
    echo "STORAGE OPERATIONS:"
    echo "  storage                   - Show storage information (PVs, PVCs)"
    echo "  backup <namespace>       - Backup application data"
    echo ""
    echo "NETWORKING:"
    echo "  network                   - Show networking information"
    echo "  port-forward <namespace> <service> <local-port>:<remote-port>"
    echo ""
    echo "MONITORING:"
    echo "  metrics                   - Show cluster metrics (if available)"
    echo "  events                    - Show recent cluster events"
    echo "  health                    - Comprehensive health check"
    echo ""
    echo "GITOPS:"
    echo "  argocd                    - ArgoCD operations"
    echo "  sync <app>               - Sync ArgoCD application"
    echo ""
    echo "UTILITIES:"
    echo "  shell <namespace> <pod>  - Open shell in pod"
    echo "  exec <namespace> <pod> <command> - Execute command in pod"
    echo "  clean                     - Clean up completed/failed pods"
    echo ""
    echo "Examples:"
    echo "  $0 status                 # Show cluster overview"
    echo "  $0 deploy gitea          # Deploy Gitea application"
    echo "  $0 logs gitea            # Show Gitea logs"
    echo "  $0 port-forward gitea gitea-http 3000:3000"
    echo "  $0 backup gitea          # Backup Gitea data"
    echo ""
    echo "CONNECTION MODES:"
    echo "  K3S_MODE=local           - Use kubectl directly (requires tunnel)"
    echo "  K3S_MODE=remote          - Use Ansible remote execution"
    echo "  K3S_MODE=auto            - Auto-detect best method (default)"
    echo ""
    echo "TUNNEL MANAGEMENT:"
    echo "  ./k3s-tunnel.sh start    - Setup SSH tunnel for local mode"
    echo "  ./k3s-tunnel.sh stop     - Stop SSH tunnel"
    echo "  ./k3s-tunnel.sh status   - Check tunnel status"
    echo ""
}

# Execute Ansible playbook for remote operations
execute_remote() {
    local operation="$1"
    local namespace="${2:-}"
    local app="${3:-}"
    
    print_info "Executing remote operation: $operation"
    
    # Ensure virtual environment
    if [ ! -d "venv" ]; then
        print_error "Python virtual environment not found. Run from project root."
        exit 1
    fi
    
    # Activate venv and run Ansible
    source venv/bin/activate
    
    # Build extra vars
    local extra_vars="k3s_operation=$operation"
    if [ -n "$namespace" ]; then
        extra_vars="$extra_vars k3s_namespace=$namespace"
    fi
    if [ -n "$app" ]; then
        extra_vars="$extra_vars k3s_app=$app"
    fi
    
    # Run the remote operations playbook
    if [ -f "ansible/playbooks/k3s-remote-operations.yml" ]; then
        ansible-playbook ansible/playbooks/k3s-remote-operations.yml \
            -i ansible/inventory.yml \
            -e "$extra_vars"
        
        # Display results if available
        if [ -f "k3s-remote-results.yml" ]; then
            print_status "Remote operation completed. Results saved to k3s-remote-results.yml"
        fi
    else
        print_error "Remote operations playbook not found"
        exit 1
    fi
}

# Wrapper functions for different connection modes
k3s_get_nodes() {
    if [ "$CONNECTION_MODE" = "remote" ]; then
        execute_remote "nodes"
    else
        kubectl get nodes -o wide
    fi
}

k3s_get_pods() {
    local namespace="${1:-}"
    if [ "$CONNECTION_MODE" = "remote" ]; then
        execute_remote "pods" "$namespace"
    else
        if [ -n "$namespace" ]; then
            kubectl get pods -n "$namespace"
        else
            kubectl get pods --all-namespaces
        fi
    fi
}

k3s_get_services() {
    if [ "$CONNECTION_MODE" = "remote" ]; then
        execute_remote "services"
    else
        kubectl get services --all-namespaces
    fi
}

k3s_get_events() {
    if [ "$CONNECTION_MODE" = "remote" ]; then
        execute_remote "events"
    else
        kubectl get events --all-namespaces --sort-by='.lastTimestamp'
    fi
}

k3s_cluster_info() {
    if [ "$CONNECTION_MODE" = "remote" ]; then
        execute_remote "cluster-info"
    else
        kubectl cluster-info
    fi
}

# Show cluster status
show_status() {
    print_header "K3s Cluster Status (Mode: $CONNECTION_MODE)"
    
    # Cluster info
    echo -e "${CYAN}Cluster Information:${NC}"
    k3s_cluster_info
    echo ""
    
    # Node status
    echo -e "${CYAN}Node Status:${NC}"
    k3s_get_nodes
    echo ""
    
    if [ "$CONNECTION_MODE" = "local" ]; then
        # Namespace summary (local mode only for now)
        echo -e "${CYAN}Namespaces:${NC}"
        kubectl get namespaces
        echo ""
        
        # Resource summary
        echo -e "${CYAN}Resource Summary:${NC}"
        echo "Deployments: $(kubectl get deployments --all-namespaces --no-headers | wc -l)"
        echo "Services: $(kubectl get services --all-namespaces --no-headers | grep -v kubernetes | wc -l)"
        echo "Pods (Running): $(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers | wc -l)"
        echo "Pods (Total): $(kubectl get pods --all-namespaces --no-headers | wc -l)"
        echo "PVCs: $(kubectl get pvc --all-namespaces --no-headers | wc -l)"
        echo ""
        
        # Recent events (last 10)
        echo -e "${CYAN}Recent Events:${NC}"
        kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -10
    else
        # Remote mode - use comprehensive remote status
        print_info "Getting comprehensive cluster status via Ansible..."
        execute_remote "status"
    fi
}

# Run Ansible discovery
run_discovery() {
    print_header "K3s Cluster Discovery (Ansible)"
    
    # Check if virtual environment exists
    if [ ! -d "venv" ]; then
        print_error "Python virtual environment not found. Run from project root."
        exit 1
    fi
    
    # Activate venv and run discovery
    print_info "Activating virtual environment and running discovery..."
    source venv/bin/activate
    
    if [ -f "ansible/playbooks/k3s-cluster-discovery.yml" ]; then
        ansible-playbook ansible/playbooks/k3s-cluster-discovery.yml -i ansible/inventory.yml
        
        if [ -f "k3s-cluster-state.yml" ]; then
            print_status "Discovery complete! Results saved to k3s-cluster-state.yml"
            print_info "View results: cat k3s-cluster-state.yml"
        fi
    else
        print_error "Discovery playbook not found: ansible/playbooks/k3s-cluster-discovery.yml"
        exit 1
    fi
}

# Show detailed node information
show_nodes() {
    print_header "Node Information"
    
    kubectl get nodes -o wide
    echo ""
    
    echo -e "${CYAN}Node Resource Usage:${NC}"
    if command -v kubectl &> /dev/null && kubectl top nodes &> /dev/null; then
        kubectl top nodes
    else
        print_warning "Metrics server not available - cannot show resource usage"
    fi
    
    echo ""
    echo -e "${CYAN}Node Details:${NC}"
    for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        echo "Node: $node"
        kubectl describe node "$node" | grep -E "(Capacity|Allocatable|Allocated resources)" -A 5
        echo "---"
    done
}

# Show resource usage
show_resources() {
    print_header "Cluster Resource Usage"
    
    if kubectl top nodes &> /dev/null; then
        echo -e "${CYAN}Node Resource Usage:${NC}"
        kubectl top nodes
        echo ""
        
        echo -e "${CYAN}Pod Resource Usage (Top 10):${NC}"
        kubectl top pods --all-namespaces | head -11
    else
        print_warning "Metrics server not available"
    fi
    
    echo ""
    echo -e "${CYAN}Resource Quotas:${NC}"
    kubectl get resourcequotas --all-namespaces
    
    echo ""
    echo -e "${CYAN}Limit Ranges:${NC}"
    kubectl get limitranges --all-namespaces
}

# List all applications
list_apps() {
    print_header "Applications Across All Namespaces"
    
    echo -e "${CYAN}Deployments:${NC}"
    kubectl get deployments --all-namespaces
    echo ""
    
    echo -e "${CYAN}Services:${NC}"
    kubectl get services --all-namespaces
    echo ""
    
    echo -e "${CYAN}Ingresses:${NC}"
    kubectl get ingress --all-namespaces
    echo ""
    
    if command -v helm &> /dev/null; then
        echo -e "${CYAN}Helm Releases:${NC}"
        helm list --all-namespaces
        echo ""
    fi
    
    # Check for ArgoCD applications
    if kubectl get namespace argocd &> /dev/null; then
        echo -e "${CYAN}ArgoCD Applications:${NC}"
        kubectl get applications -n argocd 2>/dev/null || print_warning "ArgoCD CRDs not found"
        echo ""
    fi
}

# Deploy application
deploy_app() {
    local app="$1"
    
    case "$app" in
        "gitea")
            print_header "Deploying Gitea"
            if [ -f "k3s/gitea/deploy-gitea.sh" ]; then
                cd k3s/gitea
                ./deploy-gitea.sh
            else
                print_error "Gitea deployment script not found: k3s/gitea/deploy-gitea.sh"
                exit 1
            fi
            ;;
        *)
            print_error "Unknown application: $app"
            print_info "Available applications: gitea"
            exit 1
            ;;
    esac
}

# Show logs
show_logs() {
    local namespace="$1"
    local pod="${2:-}"
    
    if [ -z "$pod" ]; then
        print_header "Logs for namespace: $namespace"
        kubectl logs -n "$namespace" --all-containers=true --tail=100 -l app.kubernetes.io/name
    else
        print_header "Logs for pod: $namespace/$pod"
        kubectl logs -n "$namespace" "$pod" --all-containers=true --tail=100
    fi
}

# Show storage information
show_storage() {
    print_header "Storage Information"
    
    echo -e "${CYAN}Persistent Volumes:${NC}"
    kubectl get pv
    echo ""
    
    echo -e "${CYAN}Persistent Volume Claims:${NC}"
    kubectl get pvc --all-namespaces
    echo ""
    
    echo -e "${CYAN}Storage Classes:${NC}"
    kubectl get storageclass
    echo ""
    
    # Show storage usage for each PVC
    echo -e "${CYAN}Storage Usage:${NC}"
    for namespace in $(kubectl get pvc --all-namespaces -o jsonpath='{.items[*].metadata.namespace}' | tr ' ' '\n' | sort -u); do
        echo "Namespace: $namespace"
        kubectl get pvc -n "$namespace" -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName
        echo ""
    done
}

# Show network information
show_network() {
    print_header "Network Information"
    
    echo -e "${CYAN}Services:${NC}"
    kubectl get services --all-namespaces -o wide
    echo ""
    
    echo -e "${CYAN}Ingresses:${NC}"
    kubectl get ingress --all-namespaces
    echo ""
    
    echo -e "${CYAN}Network Policies:${NC}"
    kubectl get networkpolicies --all-namespaces
    echo ""
    
    echo -e "${CYAN}Endpoints:${NC}"
    kubectl get endpoints --all-namespaces
}

# Port forward
port_forward() {
    local namespace="$1"
    local service="$2"
    local ports="$3"
    
    print_header "Port Forward: $namespace/$service -> $ports"
    print_info "Access via: http://localhost:${ports%:*}"
    print_info "Press Ctrl+C to stop"
    
    kubectl port-forward -n "$namespace" "svc/$service" "$ports"
}

# Show metrics
show_metrics() {
    print_header "Cluster Metrics"
    
    if kubectl top nodes &> /dev/null; then
        echo -e "${CYAN}Node Metrics:${NC}"
        kubectl top nodes
        echo ""
        
        echo -e "${CYAN}Pod Metrics (All Namespaces):${NC}"
        kubectl top pods --all-namespaces
    else
        print_warning "Metrics server not available"
    fi
    
    # Check if Prometheus is available
    if kubectl get service prometheus -n monitoring &> /dev/null; then
        echo ""
        print_info "Prometheus available at: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
    fi
    
    if kubectl get service grafana -n monitoring &> /dev/null; then
        print_info "Grafana available at: kubectl port-forward -n monitoring svc/grafana 3000:3000"
    fi
}

# Show events
show_events() {
    print_header "Recent Cluster Events"
    
    kubectl get events --all-namespaces --sort-by='.lastTimestamp'
}

# Health check
health_check() {
    print_header "Cluster Health Check"
    
    # Check nodes
    echo -e "${CYAN}Node Health:${NC}"
    local unhealthy_nodes=$(kubectl get nodes --no-headers | grep -v Ready | wc -l)
    if [ "$unhealthy_nodes" -eq 0 ]; then
        print_status "All nodes are Ready"
    else
        print_warning "$unhealthy_nodes nodes are not Ready"
        kubectl get nodes
    fi
    echo ""
    
    # Check system pods
    echo -e "${CYAN}System Pods Health:${NC}"
    local failed_pods=$(kubectl get pods -n kube-system --no-headers | grep -v Running | grep -v Completed | wc -l)
    if [ "$failed_pods" -eq 0 ]; then
        print_status "All system pods are healthy"
    else
        print_warning "$failed_pods system pods are not Running"
        kubectl get pods -n kube-system | grep -v Running | grep -v Completed
    fi
    echo ""
    
    # Check application pods
    echo -e "${CYAN}Application Pods Health:${NC}"
    kubectl get pods --all-namespaces | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|Pending)" || print_status "All application pods are healthy"
    echo ""
    
    # Check storage
    echo -e "${CYAN}Storage Health:${NC}"
    local failed_pvcs=$(kubectl get pvc --all-namespaces --no-headers | grep -v Bound | wc -l)
    if [ "$failed_pvcs" -eq 0 ]; then
        print_status "All PVCs are Bound"
    else
        print_warning "$failed_pvcs PVCs are not Bound"
        kubectl get pvc --all-namespaces | grep -v Bound
    fi
}

# ArgoCD operations
argocd_ops() {
    print_header "ArgoCD Operations"
    
    if ! kubectl get namespace argocd &> /dev/null; then
        print_error "ArgoCD namespace not found"
        exit 1
    fi
    
    echo -e "${CYAN}ArgoCD Applications:${NC}"
    kubectl get applications -n argocd
    echo ""
    
    echo -e "${CYAN}ArgoCD Server Status:${NC}"
    kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
    echo ""
    
    print_info "Access ArgoCD UI: kubectl port-forward -n argocd svc/argocd-server 8080:80"
    print_info "Get admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

# Backup application data
backup_app() {
    local namespace="$1"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    print_header "Backing up namespace: $namespace"
    
    # Create backup directory
    mkdir -p "backups/$namespace"
    
    # Backup manifests
    echo -e "${CYAN}Backing up manifests...${NC}"
    kubectl get all -n "$namespace" -o yaml > "backups/$namespace/manifests-$timestamp.yml"
    kubectl get secrets -n "$namespace" -o yaml > "backups/$namespace/secrets-$timestamp.yml"
    kubectl get configmaps -n "$namespace" -o yaml > "backups/$namespace/configmaps-$timestamp.yml"
    kubectl get pvc -n "$namespace" -o yaml > "backups/$namespace/pvc-$timestamp.yml"
    
    # Application-specific backups
    case "$namespace" in
        "gitea")
            echo -e "${CYAN}Backing up Gitea data...${NC}"
            kubectl exec -n gitea -it deployment/gitea -- tar -czf /tmp/gitea-backup-$timestamp.tar.gz /data
            kubectl cp "gitea/$(kubectl get pods -n gitea -l app.kubernetes.io/name=gitea -o jsonpath='{.items[0].metadata.name}'):/tmp/gitea-backup-$timestamp.tar.gz" "backups/gitea/data-$timestamp.tar.gz"
            ;;
    esac
    
    print_status "Backup completed: backups/$namespace/"
}

# Clean up completed/failed pods
cleanup() {
    print_header "Cleaning up completed and failed pods"
    
    echo -e "${CYAN}Completed pods:${NC}"
    kubectl get pods --all-namespaces --field-selector=status.phase=Succeeded
    kubectl delete pods --all-namespaces --field-selector=status.phase=Succeeded
    
    echo ""
    echo -e "${CYAN}Failed pods:${NC}"
    kubectl get pods --all-namespaces --field-selector=status.phase=Failed
    kubectl delete pods --all-namespaces --field-selector=status.phase=Failed
    
    print_status "Cleanup completed"
}

# Open shell in pod
open_shell() {
    local namespace="$1"
    local pod="$2"
    
    print_header "Opening shell in $namespace/$pod"
    kubectl exec -n "$namespace" -it "$pod" -- /bin/bash
}

# Execute command in pod
exec_command() {
    local namespace="$1"
    local pod="$2"
    shift 2
    local command="$*"
    
    print_header "Executing in $namespace/$pod: $command"
    kubectl exec -n "$namespace" -it "$pod" -- $command
}

# Main script logic
main() {
    print_header "K3s Unified Management"
    
    # Check prerequisites
    check_prerequisites
    
    # Handle no arguments
    if [ $# -eq 0 ]; then
        show_status
        exit 0
    fi
    
    # Parse command
    local command="$1"
    shift
    
    case "$command" in
        "help"|"-h"|"--help")
            show_usage
            ;;
        "status")
            show_status
            ;;
        "discover")
            run_discovery
            ;;
        "nodes")
            show_nodes
            ;;
        "resources")
            show_resources
            ;;
        "apps")
            list_apps
            ;;
        "deploy")
            if [ $# -eq 0 ]; then
                print_error "Application name required"
                exit 1
            fi
            deploy_app "$1"
            ;;
        "logs")
            if [ $# -eq 0 ]; then
                print_error "Namespace required"
                exit 1
            fi
            show_logs "$@"
            ;;
        "storage")
            show_storage
            ;;
        "network")
            show_network
            ;;
        "port-forward")
            if [ $# -lt 3 ]; then
                print_error "Usage: $0 port-forward <namespace> <service> <local-port>:<remote-port>"
                exit 1
            fi
            port_forward "$1" "$2" "$3"
            ;;
        "metrics")
            show_metrics
            ;;
        "events")
            show_events
            ;;
        "health")
            health_check
            ;;
        "argocd")
            argocd_ops
            ;;
        "backup")
            if [ $# -eq 0 ]; then
                print_error "Namespace required"
                exit 1
            fi
            backup_app "$1"
            ;;
        "clean")
            cleanup
            ;;
        "shell")
            if [ $# -lt 2 ]; then
                print_error "Usage: $0 shell <namespace> <pod>"
                exit 1
            fi
            open_shell "$1" "$2"
            ;;
        "exec")
            if [ $# -lt 3 ]; then
                print_error "Usage: $0 exec <namespace> <pod> <command>"
                exit 1
            fi
            exec_command "$@"
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"