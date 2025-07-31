#!/bin/bash
# Configure Proxmox Hardware Sensors (Temperature and Fan Speed Monitoring)
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/proxmox-sensors-setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🌡️ Proxmox Hardware Sensors Configuration"
echo "=========================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

echo "⚠️  IMPORTANT: This script must be run ON the Proxmox host (192.168.2.100)"
echo "SSH to Proxmox: ssh root@192.168.2.100"
echo "Then run the commands below manually or copy this script to Proxmox"
echo ""

echo "📋 PROXMOX SENSOR SETUP COMMANDS"
echo "================================="
echo ""

cat << 'PROXMOX_COMMANDS'
# 1. Update package list
apt update

# 2. Install hardware monitoring tools
apt install -y lm-sensors fancontrol

# 3. Detect hardware sensors
sensors-detect --auto

# 4. Load sensor modules (usually detected automatically)
modprobe coretemp      # CPU temperature
modprobe it87          # Common motherboard sensor chip
modprobe nct6775       # Another common sensor chip

# 5. Test sensor detection
sensors

# 6. Install additional monitoring tools
apt install -y smartmontools  # Disk temperature monitoring
apt install -y hddtemp        # Hard drive temperature

# 7. Configure sensor modules to load at boot
echo "# Hardware monitoring modules" >> /etc/modules
echo "coretemp" >> /etc/modules
echo "it87" >> /etc/modules
echo "nct6775" >> /etc/modules

# 8. Update initramfs to include modules
update-initramfs -u

# 9. Restart to load all modules
echo "🔄 Reboot required to load all sensor modules"
echo "After reboot, check: sensors"

PROXMOX_COMMANDS

echo ""
echo "🔧 POST-SETUP VERIFICATION"
echo "=========================="
echo ""

cat << 'VERIFICATION_COMMANDS'
# After running the setup commands above and rebooting:

# 1. Check if sensors are working
sensors

# Expected output should show:
# - CPU core temperatures (coretemp-isa-0000)
# - Motherboard temperatures
# - Fan speeds (RPM)
# - Voltages

# 2. Check loaded sensor modules
lsmod | grep -E "(coretemp|it87|nct6775)"

# 3. Check disk temperatures
hddtemp /dev/sda /dev/sdb  # Adjust disk names as needed

# 4. Monitor sensors in real-time
watch sensors

VERIFICATION_COMMANDS

echo ""
echo "🖥️  COMMON SENSOR CHIPS AND MODULES"
echo "==================================="
echo ""

cat << 'SENSOR_INFO'
Common sensor chips and their modules:

CPU Temperature:
- Intel: coretemp
- AMD: k10temp

Motherboard Sensors:
- ITE IT8728F/IT8792E: it87
- Nuvoton NCT6775/NCT6776: nct6775
- Fintek F71869A: f71882fg
- ASUS motherboards: asus_atk0110

To identify your specific chip:
1. Run: sensors-detect
2. Check motherboard manual
3. Look at BIOS hardware monitor section

SENSOR_INFO

echo ""
echo "🚨 TROUBLESHOOTING"
echo "=================="
echo ""

cat << 'TROUBLESHOOTING'
If sensors command shows "No sensors found":

1. Check if modules are loaded:
   lsmod | grep -E "(coretemp|it87|nct6775)"

2. Manually load modules:
   modprobe coretemp
   modprobe it87
   modprobe nct6775

3. Re-run sensor detection:
   sensors-detect --auto

4. Check dmesg for sensor-related messages:
   dmesg | grep -E "(coretemp|it87|nct6775|sensors)"

5. For newer Intel CPUs, try:
   modprobe coretemp

6. For AMD CPUs, try:
   modprobe k10temp

7. Check BIOS settings:
   - Enable "Hardware Monitor"
   - Enable "Smart Fan Control"
   - Disable "Silent Mode" if present

TROUBLESHOOTING

echo ""
echo "🎯 INTEGRATION WITH PROXMOX WEB GUI"
echo "==================================="
echo ""

cat << 'PROXMOX_INTEGRATION'
After sensor setup, Proxmox web GUI will show temperatures:

1. Location: Node → Hardware → (refresh page)
2. Look for: Temperature sensors, Fan sensors
3. Data appears in: Node summary dashboard

If sensors don't appear in Proxmox GUI after setup:
1. Restart pvestatd service: systemctl restart pvestatd
2. Clear browser cache and refresh
3. Check Proxmox logs: journalctl -u pvestatd

PROXMOX_INTEGRATION

echo ""
echo "📊 MONITORING INTEGRATION"
echo "========================="
echo ""

cat << 'MONITORING_INTEGRATION'
After Proxmox sensor setup, integrate with monitoring stack:

1. Install node-exporter on Proxmox:
   apt install prometheus-node-exporter
   systemctl enable prometheus-node-exporter
   systemctl start prometheus-node-exporter

2. Deploy homelab hardware monitoring:
   ./homelab-unified.sh hardware deploy

3. Configure Prometheus to scrape Proxmox:
   # Add to prometheus.yml:
   - job_name: 'proxmox-hardware'
     static_configs:
       - targets: ['192.168.2.100:9100']

4. Import Grafana dashboard:
   monitoring/grafana-dashboards/proxmox-hardware-monitoring.json

MONITORING_INTEGRATION

echo ""
echo "✅ SETUP SUMMARY"
echo "================"
echo ""

echo "📝 Manual Steps Required:"
echo "1. SSH to Proxmox host: ssh root@192.168.2.100"
echo "2. Run the sensor setup commands above"
echo "3. Reboot Proxmox host"
echo "4. Verify sensors with: sensors"
echo "5. Check Proxmox web GUI: Node → Hardware"
echo ""

echo "🔗 Quick Setup Command for Proxmox:"
echo "ssh root@192.168.2.100 'apt update && apt install -y lm-sensors && sensors-detect --auto && sensors'"
echo ""

echo "📋 This script has created a complete setup guide."
echo "Copy the commands to your Proxmox host to enable hardware monitoring."
echo ""

echo "🚀 After sensor setup, run: ./homelab-unified.sh hardware deploy"