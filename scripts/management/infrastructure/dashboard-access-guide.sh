#!/bin/bash
# Dashboard Access Guide - How to view hardware monitoring dashboards
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/dashboard-access-guide-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "📊 Hardware Monitoring Dashboard Access Guide"
echo "============================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

echo "🎯 AVAILABLE DASHBOARD OPTIONS"
echo "=============================="
echo ""

echo "1. 📈 GRAFANA DASHBOARD (Recommended)"
echo "====================================="
echo ""

echo "The hardware monitoring dashboard was created as a Grafana JSON file:"
echo "📄 File: monitoring/grafana-dashboards/proxmox-hardware-monitoring.json"
echo ""

echo "📊 Dashboard Features:"
echo "- CPU temperature monitoring with color-coded thresholds"
echo "- System fan speed monitoring"
echo "- RTX2080 GPU temperature and fan speed"
echo "- Thermal zone monitoring"
echo "- Historical data and trends"
echo "- Real-time updates every 30 seconds"
echo ""

echo "🔧 TO ACCESS GRAFANA DASHBOARD:"
echo "------------------------------"
echo ""

if kubectl cluster-info &>/dev/null; then
    echo "✅ K3s cluster is accessible"
    echo ""
    
    echo "Option A: Port Forward to Grafana (if deployed in K3s)"
    echo "kubectl port-forward -n monitoring svc/grafana 3000:3000"
    echo "Then access: http://localhost:3000"
    echo ""
    
    echo "Option B: Direct Grafana Access (if external)"
    echo "If Grafana is running on a specific node:"
    echo "http://192.168.2.103:3000  # K3s master node"
    echo "http://192.168.2.104:3000  # Worker node 1"
    echo "http://192.168.2.105:3000  # Worker node 2"
    echo ""
    
else
    echo "❌ K3s cluster not accessible from this machine"
    echo "Access Grafana directly via:"
    echo "http://192.168.2.103:3000  # If running on K3s master"
    echo "http://192.168.2.104:3000  # If running on worker 1"
    echo "http://192.168.2.105:3000  # If running on worker 2"
    echo ""
fi

echo "📋 GRAFANA SETUP STEPS:"
echo "1. Access Grafana web interface"
echo "2. Login (default: admin/admin, then change password)"
echo "3. Go to Dashboards → Import"
echo "4. Upload file: monitoring/grafana-dashboards/proxmox-hardware-monitoring.json"
echo "5. Configure data source: Prometheus (http://prometheus:9090)"
echo ""

echo "2. 🖥️ PROMETHEUS METRICS (Raw Data)"
echo "==================================="
echo ""

echo "Direct access to metrics via Prometheus:"
echo "http://192.168.2.103:9090  # If Prometheus is on K3s master"
echo ""

echo "📊 Key Hardware Metrics to Query:"
echo "- node_hwmon_temp_celsius          # CPU/GPU temperatures"
echo "- node_hwmon_fan_rpm               # Fan speeds"  
echo "- node_thermal_zone_temp           # Thermal zones"
echo "- node_cpu_seconds_total           # CPU usage"
echo "- node_memory_MemAvailable_bytes   # Memory usage"
echo ""

echo "3. 🌡️ COMMAND LINE MONITORING"
echo "============================="
echo ""

echo "Quick hardware status via homelab commands:"
echo "./homelab-unified.sh hardware status"
echo "./homelab-unified.sh hardware temps"
echo "./homelab-unified.sh gpu status"
echo ""

echo "Direct SSH to Proxmox for real-time sensors:"
echo "ssh root@192.168.2.100 'watch sensors'"
echo ""

echo "4. 📱 CUSTOM MONITORING PAGE"
echo "============================"
echo ""

echo "Create a custom monitoring page with embedded dashboards:"
echo ""

