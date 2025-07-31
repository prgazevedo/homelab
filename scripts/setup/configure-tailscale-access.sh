#!/bin/bash
# Configure Tailscale Access for Linkding and Other Services
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/configure-tailscale-access-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🔗 Configure Tailscale Access for Homelab Services"
echo "================================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

PROXMOX_HOST="192.168.2.100"

echo "📋 SERVICES TO CONFIGURE"
echo "======================="
echo "• Linkding Bookmarks: http://$PROXMOX_HOST:9090"
echo "• ArgoCD GitOps: http://$PROXMOX_HOST:8080 (if applicable)"
echo "• Additional services on port 8080"
echo ""

echo "🔍 CHECKING TAILSCALE STATUS"
echo "==========================="
echo ""

echo "1. Checking if Tailscale is installed on Proxmox..."
ssh root@$PROXMOX_HOST << 'EOF'
if command -v tailscale >/dev/null 2>&1; then
    echo "✅ Tailscale is installed"
    echo "Current status:"
    tailscale status
    echo ""
    echo "Current IP:"
    tailscale ip -4
else
    echo "❌ Tailscale not found on Proxmox host"
    echo "Installing Tailscale..."
    
    # Install Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
    
    echo "✅ Tailscale installed"
    echo ""
    echo "⚠️  MANUAL STEP REQUIRED:"
    echo "Run: tailscale up"
    echo "Follow the authentication URL to connect this machine to your Tailnet"
fi
EOF

echo ""
echo "🔧 CONFIGURING SERVICE ACCESS"
echo "============================"
echo ""

echo "2. Configuring firewall for Tailscale interface..."
ssh root@$PROXMOX_HOST << 'EOF'
# Get Tailscale IP and interface
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
TAILSCALE_INTERFACE=$(ip route | grep "tailscale" | head -1 | awk '{print $3}' 2>/dev/null || echo "tailscale0")

if [ -n "$TAILSCALE_IP" ]; then
    echo "✅ Tailscale IP: $TAILSCALE_IP"
    echo "✅ Tailscale Interface: $TAILSCALE_INTERFACE"
    
    # Configure UFW rules if UFW is enabled
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        echo "Configuring UFW for Tailscale access..."
        
        # Allow access to Linkding from Tailscale network
        ufw allow in on $TAILSCALE_INTERFACE to any port 9090 comment "Linkding via Tailscale"
        
        # Allow access to port 8080 from Tailscale network  
        ufw allow in on $TAILSCALE_INTERFACE to any port 8080 comment "ArgoCD/Services via Tailscale"
        
        # Allow access to other common ports
        ufw allow in on $TAILSCALE_INTERFACE to any port 3000 comment "Gitea via Tailscale"
        ufw allow in on $TAILSCALE_INTERFACE to any port 8006 comment "Proxmox UI via Tailscale"
        
        echo "✅ UFW rules configured for Tailscale"
        ufw status numbered
    else
        echo "ℹ️  UFW not active or not installed"
    fi
    
    # Configure iptables rules as backup
    echo "Configuring iptables for Tailscale access..."
    
    # Allow Tailscale traffic to services
    iptables -I INPUT -i $TAILSCALE_INTERFACE -p tcp --dport 9090 -j ACCEPT -m comment --comment "Linkding via Tailscale"
    iptables -I INPUT -i $TAILSCALE_INTERFACE -p tcp --dport 8080 -j ACCEPT -m comment --comment "Services via Tailscale"
    iptables -I INPUT -i $TAILSCALE_INTERFACE -p tcp --dport 3000 -j ACCEPT -m comment --comment "Gitea via Tailscale"
    iptables -I INPUT -i $TAILSCALE_INTERFACE -p tcp --dport 8006 -j ACCEPT -m comment --comment "Proxmox UI via Tailscale"
    
    echo "✅ iptables rules configured"
    
else
    echo "❌ Tailscale not connected. Please run 'tailscale up' first"
    exit 1
fi
EOF

echo ""
echo "🧪 TESTING TAILSCALE ACCESS"
echo "=========================="
echo ""

echo "3. Getting Tailscale connection details..."
TAILSCALE_IP=$(ssh root@$PROXMOX_HOST 'tailscale ip -4 2>/dev/null' || echo "")

if [ -n "$TAILSCALE_IP" ]; then
    echo "✅ Proxmox Tailscale IP: $TAILSCALE_IP"
    echo ""
    echo "Testing service access via Tailscale..."
    
    echo "• Testing Linkding (port 9090):"
    if curl -s -f --connect-timeout 5 "http://$TAILSCALE_IP:9090/" > /dev/null 2>&1; then
        echo "  ✅ Linkding accessible via Tailscale"
    else
        echo "  ⚠️  Linkding not accessible (may still be starting)"
    fi
    
    echo "• Testing port 8080:"
    if curl -s -f --connect-timeout 5 "http://$TAILSCALE_IP:8080/" > /dev/null 2>&1; then
        echo "  ✅ Port 8080 accessible via Tailscale"
    else
        echo "  ⚠️  Port 8080 not accessible (service may not be running)"
    fi
    
    echo "• Testing Proxmox UI (port 8006):"
    if curl -s -k --connect-timeout 5 "https://$TAILSCALE_IP:8006/" > /dev/null 2>&1; then
        echo "  ✅ Proxmox UI accessible via Tailscale"
    else
        echo "  ⚠️  Proxmox UI not accessible"
    fi
else
    echo "❌ Could not get Tailscale IP"
fi

echo ""
echo "✅ TAILSCALE ACCESS CONFIGURATION COMPLETE"
echo "=========================================="
echo ""

if [ -n "$TAILSCALE_IP" ]; then
    echo "🌐 ACCESS YOUR SERVICES VIA TAILSCALE:"
    echo "   ┌─────────────────────────────────────────────────────┐"
    echo "   │  Linkding Bookmarks: http://$TAILSCALE_IP:9090       │"
    echo "   │  Port 8080 Service:  http://$TAILSCALE_IP:8080       │"
    echo "   │  Proxmox UI:         https://$TAILSCALE_IP:8006      │"
    echo "   │  Gitea (if running): http://$TAILSCALE_IP:3000       │"
    echo "   └─────────────────────────────────────────────────────┘"
    echo ""
    echo "📱 FROM YOUR REMOTE MAC:"
    echo "   • Make sure Tailscale is running on your Mac"
    echo "   • Access services using the URLs above"
    echo "   • Configure browser extensions with Tailscale URLs"
    echo ""
    echo "🔧 BROWSER EXTENSION SETUP:"
    echo "   • Linkding Extension Server: http://$TAILSCALE_IP:9090"
    echo "   • Username: book"
    echo "   • Password: ProxBook1"
    echo ""
    echo "🚀 BENEFITS:"
    echo "   ✅ Secure access from anywhere"
    echo "   ✅ No port forwarding needed"
    echo "   ✅ Encrypted Tailscale tunnel"
    echo "   ✅ Access from any device in your Tailnet"
else
    echo "⚠️  Tailscale configuration incomplete"
    echo ""
    echo "📋 MANUAL STEPS REQUIRED:"
    echo "1. SSH to Proxmox: ssh root@$PROXMOX_HOST"
    echo "2. Connect to Tailscale: tailscale up"
    echo "3. Follow authentication URL"
    echo "4. Re-run this script"
fi

echo ""
echo "📋 Configuration log saved to: $LOGFILE"
echo "Timestamp: $(date)"