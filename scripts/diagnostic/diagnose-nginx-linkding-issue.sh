#!/bin/bash
# Diagnose Nginx-Linkding Configuration Issues
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/diagnose-nginx-linkding-issue-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🔍 Diagnose Nginx-Linkding Configuration Issues"
echo "==============================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

PROXMOX_HOST="192.168.2.100"

echo "🔍 CHECKING SERVICE STATUS"
echo "========================="
echo ""

ssh root@$PROXMOX_HOST << 'EOF'
echo "1. Service status:"
echo "Nginx service:"
systemctl status nginx --no-pager -l

echo ""
echo "Linkding service:"
systemctl status linkding --no-pager -l

echo ""
echo "2. Port usage analysis:"
netstat -tlnp | grep -E ":80|:9090|:9091|:8080|:8006"

echo ""
echo "3. Nginx configuration test:"
nginx -t

echo ""
echo "4. Nginx error logs (last 10 lines):"
tail -10 /var/log/nginx/error.log 2>/dev/null || echo "No nginx error log found"

echo ""
echo "5. Nginx access logs (last 5 lines):"
tail -5 /var/log/nginx/access.log 2>/dev/null || echo "No nginx access log found"
EOF

echo ""
echo "🔍 CHECKING NGINX SITE CONFIGURATION"
echo "==================================="
echo ""

ssh root@$PROXMOX_HOST << 'EOF'
echo "6. Enabled sites:"
ls -la /etc/nginx/sites-enabled/

echo ""
echo "7. Linkding site configuration:"
if [ -f /etc/nginx/sites-available/linkding ]; then
    echo "✅ Linkding site exists"
    echo "Configuration content:"
    cat /etc/nginx/sites-available/linkding
else
    echo "❌ Linkding site configuration missing"
fi

echo ""
echo "8. Nginx main configuration includes:"
grep -n "include.*sites" /etc/nginx/nginx.conf || echo "No sites include found"
EOF

echo ""
echo "🔍 CHECKING STATIC FILES"
echo "======================="
echo ""

ssh root@$PROXMOX_HOST << 'EOF'
echo "9. Static files directory:"
ls -la /opt/linkding/linkding/static/ | head -10

echo ""
echo "10. Static files permissions:"
find /opt/linkding/linkding/static -type f -name "*.css" -exec ls -la {} \; | head -5

echo ""
echo "11. Nginx user/group:"
ps aux | grep nginx | head -1
echo ""
echo "Static files ownership:"
ls -la /opt/linkding/linkding/static/ | head -3
EOF

echo ""
echo "🔍 TESTING CONNECTIVITY"
echo "======================"
echo ""

ssh root@$PROXMOX_HOST << 'EOF'
echo "12. Testing internal Linkding (port 9090):"
curl -s --connect-timeout 5 "http://127.0.0.1:9090/" > /dev/null && echo "✅ Internal port working" || echo "❌ Internal port failed"

echo ""
echo "13. Testing nginx proxy (port 9091):"
curl -s --connect-timeout 5 "http://127.0.0.1:9091/" > /dev/null && echo "✅ Nginx proxy working" || echo "❌ Nginx proxy failed"

echo ""
echo "14. Testing static file serving:"
curl -s --connect-timeout 5 "http://127.0.0.1:9091/static/theme-light.css" | head -3 | grep -q "color\|css" && echo "✅ Static files working" || echo "❌ Static files failed"

echo ""
echo "15. Testing external access:"
curl -s --connect-timeout 5 "http://192.168.2.100:9091/" > /dev/null && echo "✅ External access working" || echo "❌ External access failed"
EOF

echo ""
echo "🔍 CHECKING FIREWALL"  
echo "=================="
echo ""

ssh root@$PROXMOX_HOST << 'EOF'
echo "16. UFW status:"
ufw status 2>/dev/null || echo "UFW not active or not installed"

echo ""
echo "17. iptables rules for port 9091:"
iptables -L INPUT -n | grep 9091 || echo "No iptables rules for port 9091"

echo ""
echo "18. Active network interfaces:"
ip addr show | grep "inet " | head -5
EOF

echo ""
echo "✅ DIAGNOSIS COMPLETE"
echo "===================="
echo ""
echo "📋 SUMMARY TO REVIEW:"
echo "• Check service status (nginx and linkding running?)"
echo "• Verify port 9091 is listening"
echo "• Review nginx site configuration"
echo "• Check static files permissions"
echo "• Verify internal connectivity (port 9090)"
echo "• Check nginx error logs for issues"
echo ""
echo "📋 Diagnosis log saved to: $LOGFILE"
echo "Timestamp: $(date)"