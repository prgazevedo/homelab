# Nextcloud File Service Deployment Guide

## Overview
This guide documents the complete Nextcloud file service deployment on the Proxmox host, following the proven Linkding architecture pattern for maximum reliability and performance.

## Architecture Summary

### Service Design
- **Location**: Direct installation on Proxmox host (192.168.2.100)
- **Pattern**: Nginx reverse proxy + PHP backend (same as Linkding)
- **External Port**: 9092 (nginx proxy)
- **Internal Port**: 9093 (PHP-FPM backend)
- **Database**: PostgreSQL (nextcloud/NextcloudDB2025!)
- **Storage**: /storage/nextcloud-data/ (configurable location)

### Port Allocation
```
Current Service Layout:
├── Port 80:   Original nginx (Proxmox/other services)
├── Port 9090: Linkding internal (Django backend)
├── Port 9091: Linkding external (nginx proxy) ✅ WORKING
├── Port 9092: Nextcloud external (nginx proxy) 🆕 NEW
└── Port 9093: Nextcloud internal (PHP-FPM) 🆕 NEW
```

## Deployment Process

### 1. Automated Deployment
```bash
# Complete 3-step deployment
./homelab-unified.sh nextcloud deploy

# This runs:
# 1. ./scripts/setup/deploy-nextcloud-proxmox-host.sh
# 2. ./scripts/setup/configure-nginx-nextcloud.sh  
# 3. ./scripts/setup/setup-nextcloud-service.sh
```

### 2. Manual Step-by-Step (if needed)
```bash
# Step 1: Install Nextcloud and dependencies
./scripts/setup/deploy-nextcloud-proxmox-host.sh

# Step 2: Configure nginx reverse proxy
./scripts/setup/configure-nginx-nextcloud.sh

# Step 3: Setup systemd services
./scripts/setup/setup-nextcloud-service.sh
```

## Initial Configuration

### 1. Web Setup
1. Open http://192.168.2.100:9092 in browser
2. Complete initial Nextcloud setup wizard:
   - **Admin Username**: Choose admin username
   - **Admin Password**: Strong password
   - **Database**: PostgreSQL
   - **Database Host**: localhost
   - **Database Name**: nextcloud
   - **Database User**: nextcloud  
   - **Database Password**: NextcloudDB2025!
   - **Data Directory**: /storage/nextcloud-data

### 2. Post-Setup Tasks
```bash
# Start background services after web setup
ssh root@192.168.2.100 'systemctl start nextcloud-cron.timer'

# Verify everything is working
./homelab-unified.sh nextcloud status
./homelab-unified.sh nextcloud health
```

## Management Commands

### Daily Operations
```bash
# Service status and health
./homelab-unified.sh nextcloud status        # Quick status check
./homelab-unified.sh nextcloud health        # Comprehensive health check

# Service logs and troubleshooting  
./homelab-unified.sh nextcloud logs          # View service logs
./homelab-unified.sh nextcloud restart       # Restart all services

# Backup and maintenance
./homelab-unified.sh nextcloud backup        # Create complete backup
./homelab-unified.sh nextcloud occ status    # Nextcloud internal commands
```

### API Testing
```bash
# Test WebDAV API (update credentials in script first)
./homelab-unified.sh nextcloud test-api

# Direct API testing examples
curl -u 'admin:password' -T file.txt \
  'http://192.168.2.100:9092/remote.php/dav/files/admin/file.txt'
```

## Use Cases Implementation

### 1. Remote File Access
- **Web Interface**: http://192.168.2.100:9092
- **Tailscale Access**: http://TAILSCALE_IP:9092  
- **Mobile Apps**: Official Nextcloud apps with server URL
- **Desktop Sync**: Nextcloud desktop client

### 2. Video/Media Access
- **Streaming**: Built-in Nextcloud media player
- **Large Files**: Optimized nginx configuration for media
- **Remote Access**: Full media library via Tailscale

