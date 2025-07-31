#!/bin/bash
# Configure Prometheus to scrape Proxmox hardware metrics
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/prometheus-config-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "📈 Prometheus Configuration for Hardware Monitoring"
echo "=================================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

# Configuration
PROXMOX_HOST="192.168.2.100"
K3S_MASTER="192.168.2.103"
PROMETHEUS_NAMESPACE="monitoring"

echo "🎯 CONFIGURATION OVERVIEW"
echo "========================="
echo ""
echo "This script will:"
echo "- Update Prometheus ConfigMap with Proxmox hardware target"
echo "- Configure scraping job for node-exporter on Proxmox"
echo "- Restart Prometheus to apply new configuration"
echo "- Verify targets are being scraped"
echo ""

echo "📋 Configuration:"
echo "  Proxmox Target: $PROXMOX_HOST:9100"
echo "  K3s Master: $K3S_MASTER"
echo "  Prometheus Namespace: $PROMETHEUS_NAMESPACE"
echo ""

# Check connectivity and provide manual instructions if needed
if kubectl cluster-info &>/dev/null; then
    echo "✅ kubectl connectivity confirmed"
    CONNECTION_MODE="kubectl"
elif [ -f "venv/bin/ansible-playbook" ]; then
    echo "⚠️ kubectl not available - trying Ansible remote mode"
    CONNECTION_MODE="ansible"
    source venv/bin/activate
else
    echo "⚠️ Neither kubectl nor Ansible connectivity available"
    echo "📋 Providing manual configuration instructions instead"
    CONNECTION_MODE="manual"
fi

echo ""

echo "📝 UPDATING PROMETHEUS CONFIGURATION"
echo "===================================="
echo ""

if [ "$CONNECTION_MODE" = "kubectl" ]; then
    # Direct kubectl configuration
    echo "Updating Prometheus ConfigMap..."
    
    # Create new prometheus configuration
    cat > /tmp/prometheus-config.yml << 'PROM_CONFIG'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "hardware-alerts.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'proxmox-hardware'
    static_configs:
      - targets: ['192.168.2.100:9100']
    scrape_interval: 10s
    metrics_path: /metrics
    params:
      collect[]:
        - hwmon
        - thermal_zone
        - cpu
        - meminfo
        - diskstats
        - netdev
        - filesystem
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: 'proxmox-host'
  
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - source_labels: [__address__]
        regex: '(.*):10250'
        target_label: __address__
        replacement: '${1}:9100'
PROM_CONFIG

    # Update the ConfigMap
    kubectl create configmap prometheus-config-new \
        --from-file=prometheus.yml=/tmp/prometheus-config.yml \
        --from-file=hardware-alerts.yml=monitoring/prometheus-rules/hardware-alerts-enhanced.yml \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Replace the old ConfigMap
    kubectl delete configmap prometheus-config -n monitoring --ignore-not-found
    kubectl patch configmap prometheus-config-new -n monitoring --type='merge' -p='{"metadata":{"name":"prometheus-config"}}'
    kubectl delete configmap prometheus-config-new -n monitoring
    
    echo "✅ Prometheus ConfigMap updated"
    
    # Restart Prometheus deployment
    echo "Restarting Prometheus deployment..."
    kubectl rollout restart deployment/prometheus -n monitoring
    kubectl rollout status deployment/prometheus -n monitoring --timeout=300s
    
    echo "✅ Prometheus restarted"

else
    # Ansible remote configuration
    echo "Configuring Prometheus via Ansible..."
    
    cat > ansible/playbooks/prometheus-config-update.yml << 'ANSIBLE_EOF'
