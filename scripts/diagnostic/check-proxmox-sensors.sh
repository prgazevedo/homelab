#!/bin/bash
# Diagnostic script to check Proxmox hardware sensors and GUI visibility
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/proxmox-sensors-diagnostic-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🔍 Proxmox Hardware Sensors Diagnostic"
echo "======================================"
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

echo "📊 CHECKING SENSOR STATUS ON PROXMOX HOST"
echo "=========================================="
echo ""

echo "🔗 Connecting to Proxmox host (192.168.2.100)..."
echo ""

# Check sensor status on Proxmox host
ssh root@192.168.2.100 << 'EOF'
echo "🌡️ Hardware Sensor Detection Results:"
echo "====================================="
echo ""

echo "1. 📦 Checking installed sensor packages:"
dpkg -l | grep -E "(lm-sensors|fancontrol)" || echo "❌ Sensor packages not found"
echo ""

echo "2. 🔧 Checking loaded sensor modules:"
lsmod | grep -E "(coretemp|it87|nct6775|k10temp|w83627)" || echo "❌ No sensor modules loaded"
echo ""

echo "3. 🌡️ Current sensor readings:"
if command -v sensors >/dev/null 2>&1; then
    sensors 2>/dev/null || echo "❌ sensors command failed"
else
    echo "❌ sensors command not available"
fi
echo ""

echo "4. 🖥️ CPU temperature via thermal zones:"
if [ -d "/sys/class/thermal" ]; then
    echo "Available thermal zones:"
    for zone in /sys/class/thermal/thermal_zone*; do
        if [ -r "$zone/type" ] && [ -r "$zone/temp" ]; then
            type=$(cat "$zone/type" 2>/dev/null)
            temp=$(cat "$zone/temp" 2>/dev/null)
            if [ -n "$temp" ] && [ "$temp" != "0" ]; then
                temp_c=$((temp / 1000))
                echo "  $type: ${temp_c}°C"
            fi
        fi
    done
else
    echo "❌ No thermal zones found"
fi
echo ""

echo "5. 🔍 Hardware monitoring device files:"
ls -la /dev/hwmon* 2>/dev/null || echo "❌ No hwmon devices found"
echo ""

echo "6. 📋 Available sensor chips:"
if command -v sensors >/dev/null 2>&1; then
    sensors-detect --auto 2>/dev/null | grep -E "(Found|Chip)" || echo "❌ No chips detected"
else
    echo "❌ sensors-detect not available"
fi
echo ""

echo "7. 🔄 Proxmox services status:"
systemctl status pvestatd --no-pager -l || echo "❌ pvestatd service issues"
echo ""

echo "8. 📊 Proxmox hardware monitoring:"
if [ -f /proc/sys/kernel/hostname ]; then
    hostname=$(cat /proc/sys/kernel/hostname)
    echo "Hostname: $hostname"
fi

# Check if Proxmox can see the sensors
if command -v pvesh >/dev/null 2>&1; then
    echo "Proxmox sensor data:"
    pvesh get /nodes/$(hostname)/status 2>/dev/null | grep -E "(cpu|temp)" || echo "❌ No temperature data in Proxmox API"
else
    echo "❌ pvesh command not available"
fi

EOF

echo ""
echo "🖥️ PROXMOX WEB GUI NAVIGATION GUIDE"
echo "===================================="
echo ""

cat << 'GUI_GUIDE'
The Hardware tab location depends on your Proxmox version:

📍 Proxmox VE 7.x and 8.x:
1. Login to: https://192.168.2.100:8006
2. In the left panel, click on your node name (usually "proxmox")
3. Look for these tabs in the main content area:
   - Summary (shows basic CPU/Memory info)
   - Shell
   - Hardware (this is what we're looking for)
   - Disks
   - Network
   - DNS
   - Hosts
   - Time
   - Certificates

📍 If Hardware tab is missing:
- The tab might not be visible if no hardware sensors are detected
- Try refreshing the page (Ctrl+F5)
- Check browser console for JavaScript errors (F12)

📍 Alternative locations for sensor data:
1. Node → Summary tab (may show basic temperatures)
2. Node → Shell tab → run: sensors
3. Datacenter → Metric Server (if configured)

GUI_GUIDE

echo ""
echo "🔧 TROUBLESHOOTING STEPS"
echo "========================"
echo ""

cat << 'TROUBLESHOOTING'
If sensors are working in SSH but not in Proxmox GUI:

1. 🔄 Restart Proxmox services:
   ssh root@192.168.2.100 'systemctl restart pvestatd pvedaemon'

2. 🧹 Clear browser cache and cookies for Proxmox

3. 🔍 Check Proxmox logs:
   ssh root@192.168.2.100 'journalctl -u pvestatd -f'

4. 🌡️ Force sensor module loading:
   ssh root@192.168.2.100 'modprobe coretemp it87 nct6775'

5. 📊 Check if Proxmox API has sensor data:
   ssh root@192.168.2.100 'pvesh get /nodes/$(hostname)/status'

6. 🔧 Try different sensor modules for your motherboard:
   ssh root@192.168.2.100 'sensors-detect'

TROUBLESHOOTING

echo ""
echo "⚡ QUICK SENSOR TEST"
echo "==================="
echo ""

echo "Testing basic sensor functionality..."
ssh root@192.168.2.100 'sensors 2>/dev/null | head -20' || echo "❌ Sensor test failed"

echo ""
echo "🎯 RECOMMENDATIONS"
echo "=================="
echo ""

echo "Based on diagnostic results:"
echo "1. If sensors command works in SSH → Hardware monitoring is functional"
echo "2. If Hardware tab is missing → This is normal in some Proxmox versions"
echo "3. Temperature data may appear in Node → Summary instead"
echo "4. Use SSH access for detailed sensor readings: ssh root@192.168.2.100 'sensors'"
echo ""

echo "📈 For comprehensive monitoring, proceed with:"
echo "./homelab-unified.sh hardware deploy"
echo ""

echo "✅ Diagnostic complete. Check log file: $LOGFILE"