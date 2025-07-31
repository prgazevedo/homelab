#!/bin/bash
# Unified Git Service Management for LXC Container
set -euo pipefail

# Configuration
GIT_SERVICE_IP="192.168.2.200"
GIT_SERVICE_PORT="3000"
GIT_SERVICE_VMID="200"
CONTAINER_USER="git"
SERVICE_NAME="forgejo"

# Create logs directory if it doesn't exist
mkdir -p logs

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Function to check if virtual environment exists
check_venv() {
    if [ -d "venv" ]; then
        source venv/bin/activate
        print_status "Activated Python virtual environment"
    fi
}

# Function to show usage
show_usage() {
    echo "Git Service Manager - LXC Container Management"
    echo "============================================="
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Container Management:"
    echo "  start             Start Git service container"
    echo "  stop              Stop Git service container"
    echo "  restart           Restart Git service container"
    echo "  status            Show container status"
    echo ""
    echo "Service Management:"
    echo "  service-start     Start Forgejo service"
    echo "  service-stop      Stop Forgejo service"  
    echo "  service-restart   Restart Forgejo service"
    echo "  service-status    Show Forgejo service status"
    echo "  service-logs      View Forgejo service logs"
    echo ""
    echo "Monitoring:"
    echo "  health            Comprehensive health check"
    echo "  version           Show Forgejo version"
    echo "  stats             Resource usage statistics"
    echo "  connectivity      Test network connectivity"
    echo ""
    echo "Administration:"
    echo "  shell             SSH into Git service container"
    echo "  backup            Backup Git repositories and database"
    echo "  update            Update Forgejo to latest version"
    echo "  clean             Clean up logs and temporary files"
    echo ""
    echo "Development:"
    echo "  setup             Initial setup and deployment"
    echo "  reset             Reset and redeploy service"
    echo "  test              Run connectivity and functionality tests"
    echo ""
    echo "Configuration:"
    echo "  IP Address: $GIT_SERVICE_IP"
    echo "  Port: $GIT_SERVICE_PORT"
    echo "  VM ID: $GIT_SERVICE_VMID"
    echo "  Web UI: http://$GIT_SERVICE_IP:$GIT_SERVICE_PORT"
}

# Container management functions
container_start() {
    print_header "🚀 Starting Git Service Container"
    ansible proxmox -i ansible/inventory.yml -m shell -a "pct start $GIT_SERVICE_VMID"
    sleep 10
    print_status "Container started, waiting for network initialization..."
    container_status
}

container_stop() {
    print_header "🛑 Stopping Git Service Container"
    ansible proxmox -i ansible/inventory.yml -m shell -a "pct stop $GIT_SERVICE_VMID"
    print_status "Container stopped"
}

container_restart() {
    print_header "🔄 Restarting Git Service Container"
    container_stop
    sleep 5
    container_start
}

container_status() {
    print_header "📊 Git Service Container Status"
    ansible proxmox -i ansible/inventory.yml -m shell -a "pct status $GIT_SERVICE_VMID"
    ansible proxmox -i ansible/inventory.yml -m shell -a "ping -c 2 $GIT_SERVICE_IP || echo 'Network not ready'"
}

# Service management functions
service_start() {
    print_header "▶️ Starting Forgejo Service"
    ansible git-service -i ansible/inventory.yml -m shell -a "systemctl start $SERVICE_NAME"
    print_status "Forgejo service started"
}

service_stop() {
    print_header "⏹️ Stopping Forgejo Service"
    ansible git-service -i ansible/inventory.yml -m shell -a "systemctl stop $SERVICE_NAME"
    print_status "Forgejo service stopped"
}

service_restart() {
    print_header "🔄 Restarting Forgejo Service"
    ansible git-service -i ansible/inventory.yml -m shell -a "systemctl restart $SERVICE_NAME"
    print_status "Forgejo service restarted"
}

service_status() {
    print_header "📊 Forgejo Service Status"
    ansible git-service -i ansible/inventory.yml -m shell -a "systemctl status $SERVICE_NAME --no-pager -l"
}

service_logs() {
    print_header "📜 Forgejo Service Logs"
    ansible git-service -i ansible/inventory.yml -m shell -a "journalctl -u $SERVICE_NAME --no-pager -l -n 50"
}

# Monitoring functions
health_check() {
    print_header "🏥 Git Service Health Check"
    
    echo "1. Container Status:"
    container_status
    echo ""
    
    echo "2. Service Status:"
    service_status
    echo ""
    
    echo "3. Network Connectivity:"
    connectivity_test
    echo ""
    
    echo "4. Resource Usage:"
    stats_check
    echo ""
    
    echo "5. Web Interface Test:"
    version_check
}

version_check() {
    print_header "📝 Forgejo Version Information"
    curl -s "http://$GIT_SERVICE_IP:$GIT_SERVICE_PORT/api/v1/version" | jq . 2>/dev/null || \
    curl -s "http://$GIT_SERVICE_IP:$GIT_SERVICE_PORT/api/v1/version" || \
    print_error "Failed to retrieve version information"
}

stats_check() {
    print_header "📈 Resource Usage Statistics"
    ansible git-service -i ansible/inventory.yml -m shell -a "
    echo '=== CPU and Memory ==='
    top -bn1 | head -15
    echo ''
    echo '=== Disk Usage ==='
    df -h /var/lib/forgejo
    echo ''
    echo '=== Service Process ==='
    ps aux | grep forgejo | grep -v grep
    "
}

