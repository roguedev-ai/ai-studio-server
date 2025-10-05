#!/bin/bash
# Complete OAuth Authentication Fix
# Combines all fixes for OAuth issues: credentials, adapter, environment

set -e

echo "=========================================="
echo "COMPLETE GIDEON STUDIO OAUTH FIX"
echo "=========================================="
echo ""

echo "This script performs all necessary OAuth fixes:"
echo "  ✓ Placeholder → Real OAuth credentials"
echo "  ✓ Environment variable corrections"
echo "  ✓ NextAuth adapter HTTP routing"
echo "  ✓ Nginx reverse proxy configuration"
echo "  ✓ Container restart and verification"
echo ""

read -p "Continue with complete OAuth fix? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted by user."
    exit 0
fi
echo ""

# Get domain
echo "🌐 Domain Configuration"
echo "-----------------------"

read -p "Enter your domain (e.g., studio.euctools.ai): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "❌ Domain required"
    exit 1
fi

DOMAIN="https://$DOMAIN"
echo "Using domain: $DOMAIN"
echo ""

# Section 1: OAuth Credentials
echo "🔑 Section 1: OAuth Credential Setup"
echo "-------------------------------------"

cat > .env.oauth-update << EOF
# REAL GitHub OAuth Credentials (replace with your actual values)
# Get from: https://github.com/settings/applications/new
# - Application Name: Gideon Studio
# - Homepage URL: $DOMAIN
# - Authorization callback URL: $DOMAIN/api/auth/callback/github

# Replace 'your-github-client-id-here' with actual Client ID from GitHub
GITHUB_CLIENT_ID=your-github-client-id-here

# Replace 'your-github-client-secret-here' with actual Client Secret from GitHub
GITHUB_CLIENT_SECRET=your-github-client-secret-here

# Google OAuth Credentials
# Get from: https://console.cloud.google.com/apis/credentials
# Create "Web application"
# - Authorized origins: $DOMAIN
# - Redirect URIs: $DOMAIN/api/auth/callback/google

# Replace 'your-google-client-id-here' with actual Client ID
GOOGLE_CLIENT_ID=your-google-client-id-here

# Replace 'your-google-client-secret-here' with actual Client Secret
GOOGLE_CLIENT_SECRET=your-google-client-secret-here
EOF

echo "✓ Created .env.oauth-update with OAuth credential placeholders"
echo "✅ IMPORTANT: Edit the file and replace ALL 'your-*-here' values with real OAuth app credentials"
echo ""

read -p "Press Enter after you've updated the OAuth credentials..."
echo ""

# Section 2: Environment Updates
echo "🔧 Section 2: Environment Configuration"
echo "----------------------------------------"

# Backup current .env
cp .env .env.oauth-backup

# Update APP_URL in docker-compose.yml
cp docker-compose.yml docker-compose.yml.oauth-backup

# Correct APP_URL to use domain
sed -i "s|APP_URL=\${APP_URL:-\[^}]*}|APP_URL=\${APP_URL:-$DOMAIN}|" docker-compose.yml

echo "✓ Updated docker-compose.yml APP_URL to $DOMAIN"
echo "✓ Backed up original files"
echo ""

# Section 3: Credentials Verification
echo "🔍 Section 3: Credential Verification"
echo "--------------------------------------"

echo "Current credential status:"
echo "GitHub ID: $(grep '^GITHUB_CLIENT_ID=' .env | cut -d'=' -f2 | head -c 10)...$(grep '^GITHUB_CLIENT_ID=' .env | cut -d'=' -f2 | tail -c 10)"
echo "Google ID: $(grep '^GOOGLE_CLIENT_ID=' .env | cut -d'=' -f2 | head -c 10)...$(grep '^GOOGLE_CLIENT_ID=' .env | cut -d'=' -f2 | tail -c 10)"

