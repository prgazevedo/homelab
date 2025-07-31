#!/bin/bash
# Grafana-Prometheus Hardware Monitoring Diagnostic Script
# Identifies why Grafana dashboards are not showing hardware metrics
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/grafana-prometheus-debug-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🔍 Grafana-Prometheus Hardware Monitoring Debug"
echo "=============================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

# Configuration
K3S_MASTER="192.168.2.103"
K3S_USER="k3s"
PROXMOX_HOST="192.168.2.100"
GRAFANA_PORT="30030"
PROMETHEUS_PORT="30090"

echo "🎯 DIAGNOSTIC OVERVIEW"
echo "======================"
echo ""
echo "This script will diagnose why Grafana dashboards show no data:"
echo "1. Check Prometheus connectivity and targets"
echo "2. Verify node-exporter is running on Proxmox"
echo "3. Test hardware metrics collection"
echo "4. Check Grafana data source configuration"
echo "5. Validate dashboard queries"
echo ""

echo "📋 Configuration:"
echo "  K3s Master: $K3S_MASTER"
echo "  Proxmox Host: $PROXMOX_HOST"
echo "  Grafana URL: http://$K3S_MASTER:$GRAFANA_PORT"
echo "  Prometheus URL: http://$K3S_MASTER:$PROMETHEUS_PORT"
echo ""

echo "🔗 STEP 1: PROMETHEUS CONNECTIVITY TEST"
echo "========================================"
echo ""

echo "Testing Prometheus API endpoint..."
if curl -s --connect-timeout 10 "http://$K3S_MASTER:$PROMETHEUS_PORT/api/v1/query?query=up" > /dev/null; then
    echo "✅ Prometheus API is responding"
    
    echo ""
    echo "Checking Prometheus targets status..."
    TARGETS_OUTPUT=$(curl -s "http://$K3S_MASTER:$PROMETHEUS_PORT/api/v1/targets" 2>/dev/null || echo "failed")
    if [ "$TARGETS_OUTPUT" != "failed" ]; then
        echo "Targets API response (first 200 chars):"
        echo "$TARGETS_OUTPUT" | head -c 200
        echo "..."
        echo ""
        
        # Check if proxmox-hardware target is healthy
        if echo "$TARGETS_OUTPUT" | grep -q "proxmox-hardware"; then
            echo "✅ proxmox-hardware target found"
            if echo "$TARGETS_OUTPUT" | grep -q '"health":"up"'; then
                echo "✅ proxmox-hardware target is UP"
            else
                echo "❌ proxmox-hardware target is DOWN"
            fi
        else
            echo "❌ proxmox-hardware target not found"
        fi
    else
        echo "❌ Cannot get targets status from Prometheus"
    fi
else
    echo "❌ Prometheus API is not responding"
fi
echo ""

echo "🌡️ STEP 2: NODE-EXPORTER VERIFICATION"
echo "======================================"
echo ""

echo "Testing direct connection to Proxmox node-exporter..."
if curl -s --connect-timeout 10 "http://$PROXMOX_HOST:9100/metrics" > /dev/null; then
    echo "✅ Node-exporter is responding on Proxmox"
    
    echo ""
    echo "Checking for hardware metrics..."
    METRICS_OUTPUT=$(curl -s "http://$PROXMOX_HOST:9100/metrics" 2>/dev/null)
    
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
            COUNT=$(echo "$METRICS_OUTPUT" | grep "^$metric" | wc -l)
            echo "✅ $metric - Found ($COUNT metrics)"
        else
            echo "❌ $metric - Not found"
        fi
    done
    
    echo ""
    echo "Sample temperature data:"
    echo "$METRICS_OUTPUT" | grep "node_hwmon_temp_celsius" | head -3
    
    echo ""
    echo "Sample fan data:"
    echo "$METRICS_OUTPUT" | grep "node_hwmon_fan_rpm" | head -3
    
else
    echo "❌ Node-exporter is not responding on Proxmox"
    echo "💡 You may need to install or configure node-exporter"
    echo "💡 Try running: ./scripts/setup/install-proxmox-node-exporter.sh"
fi
echo ""