connectivity_test() {
    print_header "🌐 Network Connectivity Test"
    
    echo "Testing from Proxmox host:"
    ansible proxmox -i ansible/inventory.yml -m shell -a "curl -s -o /dev/null -w 'HTTP Status: %{http_code}' http://$GIT_SERVICE_IP:$GIT_SERVICE_PORT || echo 'Connection failed'"
    
    echo ""
    echo "Port status:"
    ansible git-service -i ansible/inventory.yml -m shell -a "ss -tlnp | grep :$GIT_SERVICE_PORT || echo 'Port not listening'"
}

# Administrative functions
shell_access() {
    print_header "🖥️ SSH Access to Git Service Container"
    print_status "Connecting to git@$GIT_SERVICE_IP..."
    ssh "git@$GIT_SERVICE_IP"
}

backup_service() {
    print_header "💾 Backing Up Git Service"
    BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
    BACKUP_DIR="backups/git-service-$BACKUP_DATE"
    
    mkdir -p "$BACKUP_DIR"
    
    print_status "Creating backup in $BACKUP_DIR"
    
    # Backup database
    ansible git-service -i ansible/inventory.yml -m shell -a "
    sudo -u git sqlite3 /var/lib/forgejo/forgejo.db '.backup /tmp/forgejo-backup.db'
    " 
    
    ansible git-service -i ansible/inventory.yml -m fetch -a "
    src=/tmp/forgejo-backup.db
    dest=$BACKUP_DIR/
    flat=yes
    "
    
    # Backup configuration
    ansible git-service -i ansible/inventory.yml -m fetch -a "
    src=/etc/forgejo/app.ini
    dest=$BACKUP_DIR/
    flat=yes
    "
    
    print_status "Backup completed: $BACKUP_DIR"
}

update_service() {
    print_header "🔄 Updating Forgejo Service"
    print_warning "This will download and install the latest Forgejo version"
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ansible git-service -i ansible/inventory.yml -m shell -a "
        systemctl stop $SERVICE_NAME
        wget -O /tmp/forgejo-new https://github.com/go-gitea/gitea/releases/latest/download/gitea-linux-amd64
        chmod +x /tmp/forgejo-new
        mv /opt/forgejo/forgejo /opt/forgejo/forgejo.bak
        mv /tmp/forgejo-new /opt/forgejo/forgejo
        chown git:git /opt/forgejo/forgejo
        systemctl start $SERVICE_NAME
        "
        print_status "Update completed"
    else
        print_status "Update cancelled"
    fi
}

clean_service() {
    print_header "🧹 Cleaning Up Git Service"
    ansible git-service -i ansible/inventory.yml -m shell -a "
    journalctl --vacuum-time=7d
    find /var/lib/forgejo/log -name '*.log' -mtime +7 -delete
    find /tmp -name '*forgejo*' -mtime +1 -delete
    "
    print_status "Cleanup completed"
}

# Development functions
setup_service() {
    print_header "🏗️ Setting Up Git Service"
    print_status "Running complete setup process..."
    
    if [ -f "create-git-service-lxc.sh" ]; then
        ./create-git-service-lxc.sh
    else
        print_error "Setup script not found: create-git-service-lxc.sh"
        exit 1
    fi
    
    if [ -f "deploy-forgejo-lxc.sh" ]; then
        ./deploy-forgejo-lxc.sh
    else
        print_error "Deployment script not found: deploy-forgejo-lxc.sh"
        exit 1
    fi
    
    print_status "Setup completed"
}

reset_service() {
    print_header "🔄 Resetting Git Service"
    print_warning "This will completely reset the Git service and all data will be lost!"
    
    read -p "Are you sure? Type 'RESET' to confirm: " -r
    if [[ $REPLY == "RESET" ]]; then
        container_stop
        sleep 5
        ansible proxmox -i ansible/inventory.yml -m shell -a "pct destroy $GIT_SERVICE_VMID --force" || print_warning "Container may not exist"
        sleep 5
        setup_service
    else
        print_status "Reset cancelled"
    fi
}

test_service() {
    print_header "🧪 Testing Git Service Functionality"
    
    echo "1. Basic connectivity:"
    connectivity_test
    echo ""
    
    echo "2. Web interface:"
    curl -s -I "http://$GIT_SERVICE_IP:$GIT_SERVICE_PORT" | head -1 || print_error "Web interface not accessible"
    echo ""
    
    echo "3. API endpoint:"
    version_check
    echo ""
    
    echo "4. SSH connectivity:"
    ssh -o ConnectTimeout=5 -o BatchMode=yes "git@$GIT_SERVICE_IP" exit 2>/dev/null && \
    print_status "SSH access working" || print_warning "SSH access may require key setup"
}

# Main script logic
main() {
    check_venv
    
    case "${1:-help}" in
        "start")
            container_start
            ;;
        "stop")
            container_stop
            ;;
        "restart")
            container_restart
            ;;
        "status")
            container_status
            ;;
        "service-start")
            service_start
            ;;
        "service-stop")
            service_stop
            ;;
        "service-restart")
            service_restart
            ;;
        "service-status")
            service_status
            ;;
        "service-logs")
            service_logs
            ;;
        "health")
            health_check
            ;;
        "version")
            version_check
            ;;
        "stats")
            stats_check
            ;;
        "connectivity")
            connectivity_test
            ;;
        "shell")
            shell_access
            ;;
        "backup")
            backup_service
            ;;
        "update")
            update_service
            ;;
        "clean")
            clean_service
            ;;
        "setup")
            setup_service
            ;;
        "reset")
            reset_service
            ;;
        "test")
            test_service
            ;;
        "help"|*)
            show_usage
            ;;
    esac
}

# Set up logging for all commands except help
if [[ "${1:-help}" != "help" ]]; then
    LOGFILE="logs/git-service-$(date +%Y%m%d-%H%M%S).log"
    exec > >(tee -a "$LOGFILE")
    exec 2>&1
    print_status "Logging to: $LOGFILE"
fi

main "$@"