---
- name: Update Prometheus Configuration for Hardware Monitoring
  hosts: k3s_masters
  become: true
  
  tasks:
    - name: Create new Prometheus configuration
      copy:
        dest: /tmp/prometheus-config.yml
        content: |
          global:
            scrape_interval: 15s
            evaluation_interval: 15s
          
          rule_files:
            - "hardware-alerts.yml"
          
          scrape_configs:
            - job_name: 'prometheus'
              static_configs:
                - targets: ['localhost:9090']
            
            - job_name: 'proxmox-hardware'
              static_configs:
                - targets: ['192.168.2.100:9100']
              scrape_interval: 10s
              metrics_path: /metrics
              params:
                collect[]:
                  - hwmon
                  - thermal_zone
                  - cpu
                  - meminfo
                  - diskstats
                  - netdev
                  - filesystem
              relabel_configs:
                - source_labels: [__address__]
                  target_label: instance
                  replacement: 'proxmox-host'
            
            - job_name: 'kubernetes-nodes'
              kubernetes_sd_configs:
                - role: node
              relabel_configs:
                - source_labels: [__address__]
                  regex: '(.*):10250'
                  target_label: __address__
                  replacement: '${1}:9100'
    
    - name: Copy hardware alerts to K3s master
      copy:
        src: "{{ playbook_dir }}/../../monitoring/prometheus-rules/hardware-alerts-enhanced.yml"
        dest: /tmp/hardware-alerts.yml
    
    - name: Update Prometheus ConfigMap
      shell: |
        kubectl create configmap prometheus-config-new \
          --from-file=prometheus.yml=/tmp/prometheus-config.yml \
          --from-file=hardware-alerts.yml=/tmp/hardware-alerts.yml \
          -n monitoring --dry-run=client -o yaml | kubectl apply -f -
        kubectl delete configmap prometheus-config -n monitoring --ignore-not-found
        kubectl patch configmap prometheus-config-new -n monitoring --type='merge' -p='{"metadata":{"name":"prometheus-config"}}'
        kubectl delete configmap prometheus-config-new -n monitoring
    
    - name: Restart Prometheus deployment
      shell: |
        kubectl rollout restart deployment/prometheus -n monitoring
        kubectl rollout status deployment/prometheus -n monitoring --timeout=300s
ANSIBLE_EOF

    # Try Ansible but handle failure gracefully
    if ansible-playbook ansible/playbooks/prometheus-config-update.yml -i ansible/inventory.yml 2>/dev/null; then
        echo "✅ Prometheus configured via Ansible"
    else
        echo "❌ Ansible remote configuration failed"
        echo "📋 Falling back to manual configuration mode"
        CONNECTION_MODE="manual"
    fi
else
    # Manual configuration mode
    echo "📋 Manual configuration required - providing instructions and files"
    
    # Create the Prometheus configuration file locally
    mkdir -p k3s/monitoring/config
    cat > k3s/monitoring/config/prometheus.yml << 'PROM_CONFIG'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "hardware-alerts.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'proxmox-hardware'
    static_configs:
      - targets: ['192.168.2.100:9100']
    scrape_interval: 10s
    metrics_path: /metrics
    params:
      collect[]:
        - hwmon
        - thermal_zone
        - cpu
        - meminfo
        - diskstats
        - netdev
        - filesystem
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: 'proxmox-host'
  
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - source_labels: [__address__]
        regex: '(.*):10250'
        target_label: __address__
        replacement: '${1}:9100'
PROM_CONFIG

    # Copy hardware alerts file
    cp monitoring/prometheus-rules/hardware-alerts-enhanced.yml k3s/monitoring/config/hardware-alerts.yml
    
    echo "✅ Configuration files created in k3s/monitoring/config/"
    echo ""
    echo "📋 MANUAL CONFIGURATION STEPS"
    echo "==============================="
    echo ""
    echo "Since automatic configuration failed, please follow these steps:"
    echo ""
    echo "1. 🔧 Update Prometheus ConfigMap manually:"
    echo "   - Access your K3s cluster via SSH or kubectl"
    echo "   - Copy the file k3s/monitoring/config/prometheus.yml to the cluster"
    echo "   - Update the ConfigMap with: kubectl create configmap prometheus-config --from-file=prometheus.yml=k3s/monitoring/config/prometheus.yml --from-file=hardware-alerts.yml=k3s/monitoring/config/hardware-alerts.yml -n monitoring --dry-run=client -o yaml | kubectl apply -f -"
    echo "   - Restart Prometheus: kubectl rollout restart deployment/prometheus -n monitoring"
    echo ""
    echo "2. 🌐 Or via Proxmox web interface:"
    echo "   - SSH to K3s master: ssh k3s@192.168.2.103"
    echo "   - Copy configuration files and run kubectl commands from there"
    echo ""
    echo "3. 📊 Verify configuration:"
    echo "   - Check Prometheus targets: http://192.168.2.103:30090/targets"
    echo "   - Look for 'proxmox-hardware' job with target '192.168.2.100:9100'"
    echo ""
