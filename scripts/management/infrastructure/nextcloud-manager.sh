#!/bin/bash
# Nextcloud File Service Manager
# Centralized management for Nextcloud operations
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/nextcloud-manager-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🌐 Nextcloud File Service Manager"
echo "================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

PROXMOX_HOST="192.168.2.100"
NEXTCLOUD_EXTERNAL_PORT="9092"
NEXTCLOUD_INTERNAL_PORT="9093"

# Function to show usage
show_usage() {
    echo "Usage: $0 {status|logs|restart|backup|health|access|occ|help}"
    echo ""
    echo "Commands:"
    echo "  status    - Check Nextcloud service status"
    echo "  logs      - View recent service logs"  
    echo "  restart   - Restart Nextcloud services"
    echo "  backup    - Create backup of Nextcloud data"
    echo "  health    - Run comprehensive health check"
    echo "  access    - Show access URLs and credentials info"
    echo "  occ       - Run Nextcloud occ command (interactive)"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 logs"
    echo "  $0 occ status"
}

# Function to check service status
check_status() {
    echo "📊 NEXTCLOUD SERVICE STATUS"
    echo "==========================="
    echo ""
    
    ssh root@$PROXMOX_HOST << 'EOF'
echo "Core services:"
echo ""
echo "Nginx:"
systemctl status nginx --no-pager | head -3

echo ""
echo "PHP-FPM:"
systemctl status php8.2-fpm --no-pager | head -3

echo ""
echo "PostgreSQL:"
systemctl status postgresql --no-pager | head -3

echo ""
echo "Nextcloud-specific services:"
if systemctl is-active --quiet nextcloud-cron.timer; then
    echo "✅ Nextcloud cron timer: Active"
    systemctl status nextcloud-cron.timer --no-pager | head -3
else
    echo "⚠️ Nextcloud cron timer: Inactive"
fi

echo ""
echo "Port status:"
netstat -tlnp | grep -E ":9092|:9093" | while read line; do
    echo "  $line"
done || echo "  No Nextcloud ports active"

echo ""
echo "Disk usage:"
echo "Application: $(du -sh /opt/nextcloud 2>/dev/null | cut -f1 || echo 'N/A')"
echo "Data: $(du -sh /storage/nextcloud-data 2>/dev/null | cut -f1 || echo 'N/A')"
EOF

    echo ""
    echo "External connectivity:"
    if curl -s -f --connect-timeout 5 "http://$PROXMOX_HOST:$NEXTCLOUD_EXTERNAL_PORT/nginx-health" > /dev/null 2>&1; then
        echo "✅ External access: Working"
    else
        echo "❌ External access: Failed"
    fi
    
    # Check Tailscale if available
    TAILSCALE_IP=$(ssh root@$PROXMOX_HOST 'tailscale ip -4 2>/dev/null' || echo "")
    if [ -n "$TAILSCALE_IP" ]; then
        if curl -s -f --connect-timeout 5 "http://$TAILSCALE_IP:$NEXTCLOUD_EXTERNAL_PORT/nginx-health" > /dev/null 2>&1; then
            echo "✅ Tailscale access: Working ($TAILSCALE_IP)"
        else
            echo "⚠️ Tailscale access: Issues"
        fi
    fi
}

# Function to view logs
view_logs() {
    echo "📋 NEXTCLOUD SERVICE LOGS"
    echo "========================="
    echo ""
    
    ssh root@$PROXMOX_HOST << 'EOF'
echo "Recent nginx errors (last 10 lines):"
tail -10 /var/log/nginx/error.log 2>/dev/null | grep -v "^$" || echo "No nginx errors"

echo ""
echo "Recent PHP-FPM logs (last 10 lines):"
tail -10 /var/log/php8.2-fpm.log 2>/dev/null | grep -v "^$" || echo "No PHP-FPM logs"

echo ""
echo "Nextcloud cron logs (last 5 entries):"
journalctl -u nextcloud-cron --no-pager --since "24 hours ago" | tail -5 || echo "No cron logs"

echo ""
echo "Nextcloud application log (last 5 entries):"
if [ -f /opt/nextcloud/data/nextcloud.log ]; then
    tail -5 /opt/nextcloud/data/nextcloud.log 2>/dev/null || echo "Could not read application log"
else
    echo "No application log found (normal if not configured)"
fi

echo ""
echo "System logs for Nextcloud services:"
journalctl --since "1 hour ago" | grep -i nextcloud | tail -5 || echo "No recent system logs"
EOF
}

