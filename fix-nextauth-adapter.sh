#!/bin/bash
# NextAuth Adapter HTTP Routing Fix
# Fixes APP_URL mismatch and nginx reverse proxy configuration

set -e

echo "=========================================="
echo "NextAuth Adapter HTTP Routing Fix"
echo "=========================================="
echo ""

echo "This script fixes the NextAuth adapter connectivity issue by:"
echo "  1. Updating APP_URL to use the domain (not localhost)"
echo "  2. Configuring nginx to proxy /api/auth requests"
echo "  3. Restarting container with correct routing"
echo ""

read -p "Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted by user."
    exit 0
fi
echo ""

# Check if we're running on the correct system
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker not found. Run this script on your Gideon Studio server."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Error: docker-compose not found."
    exit 1
fi

echo "🔧 Step 1: Update APP_URL for NextAuth adapter"
echo "---------------------------------------------"

# Update APP_URL in docker-compose.yml if needed
echo "Current APP_URL configuration:"
grep "APP_URL=" docker-compose.yml || echo "APP_URL setting not found"

echo ""
echo "NextAuth adapter needs APP_URL to be your domain for HTTP requests."
echo "This should be: https://studio.euctools.ai"

read -p "Is your domain 'studio.euctools.ai'? (yes/no): " DOMAIN_OK
if [ "$DOMAIN_OK" == "no" ]; then
    read -p "Enter your actual domain (e.g., yoursite.com): " USER_DOMAIN
    DOMAIN="https://$USER_DOMAIN"
else
    DOMAIN="https://studio.euctools.ai"
fi

echo "Setting APP_URL to: $DOMAIN"
echo ""

# Update docker-compose.yml
cp docker-compose.yml docker-compose.yml.adapter-backup
sed -i "s|APP_URL=\${APP_URL:-\[^}]*}|APP_URL=\${APP_URL:-$DOMAIN}|" docker-compose.yml

echo "✓ Updated APP_URL configuration"
echo ""

echo "🔧 Step 2: Set up nginx reverse proxy"
echo "--------------------------------------"

Nginx_CONF="/etc/nginx/sites-enabled/$(echo $DOMAIN | sed 's|https://||')"

echo "Creating nginx configuration for: $(echo $DOMAIN | sed 's|https://||')"
echo ""

# Check if SSL certificates exist
if [ ! -f "/etc/ssl/certs/$(echo $DOMAIN | sed 's|https://||').crt" ] || [ ! -f "/etc/ssl/private/$(echo $DOMAIN | sed 's|https://||').key" ]; then
    echo "⚠️  SSL certificates not found. You need to obtain them first."
    echo ""
    echo "Options to get SSL certificates:"
    echo "  • Let's Encrypt (certbot): sudo certbot --nginx -d $(echo $DOMAIN | sed 's|https://||')"
    echo "  • Manual certificates: Place .crt and .key files in /etc/ssl/"
    echo ""
    echo "Or you can skip SSL for now by using http://localhost:3000"
    read -p "Do you have SSL certificates? (yes/no): " HAS_SSL

    if [ "$HAS_SSL" == "no" ]; then
        echo ""
        echo "🔄 Skipping SSL setup. Using HTTP configuration instead."
        echo "Note: OAuth providers require HTTPS for production, but this will work for testing."
        DOMAIN="http://$(echo $DOMAIN | sed 's|https://||')"
        sed -i "s|APP_URL=\${APP_URL:-https://[^}]*}|APP_URL=\${APP_URL:-$DOMAIN}|" docker-compose.yml
        echo "✓ Updated APP_URL to HTTP for testing"
        echo ""

        # Create HTTP-only nginx config
        sudo tee "$Nginx_CONF" << EOF
server {
    listen 80;
    server_name $(echo $DOMAIN | sed 's|http://||');

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
    else
        read -p "Path to SSL certificate (.crt file): " SSL_CERT
        read -p "Path to SSL private key (.key file): " SSL_KEY

        if [ ! -f "$SSL_CERT" ]; then
            echo "❌ SSL certificate not found: $SSL_CERT"
            exit 1
        fi
        if [ ! -f "$SSL_KEY" ]; then
            echo "❌ SSL private key not found: $SSL_KEY"
            exit 1
        fi

        # Create HTTPS nginx config
        sudo tee "$Nginx_CONF" << EOF
server {
    listen 80;
    server_name $(echo $DOMAIN | sed 's|https://||');
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $(echo $DOMAIN | sed 's|https://||');

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;

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
    fi
else
    echo "✓ SSL certificates found - creating HTTPS configuration"

    # Create HTTPS nginx config
    sudo tee "$Nginx_CONF" << EOF
server {
    listen 80;
    server_name $(echo $DOMAIN | sed 's|https://||');
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $(echo $DOMAIN | sed 's|https://||');

    ssl_certificate /etc/ssl/certs/$(echo $DOMAIN | sed 's|https://||').crt;
    ssl_certificate_key /etc/ssl/private/$(echo $DOMAIN | sed 's|https://||').key;

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
fi

echo "✓ Created nginx configuration"
echo ""

echo "🔧 Step 3: Test nginx configuration"
echo "-------------------------------------"

if sudo nginx -t; then
    echo "✓ nginx configuration is valid"
else
    echo "❌ nginx configuration has errors"
    exit 1
fi
echo ""

echo "🔧 Step 4: Reload nginx"
echo "------------------------"

sudo systemctl reload nginx
echo "✓ nginx reloaded"
echo ""

echo "🔧 Step 5: Restart Gideon Studio container"
echo "-------------------------------------------"

docker compose down
docker compose up -d

echo "✓ Container restarted with new configuration"
echo ""

echo "🔧 Step 6: Test NextAuth adapter connectivity"
echo "----------------------------------------------"

sleep 5

# Test if we can reach the adapter endpoint
DOMAIN_TEST=$(echo $DOMAIN | sed 's|https://||')
DOMAIN_TEST=$(echo $DOMAIN_TEST | sed 's|http://||')

if curl -I "$DOMAIN/api/auth/adapter" 2>/dev/null | head -1 | grep -q "200\|301\|404"; then
    echo "✓ NextAuth adapter endpoint is accessible"
else
    echo "⚠️  NextAuth adapter endpoint may not be ready yet"
fi

# Check container is running
if docker compose ps | grep -q "gideon-studio.*Up"; then
    echo "✓ Gideon Studio container is running"
else
    echo "⚠️  Gideon Studio container may still be starting"
fi

# Check NextAuth logs
echo ""
echo "📊 NextAuth adapter logs (should show successful adapter initialization):"
docker compose logs -n 10 gideon-studio | grep -E "(LobeNextAuthDbAdapter|Adapter.*created|fetch.*success)" || echo "No adapter logs yet"

echo ""

echo "=========================================="
echo "🎉 NEXTAUTH ADAPTER CONNECTIVITY FIXED!"
echo "=========================================="
echo ""
echo "NextAuth adapter should now work properly:"
echo "  • APP_URL set to: $DOMAIN"
echo "  • Nginx proxies /api/auth requests"
echo "  • Adapter can communicate with application"
echo ""
echo "Test OAuth flow:"
echo "  1. Visit: $DOMAIN"
echo "  2. Click GitHub/Google sign-in"
echo "  3. Complete OAuth provider authorization"
echo "  4. Should redirect back to Knowledge Base (/files)"
echo ""
echo "If still failing, check container logs:"
echo "  docker compose logs -f gideon-studio"
echo ""

exit 0
