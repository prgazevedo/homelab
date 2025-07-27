#!/bin/bash
# K3s Network Diagnostic Tool
# Comprehensive connectivity testing for K3s cluster access

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROXMOX_HOST="192.168.2.100"
PROXMOX_USER="root"
K3S_MASTER_IP="192.168.2.103"
K3S_WORKER1_IP="192.168.2.104"
K3S_WORKER2_IP="192.168.2.105"
K3S_MASTER_USER="ubuntu"
K3S_API_PORT="6443"

# Function to print colored output
print_header() {
    echo -e "${BLUE}🔍 $1${NC}"
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

print_test() {
    echo -e "${CYAN}🧪 Testing: $1${NC}"
}

# Test basic network connectivity
test_network_connectivity() {
    print_header "Network Connectivity Tests"
    
    # Test Proxmox host
    print_test "Proxmox host connectivity"
    if ping -c 2 -W 3 "$PROXMOX_HOST" >/dev/null 2>&1; then
        print_status "Proxmox host ($PROXMOX_HOST) is reachable"
    else
        print_error "Proxmox host ($PROXMOX_HOST) is unreachable"
        return 1
    fi
    
    # Test Proxmox SSH port
    print_test "Proxmox SSH port"
    if nc -z -w 3 "$PROXMOX_HOST" 22 2>/dev/null; then
        print_status "Proxmox SSH port 22 is open"
    else
        print_error "Proxmox SSH port 22 is closed or filtered"
    fi
    
    # Test Proxmox web interface
    print_test "Proxmox web interface"
    if nc -z -w 3 "$PROXMOX_HOST" 8006 2>/dev/null; then
        print_status "Proxmox web interface port 8006 is open"
    else
        print_warning "Proxmox web interface port 8006 is not accessible"
    fi
    
    echo ""
}

# Test SSH connectivity
test_ssh_connectivity() {
    print_header "SSH Connectivity Tests"
    
    # Test Proxmox SSH
    print_test "Proxmox SSH authentication"
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
        print_status "Proxmox SSH authentication successful"
        
        # Test K3s nodes through Proxmox
        for node_ip in "$K3S_MASTER_IP" "$K3S_WORKER1_IP" "$K3S_WORKER2_IP"; do
            local node_name=""
            case "$node_ip" in
                "$K3S_MASTER_IP") node_name="K3s Master" ;;
                "$K3S_WORKER1_IP") node_name="K3s Worker1" ;;
                "$K3S_WORKER2_IP") node_name="K3s Worker2" ;;
            esac
            
            print_test "$node_name SSH via Proxmox jump"
            if ssh -o ConnectTimeout=5 -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" "$K3S_MASTER_USER@$node_ip" exit 2>/dev/null; then
                print_status "$node_name SSH successful"
            else
                print_error "$node_name SSH failed"
            fi
        done
    else
        print_error "Proxmox SSH authentication failed"
        print_info "Ensure SSH key authentication is configured:"
        print_info "ssh-copy-id $PROXMOX_USER@$PROXMOX_HOST"
    fi
    
    echo ""
}

# Test K3s service status
test_k3s_services() {
    print_header "K3s Service Status Tests"
    
    print_test "K3s master service status"
    if ssh -o ConnectTimeout=5 -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" "$K3S_MASTER_USER@$K3S_MASTER_IP" "sudo systemctl is-active k3s" 2>/dev/null | grep -q "active"; then
        print_status "K3s service is running on master"
        
        # Test K3s API port
        print_test "K3s API server port"
        if ssh -o ConnectTimeout=5 -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" "$K3S_MASTER_USER@$K3S_MASTER_IP" "nc -z localhost $K3S_API_PORT" 2>/dev/null; then
            print_status "K3s API server is listening on port $K3S_API_PORT"
        else
            print_error "K3s API server is not accessible on port $K3S_API_PORT"
        fi
        
        # Test kubectl access on master
        print_test "kubectl access on master"
        if ssh -o ConnectTimeout=5 -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" "$K3S_MASTER_USER@$K3S_MASTER_IP" "sudo k3s kubectl get nodes" >/dev/null 2>&1; then
            print_status "kubectl works on K3s master"
        else
            print_error "kubectl failed on K3s master"
        fi
    else
        print_error "K3s service is not running on master"
        print_info "Start K3s service: sudo systemctl start k3s"
    fi
    
    # Test worker nodes
    for worker_ip in "$K3S_WORKER1_IP" "$K3S_WORKER2_IP"; do
        local worker_name=""
        case "$worker_ip" in
            "$K3S_WORKER1_IP") worker_name="Worker1" ;;
            "$K3S_WORKER2_IP") worker_name="Worker2" ;;
        esac
        
        print_test "K3s agent service on $worker_name"
        if ssh -o ConnectTimeout=5 -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" "$K3S_MASTER_USER@$worker_ip" "sudo systemctl is-active k3s-agent" 2>/dev/null | grep -q "active"; then
            print_status "K3s agent is running on $worker_name"
        else
            print_error "K3s agent is not running on $worker_name"
        fi
    done
    
    echo ""
}