# Function to restart services
restart_services() {
    echo "🔄 RESTARTING NEXTCLOUD SERVICES"
    echo "================================"
    echo ""
    
    ssh root@$PROXMOX_HOST << 'EOF'
echo "Restarting PHP-FPM..."
systemctl restart php8.2-fpm
echo "✅ PHP-FPM restarted"

echo ""
echo "Reloading Nginx..."
systemctl reload nginx
echo "✅ Nginx reloaded"

echo ""
echo "Restarting Nextcloud cron timer..."
if systemctl is-enabled --quiet nextcloud-cron.timer; then
    systemctl restart nextcloud-cron.timer
    echo "✅ Nextcloud cron timer restarted"
else
    echo "ℹ️ Nextcloud cron timer not enabled"
fi

echo ""
echo "Waiting for services to stabilize..."
sleep 5

echo ""
echo "Post-restart status:"
systemctl status php8.2-fpm --no-pager | head -3
systemctl status nginx --no-pager | head -3
EOF

    echo ""
    echo "Testing connectivity after restart..."
    sleep 2
    if curl -s -f --connect-timeout 10 "http://$PROXMOX_HOST:$NEXTCLOUD_EXTERNAL_PORT/nginx-health" > /dev/null 2>&1; then
        echo "✅ Services restarted successfully - connectivity restored"
    else
        echo "⚠️ Services restarted but connectivity issues detected"
    fi
}

