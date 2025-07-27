#!/bin/bash
# K3s SSH Tunnel Setup Script
# Creates SSH tunnel to access K3s API server through Proxmox jump host

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
K3S_MASTER_USER="ubuntu"
K3S_API_PORT="6443"
LOCAL_TUNNEL_PORT="6443"
KUBECONFIG_LOCAL="$HOME/.kube/config"
KUBECONFIG_REMOTE="/etc/rancher/k3s/k3s.yaml"

# SSH tunnel PID file
TUNNEL_PID_FILE="/tmp/k3s-tunnel.pid"

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

# Show usage information
show_usage() {
    echo -e "${BLUE}🏠 K3s SSH Tunnel Manager${NC}"
    echo "============================="
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "COMMANDS:"
    echo "  start                     - Start SSH tunnel and setup kubeconfig"
    echo "  stop                      - Stop SSH tunnel"
    echo "  status                    - Check tunnel status"
    echo "  restart                   - Restart tunnel"
    echo "  setup                     - Setup kubeconfig only (tunnel must be running)"
    echo "  test                      - Test kubectl connectivity"
    echo "  logs                      - Show tunnel logs"
    echo "  clean                     - Clean up tunnel artifacts"
    echo ""
    echo "CONFIGURATION:"
    echo "  Proxmox Host: $PROXMOX_HOST"
    echo "  K3s Master: $K3S_MASTER_IP"
    echo "  Local Port: $LOCAL_TUNNEL_PORT"
    echo "  Kubeconfig: $KUBECONFIG_LOCAL"
    echo ""
    echo "Examples:"
    echo "  $0 start                  # Start tunnel and setup kubectl"
    echo "  $0 test                   # Test kubectl connection"
    echo "  $0 stop                   # Stop tunnel when done"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    if ! command -v ssh &> /dev/null; then
        missing_tools+=("ssh")
    fi
    
    if ! command -v scp &> /dev/null; then
        missing_tools+=("scp")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl not found - install it for full functionality"
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
}

# Test connectivity to Proxmox
test_proxmox_connectivity() {
    print_info "Testing connectivity to Proxmox host..."
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
        print_error "Cannot connect to Proxmox host: $PROXMOX_HOST"
        print_info "Ensure SSH key authentication is setup for root@$PROXMOX_HOST"
        return 1
    fi
    print_status "Proxmox connectivity verified"
}

# Test connectivity to K3s master through Proxmox
test_k3s_connectivity() {
    print_info "Testing connectivity to K3s master through Proxmox..."
    if ! ssh -o ConnectTimeout=5 -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" "$K3S_MASTER_USER@$K3S_MASTER_IP" exit 2>/dev/null; then
        print_error "Cannot connect to K3s master: $K3S_MASTER_IP through Proxmox jump host"
        print_info "Ensure SSH key authentication is setup for ubuntu@$K3S_MASTER_IP"
        return 1
    fi
    print_status "K3s master connectivity verified"
}

