#!/bin/bash
# Create Linkding User and Personal Access Token (PAT)
set -euo pipefail

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up logging
LOGFILE="logs/create-linkding-user-token-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "👤 Create Linkding User and PAT"
echo "==============================="
echo "Log file: $LOGFILE"
echo "Timestamp: $(date)"
echo ""

PROXMOX_HOST="192.168.2.100"
USERNAME="${1:-book}"
PASSWORD="${2:-ProxBook1}"
TOKEN_NAME="${3:-api-token}"

echo "📋 USER CREATION DETAILS"
echo "======================="
echo "• Username: $USERNAME"
echo "• Password: $PASSWORD"
echo "• Token Name: $TOKEN_NAME"
echo "• Target: Linkding at http://$PROXMOX_HOST:9090"
echo ""

echo "👤 CREATING USER"
echo "==============="
echo ""

echo "1. Creating user '$USERNAME'..."
ssh root@$PROXMOX_HOST << EOF
sudo -u linkding bash << 'USER_EOF'
cd /opt/linkding/linkding
source venv/bin/activate

export DJANGO_SETTINGS_MODULE=bookmarks.settings

echo "Creating user '$USERNAME'..."
python manage.py shell << 'PYTHON_EOF'
from django.contrib.auth import get_user_model
User = get_user_model()

# Check if user already exists
username = '$USERNAME'
if User.objects.filter(username=username).exists():
    print(f'⚠️  User {username} already exists, updating password...')
    user = User.objects.get(username=username)
    user.set_password('$PASSWORD')
    user.save()
    print(f'✅ Updated password for user: {username}')
else:
    # Create new user
    user = User.objects.create_user(
        username=username,
        email=f'{username}@localhost',
        password='$PASSWORD'
    )
    print(f'✅ Created new user: {username}')

print(f'User ID: {user.id}')
print(f'Email: {user.email}')
print(f'Active: {user.is_active}')
print(f'Staff: {user.is_staff}')
PYTHON_EOF

echo "✅ User creation completed"
USER_EOF
EOF

echo ""
echo "🔑 CREATING PERSONAL ACCESS TOKEN"
echo "================================"
echo ""

echo "2. Generating PAT for user '$USERNAME'..."
ssh root@$PROXMOX_HOST << EOF
sudo -u linkding bash << 'USER_EOF'
cd /opt/linkding/linkding
source venv/bin/activate

export DJANGO_SETTINGS_MODULE=bookmarks.settings

echo "Creating Personal Access Token..."
python manage.py shell << 'PYTHON_EOF'
from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token
import secrets
import string

User = get_user_model()

try:
    user = User.objects.get(username='$USERNAME')
    
    # Delete existing token if it exists
    Token.objects.filter(user=user).delete()
    
    # Create new token
    token = Token.objects.create(user=user)
    
    print('✅ Personal Access Token created successfully!')
    print(f'Token: {token.key}')
    print(f'User: {user.username}')
    print(f'Created: {token.created}')
    
except User.DoesNotExist:
    print('❌ User not found!')
    
except Exception as e:
    print(f'❌ Error creating token: {e}')
PYTHON_EOF

echo "✅ Token generation completed"
USER_EOF
EOF

echo ""
echo "🧪 TESTING API ACCESS"
echo "===================="
echo ""

echo "3. Testing API access with new token..."

# Get the token from the database for testing
TOKEN=$(ssh root@$PROXMOX_HOST << 'EOF'
sudo -u linkding bash << 'USER_EOF'
cd /opt/linkding/linkding
source venv/bin/activate
export DJANGO_SETTINGS_MODULE=bookmarks.settings
python manage.py shell << 'PYTHON_EOF'
from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token
User = get_user_model()
try:
    user = User.objects.get(username='book')
    token = Token.objects.get(user=user)
    print(token.key)
except:
    print('ERROR')
PYTHON_EOF
USER_EOF
EOF
)

if [ "$TOKEN" != "ERROR" ] && [ -n "$TOKEN" ]; then
    echo "Testing API endpoints..."
    
    echo ""
    echo "• Testing API health:"
    curl -s -H "Authorization: Token $TOKEN" "http://$PROXMOX_HOST:9090/api/health/" || echo "Health endpoint test failed"
    
    echo ""
    echo "• Testing bookmarks list:"
    curl -s -H "Authorization: Token $TOKEN" "http://$PROXMOX_HOST:9090/api/bookmarks/" | head -200 || echo "Bookmarks endpoint test failed"
    
    echo ""
    echo "✅ API access test completed"
else
    echo "❌ Could not retrieve token for testing"
fi

echo ""
echo "✅ USER AND TOKEN CREATION COMPLETE"
echo "=================================="
echo ""
echo "🎉 SUCCESS! User and PAT created successfully!"
echo ""
echo "📋 USER DETAILS:"
echo "   ┌─────────────────────────────────────────┐"
echo "   │  Username: $USERNAME                          │"
echo "   │  Password: $PASSWORD                        │"
echo "   │  Web URL:  http://$PROXMOX_HOST:9090     │"
echo "   └─────────────────────────────────────────┘"
echo ""

if [ "$TOKEN" != "ERROR" ] && [ -n "$TOKEN" ]; then
echo "🔑 API ACCESS TOKEN:"
echo "   ┌─────────────────────────────────────────┐"
echo "   │  Token: $TOKEN  │"
echo "   │  API URL: http://$PROXMOX_HOST:9090/api/ │"
echo "   └─────────────────────────────────────────┘"
echo ""
echo "🚀 API USAGE EXAMPLES:"
echo "   # Get bookmarks"
echo "   curl -H \"Authorization: Token $TOKEN\" http://$PROXMOX_HOST:9090/api/bookmarks/"
echo ""
echo "   # Add bookmark"
echo "   curl -X POST -H \"Authorization: Token $TOKEN\" \\"
echo "        -H \"Content-Type: application/json\" \\"
echo "        -d '{\"url\":\"https://example.com\",\"title\":\"Example\"}' \\"
echo "        http://$PROXMOX_HOST:9090/api/bookmarks/"
echo ""
echo "   # Health check"
echo "   curl -H \"Authorization: Token $TOKEN\" http://$PROXMOX_HOST:9090/api/health/"
else
echo "⚠️  Could not display token (check logs above)"
fi

echo ""
echo "📱 BROWSER EXTENSIONS:"
echo "   • Configure with: http://$PROXMOX_HOST:9090"
echo "   • Use token for API access in extensions"
echo ""
echo "📋 Creation log saved to: $LOGFILE"
echo "Timestamp: $(date)"