#!/bin/bash
# Analyze All Available Sensors and Their Values
# Identifies useful vs problematic/meaningless sensors
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/analyze-all-sensors-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🔍 Complete Sensor Analysis"
echo "============================"
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

K3S_MASTER="192.168.2.103"
PROMETHEUS_PORT="30090"
PROMETHEUS_URL="http://$K3S_MASTER:$PROMETHEUS_PORT"

echo "📋 Configuration:"
echo "  Prometheus: $PROMETHEUS_URL"
echo ""

echo "🌡️ TEMPERATURE SENSORS ANALYSIS"
echo "================================"
echo ""

echo "All temperature sensors:"
TEMP_RESULT=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=node_hwmon_temp_celsius" 2>/dev/null)
echo "$TEMP_RESULT" | jq -r '.data.result[] | "\(.metric.chip) - \(.metric.sensor): \(.value[1])°C"' | sort | while read -r line; do
    TEMP_VALUE=$(echo "$line" | grep -o '[0-9.-]*°C' | sed 's/°C//')
    
    if (( $(echo "$TEMP_VALUE > 100" | bc -l) )); then
        echo "❌ BOGUS: $line (impossible temperature)"
    elif (( $(echo "$TEMP_VALUE < 1" | bc -l) )); then
        echo "❌ ZERO/LOW: $line (likely inactive sensor)"
    elif (( $(echo "$TEMP_VALUE > 85" | bc -l) )); then
        echo "⚠️ HIGH: $line"
    elif (( $(echo "$TEMP_VALUE > 70" | bc -l) )); then
        echo "🟡 WARM: $line"
    else
        echo "✅ GOOD: $line"
    fi
done

echo ""
echo "🌀 FAN SENSORS ANALYSIS"
echo "======================="
echo ""

echo "All fan sensors:"
FAN_RESULT=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=node_hwmon_fan_rpm" 2>/dev/null)
echo "$FAN_RESULT" | jq -r '.data.result[] | "\(.metric.chip) - \(.metric.sensor): \(.value[1]) RPM"' | sort | while read -r line; do
    RPM_VALUE=$(echo "$line" | grep -o '[0-9.-]*' | tail -1)
    
    if (( $(echo "$RPM_VALUE == 0" | bc -l) )); then
        echo "❌ INACTIVE: $line (fan not running/connected)"
    elif (( $(echo "$RPM_VALUE < 500" | bc -l) )); then
        echo "🟡 LOW: $line"
    elif (( $(echo "$RPM_VALUE > 3000" | bc -l) )); then
        echo "⚠️ HIGH: $line"
    else
        echo "✅ GOOD: $line"
    fi
done

echo ""
echo "💾 DISK USAGE ANALYSIS"
echo "======================"
echo ""

echo "All filesystem usage:"
DISK_RESULT=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=(1%20-%20(node_filesystem_avail_bytes%7Bfstype!%3D%22tmpfs%22%7D%20/%20node_filesystem_size_bytes%7Bfstype!%3D%22tmpfs%22%7D))%20*%20100" 2>/dev/null)
echo "$DISK_RESULT" | jq -r '.data.result[] | "\(.metric.mountpoint): \(.value[1])%"' | sort | while read -r line; do
    USAGE_VALUE=$(echo "$line" | grep -o '[0-9.-]*%' | sed 's/%//')
    MOUNTPOINT=$(echo "$line" | cut -d: -f1)
    
    if (( $(echo "$USAGE_VALUE > 90" | bc -l) )); then
        echo "🚨 CRITICAL: $line"
    elif (( $(echo "$USAGE_VALUE > 70" | bc -l) )); then
        echo "⚠️ HIGH: $line"
    elif (( $(echo "$USAGE_VALUE > 10" | bc -l) )); then
        echo "✅ GOOD: $line"
    elif [[ "$MOUNTPOINT" == *"tmpfs"* ]] || [[ "$MOUNTPOINT" == *"proc"* ]] || [[ "$MOUNTPOINT" == *"sys"* ]]; then
        echo "❌ SYSTEM: $line (virtual filesystem)"
    else
        echo "🟡 LOW: $line (might be valid or empty)"
    fi
done

echo ""
echo "📊 OTHER INTERESTING SENSORS"
echo "============================"
echo ""

# Check for voltage sensors
echo "Voltage sensors:"
VOLTAGE_RESULT=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=node_hwmon_in_volts" 2>/dev/null)
if echo "$VOLTAGE_RESULT" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "$VOLTAGE_RESULT" | jq -r '.data.result[] | "\(.metric.chip) - \(.metric.sensor): \(.value[1])V"' | sort
else
    echo "  No voltage sensors found"