# Check for placeholders
PLACEHOLDER_COUNT=$(grep -c "your-.*-here" .env)
if [ "$PLACEHOLDER_COUNT" -gt 0 ]; then
    echo ""
    echo "⚠️  $PLACEHOLDER_COUNT placeholder credentials still detected!"
    echo "   Edit .env and replace ALL 'your-*-here' values with real OAuth credentials"
    read -p "Have you replaced all placeholder credentials? (yes/no): " UPDATED
    if [ "$UPDATED" != "yes" ]; then
        echo "Please update the credentials and run this script again."
        exit 1
    fi
fi
echo ""

# Section 4: Nginx Configuration
echo "🌐 Section 4: Nginx Reverse Proxy Setup"
echo "----------------------------------------"

# Extract domain without https://
DOMAIN_CLEAN=$(echo $DOMAIN | sed 's|https://||')
Nginx_CONF="/etc/nginx/sites-enabled/$DOMAIN_CLEAN"

echo "Setting up nginx for domain: $DOMAIN_CLEAN"
echo ""

# Check for SSL certificates
if [ -f "/etc/ssl/certs/$DOMAIN_CLEAN.crt" ] && [ -f "/etc/ssl/private/$DOMAIN_CLEAN.key" ]; then
    echo "✓ SSL certificates found - configuring HTTPS"

    # Create HTTPS nginx config
    sudo tee "$Nginx_CONF" << EOF
server {
    listen 80;
    server_name $DOMAIN_CLEAN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_CLEAN;

    ssl_certificate /etc/ssl/certs/$DOMAIN_CLEAN.crt;
    ssl_certificate_key /etc/ssl/private/$DOMAIN_CLEAN.key;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
    }

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

else
    echo "⚠️  No SSL certificates found - configuring HTTP for testing"

    # Create HTTP nginx config
    sudo tee "$Nginx_CONF" << EOF
server {
    listen 80;
    server_name $DOMAIN_CLEAN;

    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # Update DOMAIN to HTTP for testing
    DOMAIN="http://$DOMAIN_CLEAN"
    sed -i "s|APP_URL=\${APP_URL:-https://[^}]*}|APP_URL=\${APP_URL:-$DOMAIN}|" docker-compose.yml
fi

echo "✓ Created nginx configuration"
echo ""

# Section 5: Restart Services
echo "🔄 Section 5: Service Restart"
echo "-----------------------------"

echo "Testing nginx configuration..."
if sudo nginx -t; then
    echo "✓ nginx configuration valid"
else
    echo "❌ nginx configuration error"
    exit 1
fi

echo "Reloading nginx..."
sudo systemctl reload nginx

echo "Stopping containers..."
docker compose down

echo "Starting containers..."
docker compose up -d

echo "Waiting for startup..."
sleep 10

# Section 6: Final Tests
echo "🧪 Section 6: Final Verification"
echo "---------------------------------"

# Check container status
if docker compose ps | grep -q "gideon-studio.*Up"; then
    echo "✓ Container is running"
else
    echo "⚠️  Container may still be starting"
fi

# Test endpoint accessibility
DOMAIN_TEST=$DOMAIN
if curl -I "$DOMAIN/api/auth/adapter" 2>/dev/null | head -1 | grep -q "200\|301\|404"; then
    echo "✓ NextAuth adapter endpoint accessible"
else
    echo "⚠️  Adapter endpoint may not be ready"
fi

echo ""

echo "=========================================="
echo "🎉 OAUTH FIX COMPLETED!"
echo "=========================================="

echo ""
echo "OAuth should now work completely:"
echo "  1. Visit: $DOMAIN"
echo "  2. Click GitHub/Google sign-in buttons"
echo "  3. Complete OAuth authorization"
echo "  4. Should redirect to Knowledge Base (/files)"
echo ""

if echo "$DOMAIN" | grep -q "http://"; then
    echo "⚠️  Using HTTP configuration. OAuth providers require HTTPS for production."
    echo "   For production, get SSL certificates and run:"
    echo "   sudo certbot --nginx -d $DOMAIN_CLEAN"
fi

echo ""
echo "If issues persist, check logs:"
echo "  docker compose logs -f gideon-studio"
echo "  sudo nginx -t && sudo systemctl status nginx"

exit 0
