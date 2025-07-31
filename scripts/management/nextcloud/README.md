# Nextcloud Cloud File Service Management

This directory contains management scripts for the Nextcloud cloud file service deployed on the Proxmox host.

## Service Overview

- **URL**: http://192.168.2.100:9092
- **Login**: admin / NextJourney1
- **WebDAV API**: http://192.168.2.100:9092/remote.php/dav/
- **Storage**: /storage/nextcloud-data/ (on Proxmox host)
- **Application**: /opt/nextcloud/ (on Proxmox host)

## Architecture

- **Frontend**: Nginx reverse proxy (port 9092)
- **Backend**: PHP-FPM 8.2 (unix socket)
- **Database**: SQLite (local file)
- **Host**: Proxmox server (192.168.2.100)

## Management Scripts

### `nextcloud-management.sh`
Main management script for Nextcloud operations.

```bash
# Show service status and health
./nextcloud-management.sh status

# Restart services (nginx + PHP-FPM)
./nextcloud-management.sh restart

# View recent logs
./nextcloud-management.sh logs

# Toggle maintenance mode
./nextcloud-management.sh maintenance

# Test WebDAV API
./nextcloud-management.sh webdav-test

# Show help
./nextcloud-management.sh help
```

### `test-webdav-api.sh`
Comprehensive WebDAV API testing and documentation script.

```bash
# Run full WebDAV API test suite
./test-webdav-api.sh
```

Tests include:
- File listing (PROPFIND)
- File upload (PUT)
- File download (GET)
- Directory creation (MKCOL)
- File deletion (DELETE)
- JSONL Claude Code files integration

## Use Cases

### 1. Remote File Access
Access files and videos from anywhere via Tailscale VPN:
- Web interface: http://192.168.2.100:9092
- Mobile apps: Nextcloud mobile app
- Desktop sync: Nextcloud desktop client

### 2. JSONL Claude Code Files Repository
Store and manage Claude Code session files programmatically:

```bash
# Upload session file
curl -u admin:NextJourney1 -T session-20250801.jsonl \
  http://192.168.2.100:9092/remote.php/dav/files/admin/claude-sessions/session-20250801.jsonl

# Download for analysis
curl -u admin:NextJourney1 \
  http://192.168.2.100:9092/remote.php/dav/files/admin/claude-sessions/session-20250801.jsonl \
  -o session-20250801.jsonl

# List all sessions
curl -u admin:NextJourney1 -X PROPFIND \
  http://192.168.2.100:9092/remote.php/dav/files/admin/claude-sessions/ \
  -H "Depth: 1"
```

### 3. Application Integration
Any application can use the WebDAV API for file storage:

```python
import requests
from requests.auth import HTTPBasicAuth

# Upload file via Python
with open('myfile.txt', 'rb') as f:
    response = requests.put(
        'http://192.168.2.100:9092/remote.php/dav/files/admin/myfile.txt',
        data=f,
        auth=HTTPBasicAuth('admin', 'NextJourney1')
    )
```

## Troubleshooting

### Common Issues

1. **503 Service Unavailable**
   - Check PHP-FPM service: `systemctl status php8.2-fpm`
   - Restart services: `./nextcloud-management.sh restart`

2. **403 Forbidden on Dashboard**
   - This was fixed in the deployment - nginx routing issue
   - Check nginx config: `/etc/nginx/sites-available/nextcloud`

3. **CSS/Styling Issues**
   - Clear browser cache (hard refresh: Cmd+Shift+R)
   - Check theming CSS: `curl http://192.168.2.100:9092/apps/theming/theme/light.css`

4. **WebDAV API Issues**
   - Test with curl: `./nextcloud-management.sh webdav-test`
   - Check authentication credentials
   - Verify file permissions: `/storage/nextcloud-data/`

### Service Dependencies

- **Nginx**: Must be running and configured properly
- **PHP-FPM**: PHP 8.2 FPM service with Nextcloud pool
- **File System**: `/storage/nextcloud-data/` must be accessible
- **Network**: Port 9092 must be open

### Logs and Diagnostics

```bash
# Service logs
./nextcloud-management.sh logs

# System service status
systemctl status nginx php8.2-fpm

# Nginx configuration test
nginx -t

# Disk usage
df -h /storage/nextcloud-data/

# File permissions
ls -la /opt/nextcloud/
ls -la /storage/nextcloud-data/
```

## Integration with Homelab

The Nextcloud service integrates with the broader homelab infrastructure:

- **Tailscale VPN**: Remote access from anywhere
- **Monitoring**: Service health checks via homelab-unified.sh
- **Backup**: Data directory backup strategies
- **Security**: Isolated from K3s cluster, dedicated nginx config

For homelab-wide management, use:
```bash
# From project root
./homelab-unified.sh nextcloud status
./homelab-unified.sh nextcloud restart
```