# Check if tunnel is running
is_tunnel_running() {
    if [ -f "$TUNNEL_PID_FILE" ]; then
        local pid=$(cat "$TUNNEL_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$TUNNEL_PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Start SSH tunnel
start_tunnel() {
    print_header "Starting K3s SSH Tunnel"
    
    # Check prerequisites
    check_prerequisites
    
    # Test connectivity
    if ! test_proxmox_connectivity; then
        exit 1
    fi
    
    if ! test_k3s_connectivity; then
        exit 1
    fi
    
    # Check if tunnel is already running
    if is_tunnel_running; then
        print_warning "SSH tunnel is already running (PID: $(cat $TUNNEL_PID_FILE))"
        return 0
    fi
    
    # Check if local port is available
    if lsof -Pi :$LOCAL_TUNNEL_PORT -sTCP:LISTEN -t >/dev/null; then
        print_error "Port $LOCAL_TUNNEL_PORT is already in use"
        print_info "Stop existing processes or choose a different port"
        exit 1
    fi
    
    print_info "Creating SSH tunnel: localhost:$LOCAL_TUNNEL_PORT -> $K3S_MASTER_IP:$K3S_API_PORT"
    
    # Start SSH tunnel in background
    ssh -f -N -L "$LOCAL_TUNNEL_PORT:$K3S_MASTER_IP:$K3S_API_PORT" \
        -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -o ExitOnForwardFailure=yes \
        "$K3S_MASTER_USER@$K3S_MASTER_IP"
    
    # Find and save tunnel PID
    sleep 2
    local tunnel_pid=$(lsof -ti :$LOCAL_TUNNEL_PORT)
    if [ -n "$tunnel_pid" ]; then
        echo "$tunnel_pid" > "$TUNNEL_PID_FILE"
        print_status "SSH tunnel started (PID: $tunnel_pid)"
    else
        print_error "Failed to start SSH tunnel"
        exit 1
    fi
    
    # Setup kubeconfig
    setup_kubeconfig
    
    # Test connection
    test_kubectl
}

# Stop SSH tunnel
stop_tunnel() {
    print_header "Stopping K3s SSH Tunnel"
    
    if ! is_tunnel_running; then
        print_warning "No SSH tunnel is running"
        return 0
    fi
    
    local pid=$(cat "$TUNNEL_PID_FILE")
    print_info "Stopping SSH tunnel (PID: $pid)"
    
    if kill "$pid" 2>/dev/null; then
        rm -f "$TUNNEL_PID_FILE"
        print_status "SSH tunnel stopped"
    else
        print_error "Failed to stop SSH tunnel"
        # Force cleanup
        rm -f "$TUNNEL_PID_FILE"
    fi
}

# Check tunnel status
check_status() {
    print_header "K3s SSH Tunnel Status"
    
    if is_tunnel_running; then
        local pid=$(cat "$TUNNEL_PID_FILE")
        print_status "SSH tunnel is running (PID: $pid)"
        
        # Check if port is actually listening
        if lsof -Pi :$LOCAL_TUNNEL_PORT -sTCP:LISTEN -t >/dev/null; then
            print_status "Local port $LOCAL_TUNNEL_PORT is listening"
        else
            print_warning "Local port $LOCAL_TUNNEL_PORT is not listening"
        fi
        
        # Check kubeconfig
        if [ -f "$KUBECONFIG_LOCAL" ]; then
            print_status "Kubeconfig exists: $KUBECONFIG_LOCAL"
            
            # Test kubectl if available
            if command -v kubectl &> /dev/null; then
                if kubectl cluster-info &>/dev/null; then
                    print_status "kubectl connectivity verified"
                else
                    print_warning "kubectl cannot connect to cluster"
                fi
            fi
        else
            print_warning "Kubeconfig not found: $KUBECONFIG_LOCAL"
        fi
    else
        print_warning "SSH tunnel is not running"
    fi
    
    echo ""
    print_info "Connection details:"
    echo "  Local endpoint: https://127.0.0.1:$LOCAL_TUNNEL_PORT"
    echo "  Remote endpoint: $K3S_MASTER_IP:$K3S_API_PORT"
    echo "  Jump host: $PROXMOX_USER@$PROXMOX_HOST"
}

# Setup kubeconfig
setup_kubeconfig() {
    print_info "Setting up kubeconfig..."
    
    # Create .kube directory if it doesn't exist
    mkdir -p "$(dirname "$KUBECONFIG_LOCAL")"
    
    # Copy kubeconfig from K3s master
    print_info "Copying kubeconfig from K3s master..."
    scp -o ProxyJump="$PROXMOX_USER@$PROXMOX_HOST" \
        "$K3S_MASTER_USER@$K3S_MASTER_IP:$KUBECONFIG_REMOTE" \
        "$KUBECONFIG_LOCAL"
    
    # Modify kubeconfig to use local tunnel
    print_info "Configuring kubeconfig for local tunnel..."
    sed -i.backup "s|server: https://.*:$K3S_API_PORT|server: https://127.0.0.1:$LOCAL_TUNNEL_PORT|g" "$KUBECONFIG_LOCAL"
    
    # Set proper permissions
    chmod 600 "$KUBECONFIG_LOCAL"
    
    print_status "Kubeconfig configured: $KUBECONFIG_LOCAL"
}

# Test kubectl connectivity
test_kubectl() {
    print_header "Testing kubectl Connectivity"
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        print_info "Install kubectl to test connectivity"
        return 1
    fi
    
    if [ ! -f "$KUBECONFIG_LOCAL" ]; then
        print_error "Kubeconfig not found: $KUBECONFIG_LOCAL"
        print_info "Run: $0 setup"
        return 1
    fi
    
    export KUBECONFIG="$KUBECONFIG_LOCAL"
    
    print_info "Testing cluster connection..."
    if kubectl cluster-info; then
        print_status "✅ kubectl connection successful!"
        echo ""
        print_info "Node status:"
        kubectl get nodes
        echo ""
        print_info "Available namespaces:"
        kubectl get namespaces
    else
        print_error "kubectl connection failed"
        return 1
    fi
}

# Show tunnel logs
show_logs() {
    print_header "SSH Tunnel Logs"
    
    if ! is_tunnel_running; then
        print_warning "No SSH tunnel is running"
        return 1
    fi
    
    local pid=$(cat "$TUNNEL_PID_FILE")
    print_info "SSH tunnel process (PID: $pid):"
    ps -fp "$pid"
    
    echo ""
    print_info "Network connections:"
    lsof -Pan -p "$pid"
}

# Clean up tunnel artifacts
clean_up() {
    print_header "Cleaning up K3s Tunnel Artifacts"
    
    # Stop tunnel if running
    if is_tunnel_running; then
        stop_tunnel
    fi
    
    # Remove PID file
    if [ -f "$TUNNEL_PID_FILE" ]; then
        rm -f "$TUNNEL_PID_FILE"
        print_status "Removed PID file"
    fi
    
    # Backup and remove kubeconfig
    if [ -f "$KUBECONFIG_LOCAL" ]; then
        mv "$KUBECONFIG_LOCAL" "$KUBECONFIG_LOCAL.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backed up kubeconfig"
    fi
    
    print_status "Cleanup completed"
}

# Restart tunnel
restart_tunnel() {
    print_header "Restarting K3s SSH Tunnel"
    stop_tunnel
    sleep 2
    start_tunnel
}

# Main script logic
main() {
    # Handle no arguments
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi
    
    # Parse command
    local command="$1"
    
    case "$command" in
        "help"|"-h"|"--help")
            show_usage
            ;;
        "start")
            start_tunnel
            ;;
        "stop")
            stop_tunnel
            ;;
        "status")
            check_status
            ;;
        "restart")
            restart_tunnel
            ;;
        "setup")
            setup_kubeconfig
            ;;
        "test")
            test_kubectl
            ;;
        "logs")
            show_logs
            ;;
        "clean")
            clean_up
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