#!/bin/bash
# Check Forgejo repositories and user access
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/check-forgejo-repos-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "🔍 Checking Forgejo Repositories and Access"
echo "==========================================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

# Check if virtual environment exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

echo "1. Check Forgejo service status:"
ansible proxmox -i ansible/inventory.yml -m shell -a "pct exec 200 -- systemctl status forgejo --no-pager"
echo ""

echo "2. Check if Forgejo is listening on port 3000:"
ansible proxmox -i ansible/inventory.yml -m shell -a "pct exec 200 -- ss -tlnp | grep :3000"
echo ""

echo "3. Test HTTP access to main page:"
curl -s -I http://192.168.2.200:3000 | head -5
echo ""

echo "4. Check Forgejo database for users:"
ansible proxmox -i ansible/inventory.yml -m shell -a "pct exec 200 -- sqlite3 /var/lib/forgejo/forgejo.db 'SELECT id, name, login_name FROM user;'"
echo ""

echo "5. Check Forgejo database for repositories:"
ansible proxmox -i ansible/inventory.yml -m shell -a "pct exec 200 -- sqlite3 /var/lib/forgejo/forgejo.db 'SELECT id, owner_id, name, is_private FROM repository;'"
echo ""

echo "6. List files in repository directory:"
ansible proxmox -i ansible/inventory.yml -m shell -a "pct exec 200 -- ls -la /var/lib/forgejo/repositories/"
echo ""

echo "7. Check Forgejo configuration:"
ansible proxmox -i ansible/inventory.yml -m shell -a "pct exec 200 -- cat /etc/forgejo/app.ini | grep -A5 -B5 -E '(DOMAIN|ROOT_URL|HTTP_PORT)'"
echo ""

echo "8. Test API access:"
echo "Testing API endpoints..."
curl -s http://192.168.2.200:3000/api/v1/version || echo "API access failed"
echo ""

echo "9. Check recent Forgejo logs:"
ansible proxmox -i ansible/inventory.yml -m shell -a "pct exec 200 -- journalctl -u forgejo --no-pager -n 20"
echo ""

echo "10. Test different repository URLs:"
echo "Testing various URL formats..."
curl -s -I http://192.168.2.200:3000/prgazevedo/homelab-infra | head -3
curl -s -I http://192.168.2.200:3000/prgazevedo/homelab-infra.git | head -3
curl -s -I http://192.168.2.200:3000/api/v1/repos/prgazevedo/homelab-infra | head -3
echo ""

echo "📋 ANALYSIS"
echo "==========="
echo ""
echo "Check the output above for:"
echo "1. User 'prgazevedo' exists in the database"
echo "2. Repository 'homelab-infra' exists and is owned by the user"
echo "3. Repository directory structure"
echo "4. Any authentication or permission issues in logs"
echo ""
echo "💡 Common issues:"
echo "- Repository not properly imported/mirrored"
echo "- User permissions problem"
echo "- Repository name mismatch"
echo "- Authentication configuration issue"