# Test local kubectl setup
test_local_kubectl() {
    print_header "Local kubectl Setup Tests"
    
    # Check if kubectl is installed
    print_test "kubectl installation"
    if command -v kubectl >/dev/null 2>&1; then
        print_status "kubectl is installed"
        kubectl version --client --short 2>/dev/null || true
    else
        print_error "kubectl is not installed"
        print_info "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
        return 1
    fi
    
    # Check kubeconfig
    print_test "kubeconfig file"
    if [ -f "$HOME/.kube/config" ]; then
        print_status "kubeconfig exists at $HOME/.kube/config"
        
        # Check kubeconfig content
        if grep -q "127.0.0.1" "$HOME/.kube/config" 2>/dev/null; then
            print_info "kubeconfig points to localhost (tunnel expected)"
        elif grep -q "$K3S_MASTER_IP" "$HOME/.kube/config" 2>/dev/null; then
            print_info "kubeconfig points to K3s master IP"
        else
            print_warning "kubeconfig server endpoint unclear"
        fi
    else
        print_error "kubeconfig not found at $HOME/.kube/config"
        print_info "Setup kubeconfig with: ./k3s-tunnel.sh start"
    fi
    
    # Test kubectl connectivity
    print_test "kubectl cluster connectivity"
    if kubectl cluster-info >/dev/null 2>&1; then
        print_status "kubectl can connect to cluster"
        kubectl get nodes 2>/dev/null || true
    else
        print_error "kubectl cannot connect to cluster"
        print_info "Check if SSH tunnel is running: ./k3s-tunnel.sh status"
    fi
    
    echo ""
}

# Test SSH tunnel
test_ssh_tunnel() {
    print_header "SSH Tunnel Tests"
    
    # Check if tunnel process is running
    print_test "SSH tunnel process"
    if lsof -Pi :6443 -sTCP:LISTEN -t >/dev/null 2>&1; then
        local tunnel_pid=$(lsof -ti :6443)
        print_status "SSH tunnel is running (PID: $tunnel_pid)"
        
        # Test local tunnel endpoint
        print_test "Local tunnel endpoint"
        if nc -z 127.0.0.1 6443 2>/dev/null; then
            print_status "Local tunnel endpoint is accessible"
        else
            print_error "Local tunnel endpoint is not accessible"
        fi
        
        # Test tunnel connectivity
        print_test "Tunnel API connectivity"
        if curl -k -s --connect-timeout 5 https://127.0.0.1:6443/version >/dev/null 2>&1; then
            print_status "K3s API accessible through tunnel"
        else
            print_warning "K3s API not accessible through tunnel"
        fi
    else
        print_warning "No SSH tunnel detected on port 6443"
        print_info "Start tunnel with: ./k3s-tunnel.sh start"
    fi
    
    echo ""
}

# Test Ansible setup
test_ansible_setup() {
    print_header "Ansible Setup Tests"
    
    # Check if virtual environment exists
    print_test "Python virtual environment"
    if [ -d "venv" ]; then
        print_status "Virtual environment exists"
        
        # Check if Ansible is available
        print_test "Ansible availability"
        source venv/bin/activate
        if command -v ansible-playbook >/dev/null 2>&1; then
            print_status "Ansible is available in venv"
            ansible --version | head -1
        else
            print_error "Ansible not found in virtual environment"
        fi
    else
        print_error "Virtual environment not found"
        print_info "Run from project root directory"
    fi
    
    # Check inventory file
    print_test "Ansible inventory"
    if [ -f "ansible/inventory.yml" ]; then
        print_status "Ansible inventory exists"
        
        # Check if K3s hosts are defined
        if grep -q "k3s_cluster" ansible/inventory.yml; then
            print_status "K3s cluster defined in inventory"
        else
            print_warning "K3s cluster not found in inventory"
        fi
    else
        print_error "Ansible inventory not found"
    fi
    
    # Test Ansible connectivity
    print_test "Ansible K3s connectivity"
    if [ -d "venv" ] && [ -f "ansible/inventory.yml" ]; then
        source venv/bin/activate
        if ansible k3s_masters -i ansible/inventory.yml -m ping 2>/dev/null | grep -q "SUCCESS"; then
            print_status "Ansible can connect to K3s master"
        else
            print_error "Ansible cannot connect to K3s master"
            print_info "Check SSH key authentication"
        fi
    fi
    
    echo ""
}

