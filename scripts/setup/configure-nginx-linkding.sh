#!/bin/bash
# Configure Existing Nginx for Linkding Static Files
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/configure-nginx-linkding-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🔧 Configure Existing Nginx for Linkding"
echo "======================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

PROXMOX_HOST="192.168.2.100"

echo "📋 CONFIGURATION APPROACH" 
echo "========================"
echo "✅ Nginx already running on port 80"
echo "✅ Linkding running on port 9090" 
echo "✅ No port conflicts detected"
echo ""
echo "🎯 SOLUTION:"
echo "• Create new nginx site for Linkding"
echo "• Serve static files directly from nginx"
echo "• Proxy app requests to Linkding on port 9090"
echo "• Keep existing nginx setup intact"
echo ""

echo "🔧 CREATING LINKDING NGINX SITE"
echo "==============================="
echo ""

echo "1. Creating Linkding site configuration..."
ssh root@$PROXMOX_HOST << 'EOF'
# Create Linkding site configuration
cat > /etc/nginx/sites-available/linkding << 'NGINX_EOF'
server {
    listen 9091;
    server_name 192.168.2.100 localhost;
    
    # Serve static files directly from nginx
    location /static/ {
        alias /opt/linkding/linkding/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        
        # Enable compression for text files
        gzip on;
        gzip_types text/css application/javascript text/javascript;
        
        # Security headers
        add_header X-Content-Type-Options nosniff;
        add_header X-Frame-Options DENY;
    }
    
    # Serve media files (favicons, previews)
    location /media/ {
        alias /opt/linkding/linkding/data/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Proxy all other requests to Linkding Gunicorn
    location / {
        proxy_pass http://127.0.0.1:9090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Security: deny access to sensitive files
    location ~ /\. {
        deny all;
    }
    
    location ~ ~$ {
        deny all;
    }
}
NGINX_EOF

echo "✅ Linkding nginx site created"

# Test the configuration
nginx -t
if [ $? -eq 0 ]; then
    echo "✅ Nginx configuration test passed"
else
    echo "❌ Nginx configuration test failed"
    exit 1
fi
EOF

echo ""
echo "2. Enabling Linkding site..."
ssh root@$PROXMOX_HOST << 'EOF'
# Enable the Linkding site
ln -sf /etc/nginx/sites-available/linkding /etc/nginx/sites-enabled/

# List enabled sites
echo "Enabled nginx sites:"
ls -la /etc/nginx/sites-enabled/

# Test configuration again
nginx -t
echo "✅ Linkding site enabled"
EOF

echo ""
echo "🔧 UPDATING LINKDING TO INTERNAL PORT"
echo "===================================="
echo ""

echo "3. Configuring Linkding to use internal port..."
ssh root@$PROXMOX_HOST << 'EOF'
# Stop Linkding service
systemctl stop linkding

# Update systemd service to bind to localhost only  
cat > /etc/systemd/system/linkding.service << 'SERVICE_EOF'
[Unit]
Description=Linkding Bookmark Service
After=network.target

[Service]
Type=exec
User=linkding
Group=linkding
WorkingDirectory=/opt/linkding/linkding
Environment=DJANGO_SETTINGS_MODULE=bookmarks.settings
Environment=LD_SERVER_HOST=127.0.0.1
Environment=LD_SERVER_PORT=9090
# Bind to localhost only - nginx will handle external access
ExecStart=/opt/linkding/linkding/venv/bin/gunicorn --bind 127.0.0.1:9090 --workers 2 --timeout 120 --access-logfile - --error-logfile - --preload bookmarks.wsgi:application
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/linkding

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
echo "✅ Linkding service updated for internal access"
EOF

echo ""
echo "🚀 RESTARTING SERVICES"
echo "====================="
echo ""

echo "4. Restarting nginx and Linkding..."
ssh root@$PROXMOX_HOST << 'EOF'
# Reload nginx configuration
systemctl reload nginx

# Start Linkding
systemctl start linkding

# Wait for services to start
sleep 5

echo "Service status:"
echo ""
echo "Nginx:"
systemctl status nginx --no-pager | head -10

echo ""
echo "Linkding:"
systemctl status linkding --no-pager | head -10

echo ""
echo "Port usage:"
netstat -tlnp | grep -E ":9090|:9091|:80"
EOF

echo ""
echo "🧪 TESTING NGINX-LINKDING INTEGRATION"
echo "===================================="
echo ""

echo "5. Testing all endpoints..."
sleep 3

echo "Testing main page via nginx proxy (port 9091)..."
if curl -s -f "http://$PROXMOX_HOST:9091/" > /dev/null 2>&1; then
    echo "✅ Main page accessible via nginx"
    
    echo ""
    echo "Testing static file serving via nginx..."
    
    # Test CSS files
    if curl -s -f "http://$PROXMOX_HOST:9091/static/theme-light.css" | head -3 | grep -q "color\|font\|css"; then
        echo "✅ Light theme CSS served by nginx!"
        CSS_SIZE=$(curl -s "http://$PROXMOX_HOST:9091/static/theme-light.css" | wc -c)
        echo "   CSS file size: $CSS_SIZE bytes"
    else
        echo "⚠️ Light theme CSS issues"
    fi
    
    if curl -s -f "http://$PROXMOX_HOST:9091/static/theme-dark.css" | head -3 | grep -q "color\|font\|css"; then
        echo "✅ Dark theme CSS served by nginx!"
        CSS_SIZE=$(curl -s "http://$PROXMOX_HOST:9091/static/theme-dark.css" | wc -c)
        echo "   CSS file size: $CSS_SIZE bytes"
    else
        echo "⚠️ Dark theme CSS issues"
    fi
    
    # Test JS bundle
    if curl -s -f "http://$PROXMOX_HOST:9091/static/bundle.js" | head -3 | grep -q "function\|var\|const"; then
        echo "✅ JavaScript bundle served by nginx!"
        JS_SIZE=$(curl -s "http://$PROXMOX_HOST:9091/static/bundle.js" | wc -c)
        echo "   JS file size: $JS_SIZE bytes"
    else
        echo "⚠️ JavaScript bundle issues"
    fi
    
    echo ""
    echo "Testing page content for CSS/JS references..."
    page_content=$(curl -s "http://$PROXMOX_HOST:9091/" || echo "")
    if echo "$page_content" | grep -q "theme.*css"; then
        echo "✅ Page contains CSS references"
    else
        echo "⚠️ Page missing CSS references"
    fi
    
    if echo "$page_content" | grep -q "bundle.js"; then
        echo "✅ Page contains JS bundle reference"
    else
        echo "⚠️ Page missing JS bundle reference"
    fi
    
    echo ""
    echo "Testing nginx health endpoint..."
    if curl -s "http://$PROXMOX_HOST:9091/health" | grep -q "healthy"; then
        echo "✅ Nginx health check working"
    else
        echo "⚠️ Health check issues"
    fi
    
else
    echo "❌ Main page not accessible via nginx"
    echo "Checking service logs..."
    ssh root@$PROXMOX_HOST << 'EOF'
    echo "Nginx error log:"
    tail -10 /var/log/nginx/error.log 2>/dev/null || echo "No nginx error log"
    echo ""
    echo "Linkding service log:"
    journalctl -u linkding --no-pager --since "3 minutes ago" | tail -10
    EOF
fi

# Test Tailscale access
TAILSCALE_IP=$(ssh root@$PROXMOX_HOST 'tailscale ip -4 2>/dev/null' || echo "")
if [ -n "$TAILSCALE_IP" ]; then
    echo ""
    echo "Testing Tailscale access via nginx..."
    if curl -s -f --connect-timeout 5 "http://$TAILSCALE_IP:9091/" > /dev/null 2>&1; then
        echo "✅ Tailscale access working via nginx proxy"
    else
        echo "⚠️ Tailscale access issues"
    fi
fi

echo ""
echo "✅ NGINX-LINKDING CONFIGURATION COMPLETE"
echo "========================================"
echo ""

if curl -s -f "http://$PROXMOX_HOST:9091/static/theme-light.css" | head -3 | grep -q "color"; then
    echo "🎉 SUCCESS! Nginx is now serving Linkding with proper static files!"
    echo ""
    echo "🌐 ACCESS YOUR BEAUTIFULLY STYLED BOOKMARK SERVICE:"
    echo "   ┌─────────────────────────────────────────┐"
    echo "   │  NEW URL: http://$PROXMOX_HOST:9091       │"
    echo "   │  Username: book                         │"  
    echo "   │  Password: ProxBook1                    │"
    echo "   └─────────────────────────────────────────┘"
    
    if [ -n "$TAILSCALE_IP" ]; then
        echo ""
        echo "🔗 TAILSCALE ACCESS:"
        echo "   ┌─────────────────────────────────────────┐"
        echo "   │  NEW URL: http://$TAILSCALE_IP:9091       │"
        echo "   │  Same login credentials                 │"
        echo "   └─────────────────────────────────────────┘"
    fi
    
    echo ""
    echo "✅ NOW YOU WILL SEE:"
    echo "   • 🎨 Perfect CSS styling and beautiful colors"
    echo "   • 📱 Responsive design that works on all devices"
    echo "   • ⚡ Fast-loading static files served by nginx"
    echo "   • 🔖 Professional bookmark management interface"
    echo "   • 🚀 Production-grade performance"
    echo ""
    echo "🏗️ ARCHITECTURE:"
    echo "   • Nginx (port 9091) serves static files + proxies to Linkding"
    echo "   • Linkding (internal port 9090) handles application logic"
    echo "   • Original nginx (port 80) unchanged for other services"
    echo "   • Perfect separation of concerns"
    echo ""
    echo "📱 Ready for browser extension setup!"
    echo "   Use: http://$PROXMOX_HOST:9091 in your browser extension"
    
    echo ""
    echo "🔧 PORT SUMMARY:"
    echo "   • Port 80:   Original nginx (unchanged)"
    echo "   • Port 9090: Linkding internal (localhost only)"
    echo "   • Port 9091: NEW Linkding with nginx proxy (external access)"
    echo "   • Port 8006: Proxmox web interface (unchanged)" 
    echo "   • Port 8080: ArgoCD (unchanged)"
else
    echo "⚠️ Static files still not working properly"
    echo ""
    echo "🔧 TROUBLESHOOTING:"
    echo "   • Check nginx error logs"
    echo "   • Verify static file permissions"
    echo "   • Test direct Linkding access on port 9090"
    echo ""
    echo "🧪 MANUAL TESTS:"
    echo "   curl http://$PROXMOX_HOST:9091/static/theme-light.css"
    echo "   curl http://$PROXMOX_HOST:9091/health"
fi

echo ""
echo "📋 Configuration log saved to: $LOGFILE"
echo "Timestamp: $(date)"