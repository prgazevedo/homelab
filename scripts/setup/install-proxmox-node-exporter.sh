#!/bin/bash
# Install and configure node-exporter on Proxmox for hardware monitoring
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/proxmox-node-exporter-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🔧 Proxmox Node Exporter Installation"
echo "====================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

# Configuration
PROXMOX_HOST="192.168.2.100"
PROXMOX_USER="root"
NODE_EXPORTER_PORT="9100"

echo "🎯 INSTALLATION OVERVIEW"
echo "========================"
echo ""
echo "This script will:"
echo "- Install prometheus-node-exporter on Proxmox host"
echo "- Enable hardware monitoring collectors (hwmon, thermal_zone)"
echo "- Configure systemd service for automatic startup"
echo "- Verify metrics collection is working"
echo ""

echo "📋 Configuration:"
echo "  Proxmox Host: $PROXMOX_HOST"
echo "  Node Exporter Port: $NODE_EXPORTER_PORT"
echo "  Hardware collectors: hwmon, thermal_zone, cpu, meminfo"
echo ""

# Test SSH connectivity to Proxmox
echo "🔗 Testing SSH connectivity to Proxmox..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes "$PROXMOX_USER@$PROXMOX_HOST" exit 2>/dev/null; then
    echo "✅ SSH connectivity verified"
    SSH_MODE="automatic"
else
    echo "⚠️ Cannot connect to Proxmox host via SSH automatically"
    echo "📋 Will provide manual installation instructions"
    SSH_MODE="manual"
fi
echo ""

echo "📦 INSTALLING NODE EXPORTER"
echo "============================"
echo ""

if [ "$SSH_MODE" = "automatic" ]; then
    # Install node-exporter on Proxmox automatically
    echo "Installing prometheus-node-exporter package via SSH..."
    ssh "$PROXMOX_USER@$PROXMOX_HOST" << 'SSH_COMMANDS'
set -e

echo "Updating package lists..."
apt update -qq

echo "Installing prometheus-node-exporter..."
apt install -y prometheus-node-exporter

echo "Configuring node-exporter service..."
# Create custom systemd override to enable specific collectors
mkdir -p /etc/systemd/system/prometheus-node-exporter.service.d

cat > /etc/systemd/system/prometheus-node-exporter.service.d/override.conf << 'SYSTEMD_OVERRIDE'
[Service]
# Override default ExecStart to enable specific hardware collectors
ExecStart=
ExecStart=/usr/bin/prometheus-node-exporter \
    --web.listen-address=0.0.0.0:9100 \
    --collector.hwmon \
    --collector.thermal_zone \
    --collector.cpu \
    --collector.meminfo \
    --collector.diskstats \
    --collector.filesystem \
    --collector.netdev \
    --collector.loadavg \
    --collector.uname \
    --collector.time \
    --no-collector.arp \
    --no-collector.bcache \
    --no-collector.bonding \
    --no-collector.conntrack \
    --no-collector.edac \
    --no-collector.entropy \
    --no-collector.fibrechannel \
    --no-collector.filefd \
    --no-collector.infiniband \
    --no-collector.ipvs \
    --no-collector.mdadm \
    --no-collector.netclass \
    --no-collector.netstat \
    --no-collector.nfs \
    --no-collector.nfsd \
    --no-collector.powersupplyclass \
    --no-collector.pressure \
    --no-collector.rapl \
    --no-collector.schedstat \
    --no-collector.sockstat \
    --no-collector.softnet \
    --no-collector.stat \
    --no-collector.textfile \
    --no-collector.timex \
    --no-collector.udp_queues \
    --no-collector.vmstat \
    --no-collector.xfs \
    --no-collector.zfs
SYSTEMD_OVERRIDE

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling and starting node-exporter service..."
systemctl enable prometheus-node-exporter
systemctl restart prometheus-node-exporter

echo "Checking service status..."
systemctl is-active prometheus-node-exporter
systemctl is-enabled prometheus-node-exporter

echo "Node exporter installation completed!"
SSH_COMMANDS

    echo "✅ Node exporter installed and configured via SSH"

else
    # Manual installation mode
    echo "📋 Manual installation required. Please run these commands on Proxmox ($PROXMOX_HOST):"
    echo ""
    echo "# SSH to Proxmox host:"
    echo "ssh root@$PROXMOX_HOST"
    echo ""
    echo "# Then run these commands on Proxmox:"
    
    # Create installation script file for manual execution
    cat > scripts/setup/proxmox-node-exporter-install.sh << 'MANUAL_SCRIPT'
#!/bin/bash
# Run this script on Proxmox host to install node-exporter
set -e

echo "Updating package lists..."
apt update -qq

echo "Installing prometheus-node-exporter..."
apt install -y prometheus-node-exporter

echo "Configuring node-exporter service..."
# Create custom systemd override to enable specific collectors
mkdir -p /etc/systemd/system/prometheus-node-exporter.service.d

cat > /etc/systemd/system/prometheus-node-exporter.service.d/override.conf << 'SYSTEMD_OVERRIDE'
[Service]
# Override default ExecStart to enable specific hardware collectors
ExecStart=
ExecStart=/usr/bin/prometheus-node-exporter \
    --web.listen-address=0.0.0.0:9100 \
    --collector.hwmon \
    --collector.thermal_zone \
    --collector.cpu \
    --collector.meminfo \
    --collector.diskstats \
    --collector.filesystem \
    --collector.netdev \
    --collector.loadavg \
    --collector.uname \
    --collector.time \
    --no-collector.arp \
    --no-collector.bcache \
    --no-collector.bonding \
    --no-collector.conntrack \
    --no-collector.edac \
    --no-collector.entropy \
    --no-collector.fibrechannel \
    --no-collector.filefd \
    --no-collector.infiniband \
    --no-collector.ipvs \
    --no-collector.mdadm \
    --no-collector.netclass \
    --no-collector.netstat \
    --no-collector.nfs \
    --no-collector.nfsd \
    --no-collector.powersupplyclass \
    --no-collector.pressure \
    --no-collector.rapl \
    --no-collector.schedstat \
    --no-collector.sockstat \
    --no-collector.softnet \
    --no-collector.stat \
    --no-collector.textfile \
    --no-collector.timex \
    --no-collector.udp_queues \
    --no-collector.vmstat \
    --no-collector.xfs \
    --no-collector.zfs