cat << 'CUSTOM_PAGE'
# Create custom monitoring page
ssh root@192.168.2.100 << 'EOF'
mkdir -p /var/www/html/monitoring
cat > /var/www/html/monitoring/hardware.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Homelab Hardware Monitoring</title>
    <style>
        body { margin: 0; padding: 0; background: #1a1a1a; color: white; font-family: Arial, sans-serif; }
        .header { background: #333; padding: 20px; text-align: center; }
        .nav { background: #444; padding: 10px; text-align: center; }
        .nav a { color: white; margin: 0 15px; text-decoration: none; padding: 8px 16px; background: #555; border-radius: 4px; }
        .nav a:hover { background: #666; }
        .dashboard { display: flex; flex-wrap: wrap; gap: 20px; padding: 20px; }
        .panel { background: #2a2a2a; border-radius: 8px; padding: 15px; flex: 1; min-width: 300px; }
        .metric { font-size: 2em; color: #4CAF50; margin: 10px 0; }
        .iframe-container { width: 100%; height: 600px; margin: 20px 0; }
        iframe { width: 100%; height: 100%; border: none; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏠 Homelab Hardware Monitoring</h1>
        <p>Real-time temperature and performance monitoring</p>
    </div>
    
    <div class="nav">
        <a href="https://192.168.2.100:8006" target="_blank">📊 Proxmox</a>
        <a href="http://192.168.2.200:3000" target="_blank">🔧 Forgejo</a>
        <a href="http://192.168.2.103:30880" target="_blank">🚀 ArgoCD</a>
        <a href="http://192.168.2.103:9090" target="_blank">📈 Prometheus</a>
    </div>
    
    <div class="dashboard">
        <div class="panel">
            <h3>🌡️ Temperature Status</h3>
            <div id="temp-data">Loading...</div>
        </div>
        
        <div class="panel">
            <h3>💨 Fan Status</h3>
            <div id="fan-data">Loading...</div>
        </div>
        
        <div class="panel">
            <h3>🎮 GPU Status</h3>
            <div id="gpu-data">RTX2080 Monitoring</div>
        </div>
    </div>
    
    <!-- Embed Grafana Dashboard -->
    <div class="iframe-container">
        <iframe src="http://YOUR_GRAFANA_IP:3000/d/proxmox-hardware?refresh=30s&kiosk=tv"></iframe>
    </div>

    <script>
        // Auto-refresh every 30 seconds
        setInterval(() => location.reload(), 30000);
    </script>
</body>
</html>
HTML

# Install nginx if not already installed
apt install -y nginx
systemctl enable nginx
systemctl start nginx

echo "Custom monitoring page created: http://192.168.2.100/monitoring/hardware.html"
EOF

CUSTOM_PAGE

echo ""

echo "5. 📋 CHECKING DEPLOYMENT STATUS"
echo "================================"
echo ""

echo "Check what files were created by the deployment:"
echo ""

if [ -f "monitoring/node-exporter-hardware.yml" ]; then
    echo "✅ Node-exporter config: monitoring/node-exporter-hardware.yml"
else
    echo "❌ Node-exporter config: Not found"
fi

if [ -f "monitoring/prometheus-rules/hardware-alerts-enhanced.yml" ]; then
    echo "✅ Hardware alerts: monitoring/prometheus-rules/hardware-alerts-enhanced.yml"
else
    echo "❌ Hardware alerts: Not found"
fi

if [ -f "monitoring/grafana-dashboards/proxmox-hardware-monitoring.json" ]; then
    echo "✅ Grafana dashboard: monitoring/grafana-dashboards/proxmox-hardware-monitoring.json"
    echo "   Dashboard panels: $(grep -c '"id":' monitoring/grafana-dashboards/proxmox-hardware-monitoring.json) panels"
else
    echo "❌ Grafana dashboard: Not found"
fi

if [ -f "hardware-monitoring-state.yml" ]; then
    echo "✅ Hardware state: hardware-monitoring-state.yml"
    echo "   Contains: Proxmox node status and deployment info"
else
    echo "❌ Hardware state: Not found"
fi

echo ""

echo "6. 🎯 NEXT STEPS CHECKLIST"
echo "=========================="
echo ""

echo "To get full hardware monitoring working:"
echo ""

echo "☐ 1. Deploy Grafana (if not already running)"
echo "   kubectl apply -f k3s/monitoring/grafana-deployment.yml"
echo ""

echo "☐ 2. Install node-exporter on Proxmox host"
echo "   ssh root@192.168.2.100 'apt install prometheus-node-exporter'"
echo ""

echo "☐ 3. Enable sensor modules on Proxmox (if not done)"
echo "   ./enable-proxmox-temps.sh"
echo ""

echo "☐ 4. Import Grafana dashboard"
echo "   - Access Grafana web interface"
echo "   - Import monitoring/grafana-dashboards/proxmox-hardware-monitoring.json"
echo ""

echo "☐ 5. Configure Prometheus to scrape Proxmox"
echo "   - Add Proxmox host (192.168.2.100:9100) to Prometheus targets"
echo ""

echo "☐ 6. Test dashboard access"
echo "   - Verify temperature data appears"
echo "   - Check fan speed monitoring"
echo "   - Confirm GPU metrics (if available)"
echo ""

echo "✅ DASHBOARD ACCESS GUIDE COMPLETE"
echo "=================================="
echo ""

echo "📊 Your hardware monitoring infrastructure is ready!"
echo "📁 Dashboard file: monitoring/grafana-dashboards/proxmox-hardware-monitoring.json"
echo "🔧 Management: ./homelab-unified.sh hardware status"
echo "📋 Guide saved: $LOGFILE"
echo ""

echo "🚀 Start with: ./homelab-unified.sh hardware dashboard"