fi

echo ""

# Check for current sensors
echo "Current sensors:"
CURRENT_RESULT=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=node_hwmon_curr_amps" 2>/dev/null)
if echo "$CURRENT_RESULT" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "$CURRENT_RESULT" | jq -r '.data.result[] | "\(.metric.chip) - \(.metric.sensor): \(.value[1])A"' | sort
else
    echo "  No current sensors found"
fi

echo ""

# Check for power sensors
echo "Power sensors:"
POWER_RESULT=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=node_hwmon_power_watts" 2>/dev/null)
if echo "$POWER_RESULT" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "$POWER_RESULT" | jq -r '.data.result[] | "\(.metric.chip) - \(.metric.sensor): \(.value[1])W"' | sort
else
    echo "  No power sensors found"
fi

echo ""

# Check for frequency sensors
echo "Frequency sensors:"
FREQ_RESULT=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=node_cpu_frequency_hertz" 2>/dev/null)
if echo "$FREQ_RESULT" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "$FREQ_RESULT" | jq -r '.data.result[] | "CPU \(.metric.cpu): \(.value[1]) Hz"' | head -5
    echo "  ... (showing first 5 CPUs)"
else
    echo "  No CPU frequency sensors found"
fi

echo ""

# Check for thermal zones
echo "Thermal zones:"
THERMAL_RESULT=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=node_thermal_zone_temp" 2>/dev/null)
if echo "$THERMAL_RESULT" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "$THERMAL_RESULT" | jq -r '.data.result[] | "Zone \(.metric.zone): \(.value[1])°C"' | sort
else
    echo "  No thermal zones found"
fi

echo ""

# Check network stats
echo "Network interface stats (sample):"
NETWORK_RESULT=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=node_network_speed_bytes" 2>/dev/null)
if echo "$NETWORK_RESULT" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "$NETWORK_RESULT" | jq -r '.data.result[] | "\(.metric.device): \(.value[1]) bytes/s max"' | head -5
else
    echo "  No network speed info found"
fi

echo ""
echo "🎯 RECOMMENDATIONS"
echo "=================="
echo ""

echo "Based on the analysis above, here are the recommended sensors to include:"
echo ""

echo "✅ KEEP THESE SENSORS:"
echo "  Temperature:"
echo "    - NVMe sensors (actual hardware temperatures)"
echo "    - Any sensor between 20-85°C (realistic range)"
echo ""
echo "  Fans:"
echo "    - Fans with RPM > 0 (actually running)"
echo "    - Skip fan4, fan3, etc. if they show 0 RPM"
echo ""
echo "  Disk Usage:"
echo "    - /rpool/data/subvol-200-disk-0 (your main data)"
echo "    - Any mount with > 10% usage"
echo "    - Skip: /var/lib/lxcfs, /proc, /sys, tmpfs mounts"
echo ""

echo "❌ FILTER OUT THESE:"
echo "  Temperature:"
echo "    - wmi_bus sensors with impossible values (>100°C or <1°C)"
echo "    - temp5 with 215°C reading"
echo ""
echo "  Fans:"
echo "    - Any fan showing 0 RPM (not connected/not working)"
echo ""
echo "  Disk Usage:"
echo "    - Virtual filesystems (lxcfs, proc, sys, tmpfs)"
echo "    - Very low usage mounts (< 5%)"
echo ""

echo "🚀 SUGGESTED DASHBOARD QUERIES:"
echo "==============================="
echo ""

echo "Temperature (filtered):"
echo "  node_hwmon_temp_celsius{chip=\"nvme_nvme0\"} > 0 < 100"
echo ""

echo "Fans (active only):"
echo "  node_hwmon_fan_rpm > 0"
echo ""

echo "Disk Usage (meaningful mounts only):"
echo "  (1 - (node_filesystem_avail_bytes{mountpoint=\"/rpool/data/subvol-200-disk-0\"} / node_filesystem_size_bytes{mountpoint=\"/rpool/data/subvol-200-disk-0\"})) * 100"
echo ""

echo "✅ SENSOR ANALYSIS COMPLETE"
echo "==========================="
echo ""
echo "📋 Analysis log saved to: $LOGFILE"
echo "🔍 Use the recommendations above to create a refined dashboard"
echo "🚀 Focus on sensors that provide meaningful hardware monitoring data"
echo ""
echo "Timestamp: $(date)"