# Generate diagnostic report
generate_report() {
    local report_file="k3s-diagnostic-report-$(date +%Y%m%d_%H%M%S).txt"
    
    print_header "Generating Diagnostic Report"
    
    {
        echo "K3s Cluster Diagnostic Report"
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo "User: $(whoami)"
        echo "=========================="
        echo ""
        
        echo "NETWORK CONFIGURATION:"
        echo "Proxmox Host: $PROXMOX_HOST"
        echo "K3s Master: $K3S_MASTER_IP"
        echo "K3s Worker1: $K3S_WORKER1_IP"
        echo "K3s Worker2: $K3S_WORKER2_IP"
        echo ""
        
        echo "SYSTEM INFORMATION:"
        uname -a
        echo ""
        
        echo "NETWORK INTERFACES:"
        ifconfig | grep -E "(inet|flags)" || ip addr show | grep -E "(inet|flags)"
        echo ""
        
        echo "ROUTING TABLE:"
        netstat -rn || ip route show
        echo ""
        
        echo "DNS CONFIGURATION:"
        cat /etc/resolv.conf 2>/dev/null || echo "Cannot read /etc/resolv.conf"
        echo ""
        
        echo "SSH CLIENT CONFIG:"
        ls -la ~/.ssh/
        echo ""
        
        echo "KUBECTL VERSION:"
        kubectl version --client 2>/dev/null || echo "kubectl not available"
        echo ""
        
        echo "KUBECONFIG STATUS:"
        if [ -f "$HOME/.kube/config" ]; then
            echo "File exists: $HOME/.kube/config"
            echo "Size: $(wc -c < "$HOME/.kube/config") bytes"
            echo "Modified: $(stat -f %Sm "$HOME/.kube/config" 2>/dev/null || stat -c %y "$HOME/.kube/config" 2>/dev/null)"
        else
            echo "No kubeconfig found"
        fi
        echo ""
        
        echo "PROCESS INFORMATION:"
        ps aux | grep -E "(ssh|kubectl|k3s)" | grep -v grep || echo "No relevant processes found"
        echo ""
        
        echo "PORT USAGE:"
        lsof -i :6443 2>/dev/null || netstat -tlnp | grep 6443 || echo "Port 6443 not in use"
        echo ""
    } > "$report_file"
    
    print_status "Diagnostic report saved: $report_file"
    echo ""
}

# Show usage
show_usage() {
    echo -e "${BLUE}🔍 K3s Network Diagnostic Tool${NC}"
    echo "================================="
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "COMMANDS:"
    echo "  all                       - Run all diagnostic tests"
    echo "  network                   - Test basic network connectivity"
    echo "  ssh                       - Test SSH connectivity"
    echo "  k3s                       - Test K3s service status"
    echo "  kubectl                   - Test local kubectl setup"
    echo "  tunnel                    - Test SSH tunnel status"
    echo "  ansible                   - Test Ansible setup"
    echo "  report                    - Generate comprehensive report"
    echo ""
    echo "Examples:"
    echo "  $0 all                    # Run comprehensive diagnostics"
    echo "  $0 network                # Test basic connectivity"
    echo "  $0 tunnel                 # Check SSH tunnel status"
    echo ""
}

# Main function
main() {
    print_header "K3s Cluster Diagnostics"
    
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi
    
    local command="$1"
    
    case "$command" in
        "help"|"-h"|"--help")
            show_usage
            ;;
        "all")
            test_network_connectivity
            test_ssh_connectivity
            test_k3s_services
            test_local_kubectl
            test_ssh_tunnel
            test_ansible_setup
            generate_report
            ;;
        "network")
            test_network_connectivity
            ;;
        "ssh")
            test_ssh_connectivity
            ;;
        "k3s")
            test_k3s_services
            ;;
        "kubectl")
            test_local_kubectl
            ;;
        "tunnel")
            test_ssh_tunnel
            ;;
        "ansible")
            test_ansible_setup
            ;;
        "report")
            generate_report
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"