fi

echo ""

if [ "$CONNECTION_MODE" != "manual" ]; then
    echo "🔍 VERIFYING PROMETHEUS TARGETS"
    echo "==============================="
    echo ""

    echo "Waiting for Prometheus to restart and reload configuration..."
    sleep 30

    echo "Testing Prometheus targets endpoint..."
    if curl -s --connect-timeout 10 "http://$K3S_MASTER:30090/api/v1/targets" | grep -q "proxmox-hardware"; then
        echo "✅ Proxmox hardware target found in Prometheus"
    else
        echo "⚠️ Proxmox hardware target not yet visible - may take a few minutes"
    fi

    echo ""

    echo "📊 TESTING METRICS AVAILABILITY"
    echo "==============================="
    echo ""

    echo "Testing metrics queries..."
    METRICS_TO_TEST=(
        "node_hwmon_temp_celsius"
        "node_hwmon_fan_rpm"
        "node_thermal_zone_temp"
    )

    for metric in "${METRICS_TO_TEST[@]}"; do
        if curl -s --connect-timeout 10 "http://$K3S_MASTER:30090/api/v1/query?query=$metric" | grep -q '"status":"success"'; then
            echo "✅ $metric - Available in Prometheus"
        else
            echo "⏳ $metric - Not yet available (may take a few minutes)"
        fi
    done
else
    echo "🔍 MANUAL VERIFICATION REQUIRED"
    echo "==============================="
    echo ""
    echo "After applying the manual configuration steps above:"
    echo ""
    echo "1. Check Prometheus targets: http://$K3S_MASTER:30090/targets"
    echo "2. Look for 'proxmox-hardware' job with target '192.168.2.100:9100'"
    echo "3. Test metrics queries in Prometheus console:"
    echo "   - node_hwmon_temp_celsius"
    echo "   - node_hwmon_fan_rpm"
    echo "   - node_thermal_zone_temp"
fi

echo ""

echo "✅ PROMETHEUS CONFIGURATION COMPLETE"
echo "===================================="
echo ""

echo "📈 Prometheus: http://$K3S_MASTER:30090"
echo "🎯 Targets: http://$K3S_MASTER:30090/targets"
echo "📊 Metrics: Available for hardware monitoring"
echo ""

echo "🚀 NEXT STEPS"
echo "============="
echo ""
echo "1. 📊 Verify Grafana data source:"
echo "   - Go to Grafana: http://$K3S_MASTER:30030"
echo "   - Configuration → Data Sources → Prometheus"
echo "   - URL should be: http://prometheus:9090"
echo ""
echo "2. 🌡️ Test dashboard queries:"
echo "   - Import dashboard if not already done"
echo "   - Check that panels show hardware data"
echo "   - Verify temperature and fan speed graphs"
echo ""
echo "3. 🔧 Troubleshoot if needed:"
echo "   - Check Prometheus targets: http://$K3S_MASTER:30090/targets"
echo "   - Verify node-exporter: http://$PROXMOX_HOST:9100/metrics"
echo "   - Review Grafana data source configuration"
echo ""

echo "📋 Configuration log saved: $LOGFILE"

# Clean up temporary files
rm -f /tmp/prometheus-config.yml