# Function to create backup
create_backup() {
    echo "💾 CREATING NEXTCLOUD BACKUP"
    echo "============================="
    echo ""
    
    BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
    
    ssh root@$PROXMOX_HOST << EOF
echo "Creating backup directory..."
mkdir -p /storage/backups/nextcloud

echo ""
echo "1. Backing up Nextcloud application..."
tar -czf /storage/backups/nextcloud/nextcloud-app-$BACKUP_DATE.tar.gz -C /opt nextcloud
echo "✅ Application backup: nextcloud-app-$BACKUP_DATE.tar.gz"

echo ""
echo "2. Backing up Nextcloud data..."
tar -czf /storage/backups/nextcloud/nextcloud-data-$BACKUP_DATE.tar.gz -C /storage nextcloud-data
echo "✅ Data backup: nextcloud-data-$BACKUP_DATE.tar.gz"

echo ""
echo "3. Backing up database..."
sudo -u postgres pg_dump nextcloud > /storage/backups/nextcloud/nextcloud-db-$BACKUP_DATE.sql
gzip /storage/backups/nextcloud/nextcloud-db-$BACKUP_DATE.sql
echo "✅ Database backup: nextcloud-db-$BACKUP_DATE.sql.gz"

echo ""
echo "4. Creating backup manifest..."
cat > /storage/backups/nextcloud/backup-manifest-$BACKUP_DATE.txt << 'MANIFEST_EOF'
Nextcloud Backup Manifest
========================
Date: $(date)
Hostname: $(hostname)

Files:
- nextcloud-app-$BACKUP_DATE.tar.gz (Application files)
- nextcloud-data-$BACKUP_DATE.tar.gz (User data and config)
- nextcloud-db-$BACKUP_DATE.sql.gz (PostgreSQL database)

Sizes:
$(ls -lh /storage/backups/nextcloud/*$BACKUP_DATE* | awk '{print $5 " " $9}')
MANIFEST_EOF

echo "✅ Backup manifest created"

echo ""
echo "Backup summary:"
ls -lh /storage/backups/nextcloud/*$BACKUP_DATE*
echo ""
echo "Total backup size: \$(du -sh /storage/backups/nextcloud/ | cut -f1)"
EOF

    echo "✅ Backup completed successfully"
    echo "   Backup date: $BACKUP_DATE"
    echo "   Location: /storage/backups/nextcloud/"
}

# Function to run health check
run_health_check() {
    echo "🔍 RUNNING COMPREHENSIVE HEALTH CHECK"
    echo "====================================="
    echo ""
    
    echo "Running diagnostic script..."
    "$(dirname "$0")/../diagnostic/diagnose-nextcloud-service.sh"
}

# Function to show access information
show_access() {
    echo "🌐 NEXTCLOUD ACCESS INFORMATION"
    echo "==============================="
    echo ""
    
    TAILSCALE_IP=$(ssh root@$PROXMOX_HOST 'tailscale ip -4 2>/dev/null' || echo "")
    
    echo "📍 ACCESS URLS:"
    echo "• Web Interface: http://$PROXMOX_HOST:$NEXTCLOUD_EXTERNAL_PORT"
    echo "• Health Check:  http://$PROXMOX_HOST:$NEXTCLOUD_EXTERNAL_PORT/nginx-health"
    if [ -n "$TAILSCALE_IP" ]; then
    echo "• Tailscale:     http://$TAILSCALE_IP:$NEXTCLOUD_EXTERNAL_PORT"
    fi
    
    echo ""
    echo "📡 WEBDAV API:"
    echo "• Endpoint: http://$PROXMOX_HOST:$NEXTCLOUD_EXTERNAL_PORT/remote.php/dav/files/USERNAME/"
    if [ -n "$TAILSCALE_IP" ]; then
    echo "• Tailscale: http://$TAILSCALE_IP:$NEXTCLOUD_EXTERNAL_PORT/remote.php/dav/files/USERNAME/"
    fi
    
    echo ""
    echo "🔐 AUTHENTICATION:"
    echo "• Use Nextcloud web interface to create users"
    echo "• Generate app passwords for API access"
    echo "• WebDAV format: curl -u 'username:password' [WebDAV URL]"
    
    echo ""
    echo "📱 CLIENT APPS:"
    echo "• Desktop: Nextcloud Desktop Client"
    echo "• Mobile: Nextcloud mobile apps (iOS/Android)"
    echo "• Server URL: http://$PROXMOX_HOST:$NEXTCLOUD_EXTERNAL_PORT"
    
    echo ""
    echo "🧪 TEST WEBDAV:"
    echo "• Run: $(dirname "$0")/../diagnostic/test-nextcloud-webdav.sh"
    echo "• Update script with your admin credentials first"
}

# Function to run occ command
run_occ() {
    if [ $# -eq 0 ]; then
        echo "🔧 NEXTCLOUD OCC COMMAND INTERFACE"
        echo "=================================="
        echo ""
        echo "Usage: $0 occ <command>"
        echo ""
        echo "Common commands:"
        echo "  status                    - Show Nextcloud status"
        echo "  user:list                - List all users"
        echo "  user:add <username>       - Add new user (interactive)"
        echo "  maintenance:mode --on     - Enable maintenance mode"
        echo "  maintenance:mode --off    - Disable maintenance mode"
        echo "  files:scan --all          - Scan all files"
        echo "  config:list               - Show configuration"
        echo ""
        echo "Example: $0 occ status"
        return
    fi
    
    echo "🔧 RUNNING NEXTCLOUD OCC COMMAND"
    echo "==============================="
    echo "Command: occ $*"
    echo ""
    
    ssh root@$PROXMOX_HOST << EOF
cd /opt/nextcloud
sudo -u nextcloud php occ $*
EOF
}

# Main script logic
case "${1:-help}" in
    status)
        check_status
        ;;
    logs)
        view_logs
        ;;
    restart)
        restart_services
        ;;
    backup)
        create_backup
        ;;
    health)
        run_health_check
        ;;
    access)
        show_access
        ;;
    occ)
        shift
        run_occ "$@"
        ;;
    help|*)
        show_usage
        ;;
esac

echo ""
echo "📋 Management log saved to: $LOGFILE"
echo "Timestamp: $(date)"