### 3. Application Integration
```bash
# Claude Code JSONL storage
curl -u 'username:password' -T session.jsonl \
  'http://192.168.2.100:9092/remote.php/dav/files/username/claude-code/session.jsonl'

# Automated backups
curl -u 'username:password' -T backup.tar.gz \
  'http://192.168.2.100:9092/remote.php/dav/files/username/backups/backup.tar.gz'

# Development files
curl -u 'username:password' \
  'http://192.168.2.100:9092/remote.php/dav/files/username/projects/code.py' \
  -o local_code.py
```

## Security Configuration

### 1. User Management
```bash
# Create additional users via web interface or occ
./homelab-unified.sh nextcloud occ user:add developer

# Generate app passwords for API access
# Web Interface: Settings → Personal → Security → App passwords
```

### 2. Tailscale Integration
- Nextcloud automatically accessible via existing Tailscale setup
- Same firewall rules as Linkding (already configured)
- No additional configuration needed

## Monitoring and Maintenance

### 1. Health Monitoring
```bash
# Automated diagnostics
./scripts/diagnostic/diagnose-nextcloud-service.sh

# Manual health checks
curl http://192.168.2.100:9092/nginx-health
systemctl status php8.1-fpm nginx postgresql
```

### 2. Backup Strategy
```bash
# Automated backup (creates date-stamped archives)
./scripts/management/infrastructure/nextcloud-manager.sh backup

# Backup includes:
# - Application files (/opt/nextcloud)
# - User data (/storage/nextcloud-data)  
# - PostgreSQL database dump
# - Configuration files
```

### 3. Log Monitoring
```bash
# Service logs
journalctl -u php8.1-fpm -f
tail -f /var/log/nginx/error.log
tail -f /opt/nextcloud/data/nextcloud.log

# System monitoring integration
# (Extends existing Prometheus/Grafana stack)
```

## Troubleshooting

### Common Issues
1. **Service not accessible**: Check nginx and PHP-FPM status
2. **Database connection errors**: Verify PostgreSQL service and credentials
3. **File upload issues**: Check PHP upload limits and disk space
4. **API authentication**: Verify user credentials and app passwords

### Diagnostic Tools
```bash
# Comprehensive diagnostics
./scripts/diagnostic/diagnose-nextcloud-service.sh

# API functionality testing
./scripts/diagnostic/test-nextcloud-webdav.sh

# Service logs
./scripts/management/infrastructure/nextcloud-manager.sh logs
```

## Architecture Benefits

### 1. Proven Pattern
- Same architecture as successful Linkding deployment
- Production-grade nginx reverse proxy
- Internal service isolation for security

### 2. Resource Efficiency
- Direct host installation (no container overhead)
- Shared nginx infrastructure
- Optimized PHP-FPM configuration

### 3. Integration
- Unified management via homelab-unified.sh
- Consistent with existing service architecture
- Tailscale ready for remote access
- Monitoring integration with existing stack

## Success Metrics

### ✅ Completed Features
- [x] Complete Nextcloud installation with PostgreSQL
- [x] Nginx reverse proxy with static file optimization
- [x] PHP-FPM backend with proper configuration  
- [x] Systemd service integration
- [x] WebDAV API functionality
- [x] Tailscale remote access
- [x] Unified management commands
- [x] Comprehensive diagnostics
- [x] Backup automation
- [x] Documentation integration

### 🎯 Ready for Use
- **Web Interface**: Fully functional with proper CSS/JS
- **API Access**: Complete WebDAV implementation
- **Remote Access**: Tailscale integration working
- **File Operations**: Upload, download, streaming, sharing
- **Client Support**: Web, mobile, desktop applications
- **Maintenance**: Automated backups and monitoring

This deployment provides a production-ready, self-hosted cloud storage solution that addresses all specified use cases while maintaining security and integration with the existing homelab infrastructure.