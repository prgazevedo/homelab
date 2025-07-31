#!/bin/bash
# Check Nginx Status and Configuration on Proxmox
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/check-nginx-status-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🔍 Nginx Status and Configuration Check"
echo "======================================"
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

PROXMOX_HOST="192.168.2.100"

echo "🔍 CHECKING NGINX INSTALLATION"
echo "============================="
echo ""

echo "1. Nginx installation status..."
ssh root@$PROXMOX_HOST << 'EOF'
echo "Nginx package status:"
dpkg -l | grep nginx || echo "No nginx packages found"

echo ""
echo "Nginx binary location:"
which nginx 2>/dev/null || echo "Nginx binary not found in PATH"

echo ""
echo "Nginx version:"
nginx -v 2>&1 || echo "Could not get nginx version"

echo ""
echo "Nginx service status:"
systemctl status nginx --no-pager -l 2>/dev/null || echo "Nginx service not found or not running"
EOF

echo ""
echo "🔍 CHECKING NGINX CONFIGURATION"
echo "==============================="
echo ""

echo "2. Nginx configuration structure..."
ssh root@$PROXMOX_HOST << 'EOF'
echo "Main nginx configuration:"
if [ -f /etc/nginx/nginx.conf ]; then
    echo "✅ /etc/nginx/nginx.conf exists"
    echo "Configuration file size: $(stat -c%s /etc/nginx/nginx.conf) bytes"
    echo "Last modified: $(stat -c%y /etc/nginx/nginx.conf)"
else
    echo "❌ /etc/nginx/nginx.conf not found"
fi

echo ""
echo "Sites configuration:"
if [ -d /etc/nginx/sites-available ]; then
    echo "✅ /etc/nginx/sites-available directory exists"
    echo "Available sites:"
    ls -la /etc/nginx/sites-available/ 2>/dev/null || echo "Directory empty"
else
    echo "❌ /etc/nginx/sites-available not found"
fi

echo ""
if [ -d /etc/nginx/sites-enabled ]; then
    echo "✅ /etc/nginx/sites-enabled directory exists"
    echo "Enabled sites:"
    ls -la /etc/nginx/sites-enabled/ 2>/dev/null || echo "Directory empty"
else
    echo "❌ /etc/nginx/sites-enabled not found"
fi

echo ""
echo "Configuration directories:"
ls -la /etc/nginx/ 2>/dev/null || echo "Nginx config directory not accessible"
EOF

echo ""
echo "🔍 CHECKING CURRENT NGINX SITES"
echo "==============================="
echo ""

echo "3. Active nginx configurations..."
ssh root@$PROXMOX_HOST << 'EOF'
if [ -f /etc/nginx/nginx.conf ]; then
    echo "Main nginx.conf includes:"
    grep -n "include.*sites" /etc/nginx/nginx.conf 2>/dev/null || echo "No sites includes found"
    
    echo ""
    echo "Default server configurations:"
    grep -n "server_name\|listen" /etc/nginx/nginx.conf 2>/dev/null || echo "No server blocks in main config"
fi