echo "📊 STEP 3: PROMETHEUS METRICS VERIFICATION"
echo "==========================================="
echo ""

echo "Testing hardware metrics in Prometheus..."

# Test specific queries from the dashboard
DASHBOARD_QUERIES=(
    "node_hwmon_temp_celsius{chip=\"coretemp-isa-0000\"}"
    "node_hwmon_fan_rpm"
    "node_thermal_zone_temp"
    "up{job=\"proxmox-hardware\"}"
)

for query in "${DASHBOARD_QUERIES[@]}"; do
    echo "Testing query: $query"
    ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$query'))")
    RESULT=$(curl -s "http://$K3S_MASTER:$PROMETHEUS_PORT/api/v1/query?query=$ENCODED_QUERY" 2>/dev/null || echo "failed")
    
    if [ "$RESULT" != "failed" ]; then
        # Check if result contains data
        if echo "$RESULT" | grep -q '"status":"success"' && echo "$RESULT" | grep -q '"result":\['; then
            DATA_COUNT=$(echo "$RESULT" | grep -o '"result":\[' | wc -l)
            if echo "$RESULT" | grep -q '"result":\[\]'; then
                echo "  ⚠️  Query successful but no data returned"
            else
                echo "  ✅ Query successful with data"
            fi
        else
            echo "  ❌ Query failed or returned error"
        fi
    else
        echo "  ❌ Cannot execute query"
    fi
done
echo ""

echo "🎨 STEP 4: GRAFANA DATA SOURCE CHECK"
echo "====================================="
echo ""

echo "Testing Grafana connectivity..."
if curl -s --connect-timeout 10 "http://$K3S_MASTER:$GRAFANA_PORT" > /dev/null; then
    echo "✅ Grafana is responding"
    echo "🌐 Grafana URL: http://$K3S_MASTER:$GRAFANA_PORT"
else
    echo "❌ Grafana is not responding"
    echo "💡 Check if Grafana service is running in K3s"
fi
echo ""

echo "🔍 STEP 5: ANALYSIS AND RECOMMENDATIONS"
echo "========================================"
echo ""

echo "📊 Based on the diagnostic results:"
echo ""

# Analyze results and provide recommendations
echo "🔧 LIKELY ISSUES AND SOLUTIONS:"
echo ""

echo "1. If Prometheus is not responding:"
echo "   - Check if Prometheus pod is running: kubectl get pods -n monitoring"
echo "   - Check Prometheus logs: kubectl logs -n monitoring deployment/prometheus"
echo ""

echo "2. If node-exporter is not responding:"
echo "   - Install node-exporter on Proxmox: ./scripts/setup/install-proxmox-node-exporter.sh"
echo "   - Check Proxmox firewall settings for port 9100"
echo ""

echo "3. If hardware metrics are missing:"
echo "   - Ensure hwmon collector is enabled in node-exporter"
echo "   - Check if hardware sensors are available on Proxmox"
echo "   - Run: sensors command on Proxmox to verify hardware monitoring"
echo ""

echo "4. If Prometheus can't scrape metrics:"
echo "   - Check Prometheus configuration and targets"
echo "   - Verify network connectivity between K3s and Proxmox"
echo "   - Check if Prometheus ConfigMap is properly mounted"
echo ""

echo "5. If Grafana shows no data:"
echo "   - Verify Prometheus data source is configured in Grafana"
echo "   - Check that data source URL points to Prometheus service"
echo "   - Ensure dashboard queries match available metric names"
echo ""

echo "📋 NEXT STEPS BASED ON RESULTS:"
echo ""
echo "Review the diagnostic output above and focus on the failed checks."
echo "The most common issues are:"
echo "- Node-exporter not installed on Proxmox"
echo "- Prometheus not configured to scrape Proxmox"
echo "- Grafana data source misconfigured"
echo ""

echo "✅ DIAGNOSTIC COMPLETE"
echo "======================"
echo ""
echo "📋 Full diagnostic log saved to: $LOGFILE"
echo "🔍 Review the results above to identify the specific issue"
echo "🚀 Run the suggested commands based on the failed checks"
echo ""
echo "Timestamp: $(date)"