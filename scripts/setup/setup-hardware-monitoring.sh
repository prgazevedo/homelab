#!/bin/bash
# Complete Hardware Monitoring Setup - Install node-exporter and configure Prometheus
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/hardware-monitoring-setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🔧 Complete Hardware Monitoring Setup"
echo "====================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

echo "🎯 SETUP OVERVIEW"
echo "=================="
echo ""
echo "This script will:"
echo "1. Install node-exporter on Proxmox host"
echo "2. Configure Prometheus to scrape hardware metrics"
echo "3. Verify data flow from Proxmox → Prometheus → Grafana"
echo "4. Provide access URLs and troubleshooting steps"
echo ""

# Configuration
PROXMOX_HOST="192.168.2.100"
K3S_MASTER="192.168.2.103"
GRAFANA_URL="http://$K3S_MASTER:30030"
PROMETHEUS_URL="http://$K3S_MASTER:30090"

echo "📋 Configuration:"
echo "  Proxmox Host: $PROXMOX_HOST"
echo "  K3s Master: $K3S_MASTER"
echo "  Grafana: $GRAFANA_URL"
echo "  Prometheus: $PROMETHEUS_URL"
echo ""

read -p "Press Enter to continue with hardware monitoring setup..."

echo ""
echo "🚀 STEP 1: INSTALL NODE-EXPORTER ON PROXMOX"
echo "============================================"
echo ""

if [ -f "scripts/setup/install-proxmox-node-exporter.sh" ]; then
    ./scripts/setup/install-proxmox-node-exporter.sh
    if [ $? -eq 0 ]; then
        echo "✅ Node-exporter installation completed"
    else
        echo "❌ Node-exporter installation failed"
        exit 1
    fi
else
    echo "❌ Node-exporter installation script not found"
    exit 1
fi

echo ""
echo "🚀 STEP 2: CONFIGURE PROMETHEUS TARGETS"
echo "======================================="
echo ""

if [ -f "scripts/setup/configure-prometheus-targets.sh" ]; then
    ./scripts/setup/configure-prometheus-targets.sh
    if [ $? -eq 0 ]; then
        echo "✅ Prometheus configuration completed"
    else
        echo "❌ Prometheus configuration failed"
        exit 1
    fi
else
    echo "❌ Prometheus configuration script not found"
    exit 1
fi

echo ""
echo "🚀 STEP 3: VERIFY DATA FLOW"
echo "============================"
echo ""

echo "Waiting for metrics collection to stabilize..."
sleep 30

echo "Testing complete data flow:"
echo ""

# Test 1: Node-exporter on Proxmox
echo "1. 🔧 Testing node-exporter on Proxmox..."
if curl -s --connect-timeout 10 "http://$PROXMOX_HOST:9100/metrics" | grep -q "node_hwmon_temp_celsius"; then
    echo "   ✅ Node-exporter is collecting hardware metrics"
else
    echo "   ❌ Node-exporter is not collecting hardware metrics"
fi

# Test 2: Prometheus scraping
echo "2. 📈 Testing Prometheus scraping..."
if curl -s "http://$K3S_MASTER:30090/api/v1/targets" | grep -q "proxmox-hardware"; then
    echo "   ✅ Prometheus is configured to scrape Proxmox"
else
    echo "   ❌ Prometheus is not configured to scrape Proxmox"
fi

# Test 3: Metrics in Prometheus
echo "3. 📊 Testing metrics availability in Prometheus..."
if curl -s "http://$K3S_MASTER:30090/api/v1/query?query=node_hwmon_temp_celsius" | grep -q '"status":"success"'; then
    echo "   ✅ Hardware metrics are available in Prometheus"
else
    echo "   ⏳ Hardware metrics not yet available (may take a few minutes)"
fi

# Test 4: Grafana accessibility
echo "4. 📊 Testing Grafana accessibility..."
if curl -s --connect-timeout 10 "$GRAFANA_URL" | grep -q "Grafana"; then
    echo "   ✅ Grafana is accessible"
else
    echo "   ❌ Grafana is not accessible"
fi

echo ""

echo "✅ HARDWARE MONITORING SETUP COMPLETE"
echo "====================================="
echo ""

echo "🌐 ACCESS INFORMATION"
echo "===================="
echo ""
echo "📊 Grafana Dashboard:"
echo "   URL: $GRAFANA_URL"
echo "   Username: admin"
echo "   Password: homelab123"
echo ""
echo "📈 Prometheus Metrics:"
echo "   URL: $PROMETHEUS_URL"
echo "   Targets: $PROMETHEUS_URL/targets"
echo ""
echo "🔧 Node Exporter (Proxmox):"
echo "   URL: http://$PROXMOX_HOST:9100/metrics"
echo ""

echo "🚀 NEXT STEPS"
echo "============="
echo ""
echo "1. 📊 Access Grafana and verify dashboard:"
echo "   - Go to: $GRAFANA_URL"
echo "   - Login with admin/homelab123"
echo "   - Navigate to imported dashboard"
echo "   - Verify temperature and fan speed graphs show data"
echo ""
echo "2. 🔍 If dashboard is still empty:"
echo "   - Check Prometheus targets: $PROMETHEUS_URL/targets"
echo "   - Verify Grafana data source points to: http://prometheus:9090"
echo "   - Wait 2-3 minutes for metrics to populate"
echo ""
echo "3. 📈 Monitor your hardware:"
echo "   - CPU temperatures should be visible"
echo "   - Fan speeds should be displayed"
echo "   - Thermal zones will show overall system temperature"
echo ""

echo "🔧 TROUBLESHOOTING"
echo "=================="
echo ""
echo "If the dashboard is still empty after 5 minutes:"
echo ""
echo "1. Check node-exporter on Proxmox:"
echo "   curl http://$PROXMOX_HOST:9100/metrics | grep hwmon"
echo ""
echo "2. Check Prometheus targets:"
echo "   curl http://$K3S_MASTER:30090/api/v1/targets"
echo ""
echo "3. Test Prometheus query:"
echo "   curl \"http://$K3S_MASTER:30090/api/v1/query?query=node_hwmon_temp_celsius\""
echo ""
echo "4. Verify Grafana data source:"
echo "   - Go to Configuration → Data Sources"
echo "   - Ensure Prometheus URL is: http://prometheus:9090"
echo "   - Test & Save the data source"
echo ""

echo "📋 Complete setup log saved: $LOGFILE"
echo ""
echo "🎉 Your hardware monitoring stack is now ready!"