SYSTEMD_OVERRIDE

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling and starting node-exporter service..."
systemctl enable prometheus-node-exporter
systemctl restart prometheus-node-exporter

echo "Checking service status..."
systemctl is-active prometheus-node-exporter
systemctl is-enabled prometheus-node-exporter

echo "Node exporter installation completed!"
MANUAL_SCRIPT

    chmod +x scripts/setup/proxmox-node-exporter-install.sh
    
    echo ""
    echo "📋 Manual installation steps:"
    echo "1. Copy the script to Proxmox: scp scripts/setup/proxmox-node-exporter-install.sh root@$PROXMOX_HOST:/tmp/"
    echo "2. SSH to Proxmox: ssh root@$PROXMOX_HOST"
    echo "3. Run the script: bash /tmp/proxmox-node-exporter-install.sh"
    echo ""
    echo "✅ Manual installation script created: scripts/setup/proxmox-node-exporter-install.sh"
fi
echo ""

if [ "$SSH_MODE" = "automatic" ]; then
    echo "🌡️ VERIFYING HARDWARE METRICS"
    echo "=============================="
    echo ""

    # Test metrics endpoint
    echo "Testing metrics endpoint..."
    METRICS_OUTPUT=$(curl -s --connect-timeout 10 "http://$PROXMOX_HOST:$NODE_EXPORTER_PORT/metrics" 2>/dev/null)
    if [ -n "$METRICS_OUTPUT" ] && echo "$METRICS_OUTPUT" | grep -q "TYPE.*gauge\|TYPE.*counter"; then
        echo "First 10 lines of metrics output:"
        echo "$METRICS_OUTPUT" | head -10
        echo ""
        echo "✅ Node exporter is responding"
    else
        echo "❌ Node exporter is not responding"
        exit 1
    fi

    echo ""
    echo "🔍 Checking for hardware metrics..."

    # Check for specific hardware metrics
    HARDWARE_METRICS=(
        "node_hwmon_temp_celsius"
        "node_hwmon_fan_rpm"
        "node_thermal_zone_temp"
        "node_cpu_seconds_total"
        "node_memory_MemTotal_bytes"
    )

    for metric in "${HARDWARE_METRICS[@]}"; do
        if echo "$METRICS_OUTPUT" | grep -q "^$metric"; then
            echo "✅ $metric - Available"
        else
            echo "⚠️  $metric - Not found"
        fi
    done

    echo ""

    echo "📊 SAMPLE HARDWARE DATA"
    echo "======================="
    echo ""

    echo "Temperature sensors:"
    echo "$METRICS_OUTPUT" | grep "node_hwmon_temp_celsius" | head -5

    echo ""
    echo "Fan speeds:"
    echo "$METRICS_OUTPUT" | grep "node_hwmon_fan_rpm" | head -5

    echo ""
    echo "Thermal zones:"
    echo "$METRICS_OUTPUT" | grep "node_thermal_zone_temp" | head -5
else
    echo "🌡️ MANUAL VERIFICATION REQUIRED"
    echo "==============================="
    echo ""
    echo "After running the installation script on Proxmox, verify with:"
    echo ""
    echo "1. Test metrics endpoint:"
    echo "   curl http://$PROXMOX_HOST:$NODE_EXPORTER_PORT/metrics | head -20"
    echo ""
    echo "2. Check for hardware metrics:"
    echo "   curl http://$PROXMOX_HOST:$NODE_EXPORTER_PORT/metrics | grep node_hwmon_temp_celsius"
    echo "   curl http://$PROXMOX_HOST:$NODE_EXPORTER_PORT/metrics | grep node_hwmon_fan_rpm"
    echo "   curl http://$PROXMOX_HOST:$NODE_EXPORTER_PORT/metrics | grep node_thermal_zone_temp"
    echo ""
    echo "3. Check service status on Proxmox:"
    echo "   systemctl status prometheus-node-exporter"
fi

echo ""

echo "✅ NODE EXPORTER INSTALLATION COMPLETE"
echo "======================================"
echo ""

echo "📊 Metrics endpoint: http://$PROXMOX_HOST:$NODE_EXPORTER_PORT/metrics"
echo "🌡️ Hardware monitoring: Enabled"
echo "🔧 Service status: $(ssh "$PROXMOX_USER@$PROXMOX_HOST" systemctl is-active prometheus-node-exporter)"
echo ""

echo "🚀 NEXT STEPS"
echo "============="
echo ""
echo "1. 📈 Configure Prometheus to scrape this endpoint:"
echo "   - Add target: $PROXMOX_HOST:$NODE_EXPORTER_PORT"
echo "   - Verify scraping in Prometheus targets page"
echo ""
echo "2. 📊 Check Grafana dashboard:"
echo "   - Ensure Prometheus data source is configured"
echo "   - Verify dashboard queries are receiving data"
echo ""
echo "3. 🔧 Test hardware monitoring:"
echo "   curl http://$PROXMOX_HOST:$NODE_EXPORTER_PORT/metrics | grep hwmon"
echo ""

echo "📋 Installation log saved: $LOGFILE"