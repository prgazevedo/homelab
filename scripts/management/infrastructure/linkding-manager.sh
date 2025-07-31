#!/bin/bash
# Linkding Bookmark Service Manager
# Provides comprehensive management for Linkding service on Proxmox host
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/linkding-manager-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

COMMAND="${1:-status}"

echo "🔖 Linkding Bookmark Service Manager"
echo "===================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo "Command: $COMMAND"
echo ""

# Configuration
PROXMOX_HOST="192.168.2.100"
LINKDING_PORT="9090"
LINKDING_URL="http://$PROXMOX_HOST:$LINKDING_PORT"

case "$COMMAND" in
    "status")
        echo "📊 LINKDING SERVICE STATUS"
        echo "=========================="
        echo ""
        
        echo "🔍 Service Health Check:"
        if curl -s -f "$LINKDING_URL/health" > /dev/null 2>&1; then
            echo "✅ Linkding service is running and healthy"
            echo "🌐 Access URL: $LINKDING_URL"
        else
            echo "❌ Linkding service is not responding"
            echo "💡 Try: ./homelab-unified.sh linkding deploy"
        fi
        echo ""
        
        echo "🐳 Docker Container Status:"
        if ansible proxmox -i ansible/inventory.yml -m shell -a "docker ps --filter name=linkding --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" > /dev/null 2>&1; then
            ansible proxmox -i ansible/inventory.yml -m shell -a "docker ps --filter name=linkding --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
        else
            echo "❌ Could not check Docker status"
        fi
        echo ""
        
        echo "💾 Storage Information:"
        ansible proxmox -i ansible/inventory.yml -m shell -a "du -sh /var/lib/linkding 2>/dev/null || echo 'Data directory not found'"
        ;;
        
    "health")
        echo "🏥 COMPREHENSIVE HEALTH CHECK"
        echo "============================="
        echo ""
        
        echo "1. 🌐 Web Interface Test:"
        if curl -s -f "$LINKDING_URL" > /dev/null 2>&1; then
            echo "   ✅ Web interface accessible"
        else
            echo "   ❌ Web interface not accessible"
        fi
        
        echo "2. 🐳 Container Health:"
        CONTAINER_STATUS=$(ansible proxmox -i ansible/inventory.yml -m shell -a "docker inspect linkding --format '{{.State.Health.Status}}' 2>/dev/null" | grep -v "SUCCESS" | tail -1)
        if [ "$CONTAINER_STATUS" = "healthy" ]; then
            echo "   ✅ Container health check passed"
        else
            echo "   ⚠️ Container health: $CONTAINER_STATUS"
        fi
        
        echo "3. 📊 Resource Usage:"
        ansible proxmox -i ansible/inventory.yml -m shell -a "docker stats linkding --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'" 2>/dev/null || echo "   ❌ Could not get resource stats"
        
        echo "4. 💾 Data Integrity:"
        ansible proxmox -i ansible/inventory.yml -m shell -a "test -f /var/lib/linkding/db.sqlite3 && echo '   ✅ Database file exists' || echo '   ❌ Database file missing'"
        ;;
        
    "backup")
        echo "💾 LINKDING DATA BACKUP"
        echo "======================"
        echo ""
        
        BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
        BACKUP_DIR="/var/lib/linkding-backup-$BACKUP_DATE"
        
        echo "📦 Creating backup: $BACKUP_DIR"
        ansible proxmox -i ansible/inventory.yml -m shell -a "cp -r /var/lib/linkding $BACKUP_DIR"
        
        echo "🗜️ Creating compressed archive:"
        ansible proxmox -i ansible/inventory.yml -m shell -a "tar -czf $BACKUP_DIR.tar.gz -C /var/lib linkding-backup-$BACKUP_DATE"
        
        echo "📊 Backup size:"
        ansible proxmox -i ansible/inventory.yml -m shell -a "ls -lh $BACKUP_DIR.tar.gz"
        
        echo "✅ Backup completed: $BACKUP_DIR.tar.gz"
        ;;
        
    "restore")
        if [ $# -lt 2 ]; then
            echo "❌ Usage: $0 restore <backup-file>"
            echo "Example: $0 restore /var/lib/linkding-backup-20250731-120000.tar.gz"
            exit 1
        fi
        
        BACKUP_FILE="$2"
        echo "🔄 LINKDING DATA RESTORE"
        echo "======================="
        echo ""
        
        echo "⚠️ WARNING: This will replace current bookmark data!"
        echo "Backup file: $BACKUP_FILE"
        echo ""
        
        echo "1. 🛑 Stopping Linkding service:"
        ansible proxmox -i ansible/inventory.yml -m shell -a "systemctl stop linkding"
        
        echo "2. 💾 Backing up current data:"
        CURRENT_BACKUP="/var/lib/linkding-pre-restore-$(date +%Y%m%d-%H%M%S)"
        ansible proxmox -i ansible/inventory.yml -m shell -a "cp -r /var/lib/linkding $CURRENT_BACKUP"
        
        echo "3. 🗜️ Extracting backup:"
        ansible proxmox -i ansible/inventory.yml -m shell -a "tar -xzf $BACKUP_FILE -C /var/lib/"
        
        echo "4. 🔄 Restoring data:"
        ansible proxmox -i ansible/inventory.yml -m shell -a "rm -rf /var/lib/linkding && mv /var/lib/linkding-backup-* /var/lib/linkding"
        
        echo "5. 🚀 Starting Linkding service:"
        ansible proxmox -i ansible/inventory.yml -m shell -a "systemctl start linkding"
        
        echo "✅ Restore completed. Current data backed up to: $CURRENT_BACKUP"
        ;;
        
    "logs")
        echo "📋 LINKDING SERVICE LOGS"
        echo "======================="
        echo ""
        
        echo "🐳 Docker Container Logs (last 50 lines):"
        ansible proxmox -i ansible/inventory.yml -m shell -a "docker logs linkding --tail 50"
        
        echo ""
        echo "🔧 Systemd Service Logs:"
        ansible proxmox -i ansible/inventory.yml -m shell -a "journalctl -u linkding --lines 20 --no-pager"
        ;;
        
    "update")
        echo "🔄 LINKDING SERVICE UPDATE"
        echo "========================="
        echo ""
        
        echo "1. 💾 Creating pre-update backup:"
        ./scripts/management/infrastructure/linkding-manager.sh backup
        
        echo "2. 🐳 Pulling latest Linkding image:"
        ansible proxmox -i ansible/inventory.yml -m shell -a "docker pull sissbruecker/linkding:latest"
        
        echo "3. 🔄 Restarting service with new image:"
        ansible proxmox -i ansible/inventory.yml -m shell -a "systemctl restart linkding"
        
        echo "4. ⏳ Waiting for service to be ready:"
        sleep 10
        
        echo "5. 🏥 Health check after update:"
        ./scripts/management/infrastructure/linkding-manager.sh health
        
        echo "✅ Update completed"
        ;;
        
    "access")
        echo "🌐 LINKDING ACCESS INFORMATION"
        echo "=============================="
        echo ""
        
        echo "📍 Service Details:"
        echo "   Web Interface: $LINKDING_URL"
        echo "   Default Login: admin / changeme123"
        echo "   Service Port: $LINKDING_PORT"
        echo ""
        
        echo "🔧 Browser Extensions:"
        echo "   Firefox: https://addons.mozilla.org/firefox/addon/linkding-extension/"
        echo "   Chrome: https://chrome.google.com/webstore/detail/linkding-extension/"
        echo ""
        
        echo "📱 Mobile Access:"
        echo "   Same URL works on mobile browsers"
        echo "   Responsive web interface"
        echo ""
        
        echo "🔑 API Access:"
        echo "   API Endpoint: $LINKDING_URL/api/"
        echo "   Generate token in Settings → Integrations"
        echo "   Documentation: https://github.com/sissbruecker/linkding/blob/master/docs/API.md"
        ;;
        
    *)
        echo "❌ Unknown command: $COMMAND"
        echo ""
        echo "Available commands:"
        echo "  status  - Check service status and health"
        echo "  health  - Comprehensive health check"
        echo "  backup  - Create backup of bookmark data"
        echo "  restore - Restore from backup file"
        echo "  logs    - View service logs"
        echo "  update  - Update Linkding to latest version"
        echo "  access  - Show access information and browser extensions"
        echo ""
        echo "Examples:"
        echo "  $0 status"
        echo "  $0 backup"
        echo "  $0 restore /var/lib/linkding-backup-20250731-120000.tar.gz"
        exit 1
        ;;
esac

echo ""
echo "📋 Management log saved to: $LOGFILE"
echo "Timestamp: $(date)"