#!/bin/bash
# Nextcloud Management Script
# Unified management for Nextcloud cloud file service on Proxmox host
set -euo pipefail

PROXMOX_HOST="192.168.2.100"
NEXTCLOUD_PORT="9092"
NEXTCLOUD_URL="http://$PROXMOX_HOST:$NEXTCLOUD_PORT"

echo "🔧 Nextcloud Management Script"
echo "=============================="
echo ""

case "${1:-status}" in
    "status")
        echo "📊 NEXTCLOUD SERVICE STATUS"
        echo "============================"
        echo ""
        
        # Check service accessibility
        echo "1. Service accessibility:"
        main_status=$(curl -s -w "%{http_code}" "$NEXTCLOUD_URL/" -o /dev/null 2>/dev/null || echo "000")
        login_status=$(curl -s -w "%{http_code}" "$NEXTCLOUD_URL/login" -o /dev/null 2>/dev/null || echo "000")
        
        if [ "$main_status" = "200" ] || [ "$main_status" = "302" ]; then
            echo "✅ Main page: HTTP $main_status"
        else
            echo "❌ Main page: HTTP $main_status"
        fi
        
        if [ "$login_status" = "200" ]; then
            echo "✅ Login page: HTTP $login_status"
        else
            echo "❌ Login page: HTTP $login_status"
        fi
        
        echo ""
        echo "2. WebDAV API:"
        webdav_status=$(curl -s -w "%{http_code}" "$NEXTCLOUD_URL/remote.php/dav/" -o /dev/null 2>/dev/null || echo "000")
        if [ "$webdav_status" = "401" ] || [ "$webdav_status" = "200" ]; then
            echo "✅ WebDAV endpoint: HTTP $webdav_status (requires auth)"
        else
            echo "❌ WebDAV endpoint: HTTP $webdav_status"
        fi
        
        echo ""
        echo "3. Backend services (via SSH):"
        ssh root@$PROXMOX_HOST << 'EOF'
        echo "Nginx status:"
        systemctl is-active nginx || echo "❌ Nginx not running"
        
        echo "PHP-FPM status:"
        systemctl is-active php8.2-fpm || echo "❌ PHP-FPM not running"
        
        echo "Disk usage:"
        df -h /storage/nextcloud-data/ 2>/dev/null || echo "⚠️ Data directory not accessible"
EOF
        ;;
        
    "restart")
        echo "🔄 RESTARTING NEXTCLOUD SERVICES"
        echo "================================"
        echo ""
        
        ssh root@$PROXMOX_HOST << 'EOF'
        echo "Restarting PHP-FPM..."
        systemctl restart php8.2-fpm
        sleep 2
        
        echo "Reloading Nginx..."
        systemctl reload nginx
        sleep 2
        
        echo "✅ Services restarted"
EOF
        
        echo ""
        echo "Testing service after restart..."
        sleep 3
        status_check=$(curl -s -w "%{http_code}" "$NEXTCLOUD_URL/" -o /dev/null 2>/dev/null || echo "000")
        if [ "$status_check" = "200" ] || [ "$status_check" = "302" ]; then
            echo "✅ Service is responding: HTTP $status_check"
        else
            echo "❌ Service may have issues: HTTP $status_check"
        fi
        ;;
        
    "logs")
        echo "📋 NEXTCLOUD SERVICE LOGS"
        echo "========================="
        echo ""
        
        ssh root@$PROXMOX_HOST << 'EOF'
        echo "=== Nginx Error Log (last 10 lines) ==="
        tail -10 /var/log/nginx/error.log
        
        echo ""
        echo "=== Nginx Access Log (last 5 lines) ==="
        tail -5 /var/log/nginx/access.log
        
        echo ""
        echo "=== PHP-FMP Error Log ==="
        if [ -f /var/log/nextcloud/php-errors.log ]; then
            tail -10 /var/log/nextcloud/php-errors.log
        else
            echo "No PHP error log found"
        fi
EOF
        ;;
        
    "maintenance")
        echo "🔧 NEXTCLOUD MAINTENANCE MODE"
        echo "============================="
        echo ""
        
        ssh root@$PROXMOX_HOST << 'EOF'
        cd /opt/nextcloud
        current_mode=$(sudo -u www-data php occ maintenance:mode)
        echo "Current maintenance mode: $current_mode"
        
        if [[ "$current_mode" == *"enabled"* ]]; then
            echo "Disabling maintenance mode..."
            sudo -u www-data php occ maintenance:mode --off
        else
            echo "Enabling maintenance mode..."
            sudo -u www-data php occ maintenance:mode --on
        fi
        
        new_mode=$(sudo -u www-data php occ maintenance:mode)
        echo "New maintenance mode: $new_mode"
EOF
        ;;
        
    "webdav-test")
        echo "🔗 WEBDAV API TEST"
        echo "=================="
        echo ""
        
        echo "Testing WebDAV endpoints..."
        echo "1. WebDAV root:"
        curl -u admin:NextJourney1 -X PROPFIND "$NEXTCLOUD_URL/remote.php/dav/" -H "Depth: 1" 2>/dev/null | head -5 || echo "❌ WebDAV root test failed"
        
        echo ""
        echo "2. User files directory:"
        curl -u admin:NextJourney1 -X PROPFIND "$NEXTCLOUD_URL/remote.php/dav/files/admin/" -H "Depth: 1" 2>/dev/null | head -5 || echo "❌ User files test failed"
        
        echo ""
        echo "📋 WebDAV Usage:"
        echo "• Upload file: curl -u admin:NextJourney1 -T file.txt $NEXTCLOUD_URL/remote.php/dav/files/admin/file.txt"
        echo "• Download file: curl -u admin:NextJourney1 $NEXTCLOUD_URL/remote.php/dav/files/admin/file.txt"
        echo "• List files: curl -u admin:NextJourney1 -X PROPFIND $NEXTCLOUD_URL/remote.php/dav/files/admin/"
        ;;
        
    "help"|*)
        echo "📋 NEXTCLOUD MANAGEMENT COMMANDS"
        echo "==============================="
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Available commands:"
        echo "  status        Show service status and health"
        echo "  restart       Restart Nextcloud services (nginx + PHP-FPM)"
        echo "  logs          Show recent service logs"
        echo "  maintenance   Toggle maintenance mode"
        echo "  webdav-test   Test WebDAV API functionality"
        echo "  help          Show this help message"
        echo ""
        echo "🌐 Service Access:"
        echo "• Web Interface: $NEXTCLOUD_URL"
        echo "• Login: admin / NextJourney1"
        echo "• WebDAV API: $NEXTCLOUD_URL/remote.php/dav/"
        echo ""
        echo "📁 File Locations:"
        echo "• Data directory: /storage/nextcloud-data/"
        echo "• Application: /opt/nextcloud/"
        echo "• Nginx config: /etc/nginx/sites-available/nextcloud"
        ;;
esac