echo ""
echo "Checking for existing site configurations:"
if [ -d /etc/nginx/sites-enabled ]; then
    for site in /etc/nginx/sites-enabled/*; do
        if [ -f "$site" ]; then
            echo "=== Site: $(basename "$site") ==="
            echo "Listen directives:"
            grep -n "listen" "$site" 2>/dev/null || echo "No listen directives"
            echo "Server names:"
            grep -n "server_name" "$site" 2>/dev/null || echo "No server names"
            echo "Location blocks:"
            grep -n "location" "$site" 2>/dev/null || echo "No location blocks"
            echo ""
        fi
    done
else
    echo "No sites-enabled directory"
fi
EOF

echo ""
echo "🔍 CHECKING PORT USAGE"
echo "====================="
echo ""

echo "4. Port usage analysis..."
ssh root@$PROXMOX_HOST << 'EOF'
echo "Ports currently in use:"
netstat -tlnp 2>/dev/null | grep -E ":80|:443|:8006|:8080|:9090" || echo "No relevant ports found"

echo ""
echo "Process listening on port 9090:"
netstat -tlnp 2>/dev/null | grep ":9090" || echo "Port 9090 not in use"

echo ""
echo "Process listening on port 80:"
netstat -tlnp 2>/dev/null | grep ":80 " || echo "Port 80 not in use"

echo ""
echo "Process listening on port 443:"
netstat -tlnp 2>/dev/null | grep ":443" || echo "Port 443 not in use"

echo ""
echo "Process listening on port 8006 (Proxmox):"
netstat -tlnp 2>/dev/null | grep ":8006" || echo "Port 8006 not in use"
EOF

echo ""
echo "🔍 CHECKING NGINX LOGS"
echo "====================="
echo ""

echo "5. Recent nginx logs..."
ssh root@$PROXMOX_HOST << 'EOF'
echo "Nginx error log (last 10 lines):"
if [ -f /var/log/nginx/error.log ]; then
    tail -10 /var/log/nginx/error.log 2>/dev/null || echo "Could not read error log"
else
    echo "No nginx error log found"
fi

echo ""
echo "Nginx access log (last 5 lines):"
if [ -f /var/log/nginx/access.log ]; then
    tail -5 /var/log/nginx/access.log 2>/dev/null || echo "Could not read access log"
else
    echo "No nginx access log found"
fi

echo ""
echo "All nginx log files:"
find /var/log -name "*nginx*" -type f 2>/dev/null || echo "No nginx log files found"
EOF

echo ""
echo "🔍 TESTING NGINX CONFIGURATION"
echo "=============================="
echo ""

echo "6. Configuration validation..."
ssh root@$PROXMOX_HOST << 'EOF'
if command -v nginx >/dev/null 2>&1; then
    echo "Testing nginx configuration:"
    nginx -t 2>&1 || echo "Nginx configuration test failed"
    
    echo ""
    echo "Nginx configuration summary:"
    nginx -T 2>/dev/null | grep -E "server_name|listen|location|root|proxy_pass" | head -20 || echo "Could not get configuration summary"
else
    echo "Nginx command not available"
fi
EOF

echo ""
echo "🔍 CHECKING PROXMOX INTEGRATION"
echo "==============================="
echo ""

echo "7. Proxmox-specific nginx usage..."
ssh root@$PROXMOX_HOST << 'EOF'
echo "Checking if nginx is used by Proxmox services:"
ps aux | grep nginx | grep -v grep || echo "No nginx processes running"

echo ""
echo "Checking Proxmox web service:"
systemctl status pveproxy --no-pager -l 2>/dev/null || echo "Proxmox web service status unknown"

echo ""
echo "Proxmox service ports:"
netstat -tlnp 2>/dev/null | grep -E "pve|proxmox" || echo "No Proxmox-specific ports found"

echo ""
echo "Looking for Proxmox-specific nginx configs:"
find /etc -name "*nginx*" -type f 2>/dev/null | grep -i proxmox || echo "No Proxmox-specific nginx configs found"
EOF

echo ""
echo "✅ NGINX STATUS CHECK COMPLETE"
echo "=============================="
echo ""

# Summary and recommendations
echo "📋 SUMMARY AND RECOMMENDATIONS:"
echo ""

# Check if nginx is running
NGINX_RUNNING=$(ssh root@$PROXMOX_HOST 'systemctl is-active nginx 2>/dev/null' || echo "inactive")
NGINX_INSTALLED=$(ssh root@$PROXMOX_HOST 'which nginx >/dev/null 2>&1 && echo "yes" || echo "no"')

if [ "$NGINX_INSTALLED" = "yes" ]; then
    echo "✅ Nginx is installed"
    
    if [ "$NGINX_RUNNING" = "active" ]; then
        echo "✅ Nginx is running"
        echo ""
        echo "💡 RECOMMENDATIONS:"
        echo "   • Nginx is already running - we can configure it for Linkding"
        echo "   • Add a new site configuration for Linkding static files"
        echo "   • Use existing nginx to proxy Linkding requests"
        echo "   • Check for port conflicts with existing configurations"
    else
        echo "⚠️ Nginx is installed but not running"
        echo ""
        echo "💡 RECOMMENDATIONS:"
        echo "   • Start nginx service: systemctl start nginx"
        echo "   • Configure nginx for Linkding static file serving"
        echo "   • Set up proper site configuration"
    fi
else
    echo "❌ Nginx is not installed"
    echo ""
    echo "💡 RECOMMENDATIONS:"
    echo "   • Install nginx: apt install nginx"
    echo "   • Configure for Linkding static file serving"
fi

# Check port 9090 usage
PORT_9090_USED=$(ssh root@$PROXMOX_HOST 'netstat -tlnp 2>/dev/null | grep ":9090" >/dev/null && echo "yes" || echo "no"')

if [ "$PORT_9090_USED" = "yes" ]; then
    echo ""
    echo "⚠️ Port 9090 is currently in use (likely by Linkding)"
    echo "💡 We need to either:"
    echo "   • Configure nginx to proxy to Linkding on port 9090"
    echo "   • Move Linkding to internal port and nginx to 9090"
    echo "   • Use a different port for nginx"
fi

echo ""
echo "🔧 NEXT STEPS:"
echo "   1. Review the configuration details above"
echo "   2. Decide on nginx setup approach based on current state"
echo "   3. Configure nginx to serve Linkding static files"
echo ""
echo "📋 Check log saved to: $LOGFILE"
echo "Timestamp: $(date)"