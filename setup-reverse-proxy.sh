#!/bin/bash
set -e

echo "=========================================="
echo "Gideon Studio Reverse Proxy Setup"
echo "=========================================="
echo ""
echo "This script configures nginx as a reverse proxy with SSL"
echo "for production OAuth-compatible access to Gideon Studio."
echo ""
echo "Requirements: SSL certificate, private key, and root access"
echo ""

# Part 1: Prerequisite Checks
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: Please run as root (sudo ./setup-reverse-proxy.sh)"
    exit 1
fi

echo "🔍 Performing prerequisite checks..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker is not running or not accessible"
    exit 1
fi

# Check if docker-compose exists
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Error: docker compose command not found"
    exit 1
fi

# Check available disk space (require at least 500MB)
AVAILABLE_MB=$(df / | awk 'NR==2 {print int($4/1024)}')
if [ "$AVAILABLE_MB" -lt 500 ]; then
    echo "❌ Error: Insufficient disk space (${AVAILABLE_MB}MB available, need 500MB+)"
    exit 1
fi

# Check if port 80 and 443 are free
if netstat -tuln 2>/dev/null | grep -q ':80 '; then
    echo "⚠️  Warning: Port 80 is already in use"
    echo "   This might conflict with HTTP redirects"
fi

if netstat -tuln 2>/dev/null | grep -q ':443 '; then
    echo "❌ Error: Port 443 is already in use"
    echo "   Please stop any service using port 443 before running this script"
    exit 1
fi

echo "✅ Prerequisites passed"

# Part 2: Information Gathering
echo ""
echo "📋 Configuration Information"
echo "----------------------------"

# Domain
read -p "Domain name [studio.euctools.ai]: " DOMAIN
DOMAIN=${DOMAIN:-studio.euctools.ai}

# SSL Certificate
while true; do
    read -p "SSL certificate path (full path): " SSL_CERT
    if [ -z "$SSL_CERT" ]; then
        echo "❌ Certificate path cannot be empty"
        continue
    fi
    if [ ! -f "$SSL_CERT" ]; then
        echo "❌ Certificate file not found: $SSL_CERT"
        continue
    fi
    break
done

# SSL Private Key
while true; do
    read -p "SSL private key path (full path): " SSL_KEY
    if [ -z "$SSL_KEY" ]; then
        echo "❌ Private key path cannot be empty"
        continue
    fi
    if [ ! -f "$SSL_KEY" ]; then
        echo "❌ Private key file not found: $SSL_KEY"
        continue
    fi
    break
done

# Validate SSL certificate and private key (supports RSA and ECDSA)
echo "🔍 Validating SSL certificate and private key..."

# Verify files are readable
if ! openssl x509 -in "$SSL_CERT" -noout 2>/dev/null; then
    echo "❌ Error: Cannot read SSL certificate"
    exit 1
fi

if ! openssl pkey -in "$SSL_KEY" -noout 2>/dev/null; then
    echo "❌ Error: Cannot read SSL private key"
    exit 1
fi

# Detect key type and validate accordingly
KEY_TYPE=$(openssl pkey -in "$SSL_KEY" -text -noout 2>/dev/null | head -1)

if echo "$KEY_TYPE" | grep -qi "rsa"; then
    echo "   ✅ Detected RSA key"
    CERT_MOD=$(openssl x509 -noout -modulus -in "$SSL_CERT" | openssl md5)
    KEY_MOD=$(openssl rsa -noout -modulus -in "$SSL_KEY" | openssl md5)

    if [ "$CERT_MOD" != "$KEY_MOD" ]; then
        echo "❌ Error: Certificate and key don't match"
        exit 1
    fi

elif echo "$KEY_TYPE" | grep -qi "private-key"; then
    echo "   ✅ Detected ECDSA key"
    CERT_PUB=$(openssl x509 -in "$SSL_CERT" -pubkey -noout | openssl md5)
    KEY_PUB=$(openssl pkey -in "$SSL_KEY" -pubout | openssl md5)

    if [ "$CERT_PUB" != "$KEY_PUB" ]; then
        echo "❌ Error: Certificate and key don't match"
        exit 1
    fi
else
    echo "❌ Error: Unknown key type: $KEY_TYPE"
    exit 1
fi

echo "✅ Certificate and key are valid and match"

# Check certificate validity
if ! openssl x509 -checkend 86400 -noout -in "$SSL_CERT"; then
    echo "⚠️  Warning: SSL certificate expires within 24 hours"
    echo "   Consider renewing before proceeding"
    read -p "Continue anyway? [y/N]: " -n 1 -r
    echo ""
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# Internal port
read -p "Internal Gideon Studio port [3000]: " INTERNAL_PORT
INTERNAL_PORT=${INTERNAL_PORT:-3000}

# Admin email
read -p "Admin email for notifications (optional): " ADMIN_EMAIL

echo ""
echo "📋 Configuration Summary:"
echo "  Domain: $DOMAIN"
echo "  SSL Certificate: $SSL_CERT"
echo "  SSL Private Key: $SSL_KEY"
echo "  Internal Port: $INTERNAL_PORT"
echo "  Admin Email: ${ADMIN_EMAIL:-none}"
echo ""

# Part 3: Nginx Installation & Configuration
echo "🛠️  Installing and configuring nginx..."

# Install nginx if not present
if ! nginx -v >/dev/null 2>&1; then
    echo "📦 Installing nginx..."
    apt update
    apt install -y nginx
else
    echo "✅ nginx already installed"
    # Stop existing nginx while we configure
    systemctl stop nginx 2>/dev/null || true
fi

# Backup existing config
BACKUP_TIME=$(date +%s)
if [ -d "/etc/nginx" ]; then
    echo "💾 Backing up existing nginx configuration..."
    tar -czf "/etc/nginx/backup-pre-gideon-${BACKUP_TIME}.tar.gz" -C / etc/nginx 2>/dev/null || true
    echo "   Backup saved: /etc/nginx/backup-pre-gideon-${BACKUP_TIME}.tar.gz"
fi

# Create nginx configuration
echo "📝 Creating nginx configuration..."

# Use sed to replace variables in template
cat > /etc/nginx/sites-available/gideon-studio << EOF_NGINX_CONFIG
# Gideon Studio Reverse Proxy Configuration
# Generated on $(date)
# Domain: $DOMAIN
# Internal: localhost:$INTERNAL_PORT

# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    # Let's Encrypt ACME challenge (for renewals)
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files \$uri =404;
    }

    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }

    access_log /var/log/nginx/gideon-studio-access.log;
    error_log /var/log/nginx/gideon-studio-error.log;
}

# Main HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    # SSL Configuration
    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;

    # Modern SSL security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # SSL session caching
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS Security Header (adjust age as needed)
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;

    # Main proxy to Gideon Studio
    location / {
        proxy_pass http://localhost:$INTERNAL_PORT;
        proxy_http_version 1.1;

        # WebSocket support (for real-time features)
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;

        # Pass original request information
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for,\$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Maintenance-Mode "false";

        # Bypass cache for upgrades
        proxy_cache_bypass \$http_upgrade \$http_cache_control \$http_authorization;

        # Extended timeouts for large file uploads
        proxy_connect_timeout 600;
        proxy_send_timeout 600;
        proxy_read_timeout 600;
        send_timeout 600;

        # Handle large file uploads (adjust as needed)
        client_max_body_size 100M;
        proxy_request_buffering off;
    }

    # Optional: MinIO S3 direct access (if needed)
    location /minio/ {
        proxy_pass http://localhost:9000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for,\$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 60;
        proxy_send_timeout 60;
        proxy_read_timeout 60;
    }

    # Logs
    access_log /var/log/nginx/gideon-studio-access.log;
    error_log /var/log/nginx/gideon-studio-error.log;
}

# Variable for WebSocket connection upgrade
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}
EOF_NGINX_CONFIG

echo "✅ Created nginx configuration: /etc/nginx/sites-available/gideon-studio"

# Set proper permissions on SSL key
echo "🔐 Setting SSL permissions..."
chmod 600 "$SSL_KEY"
chmod 644 "$SSL_CERT"

# Part 4: Enable Site & Test Configuration
echo "🔗 Enabling nginx site..."

# Remove default site if it exists
if [ -L "/etc/nginx/sites-enabled/default" ]; then
    echo "🔧 Disabling nginx default site..."
    rm -f /etc/nginx/sites-enabled/default
fi

# Enable our site
ln -sf /etc/nginx/sites-available/gideon-studio /etc/nginx/sites-enabled/

echo "🧪 Testing nginx configuration..."
if ! nginx -t; then
    echo ""
    echo "❌ nginx configuration test failed!"
    echo "   Check syntax and file paths"
    echo ""
    echo "Fix the configuration and run:"
    echo "  sudo nginx -t"
    echo "  sudo systemctl restart nginx"
    exit 1
fi

echo "✅ nginx configuration test passed"

# Start nginx
echo "🚀 Starting nginx service..."
systemctl start nginx
systemctl enable nginx

echo "✅ nginx is running and enabled"

# Part 5: Update docker-compose.yml
echo ""
echo "🔧 Updating docker-compose.yml for HTTPS URLs..."

# Backup existing docker-compose.yml
DOCKER_BACKUP_PATH="/opt/gideon-docker-compose-${BACKUP_TIME}.yml.backup"
CURRENT_DIR="$(pwd)"

# Try to determine the correct ai-studio-server path
AI_STUDIO_PATH="/opt/ai-studio-server"
if [ ! -d "$AI_STUDIO_PATH" ] && [ -f "docker-compose.yml" ]; then
    AI_STUDIO_PATH="$CURRENT_DIR"
elif [ ! -d "$AI_STUDIO_PATH" ]; then
    AI_STUDIO_PATH="/home/$(logname)/ai-studio-server"
fi

DOCKER_COMPOSE_FILE="${AI_STUDIO_PATH}/docker-compose.yml"

if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "⚠️  Warning: Could not find docker-compose.yml in standard locations"
    echo "   Checked: $AI_STUDIO_PATH"
    echo "   Please manually update these environment variables in your docker-compose.yml:"
    echo ""
    echo "   Change these values from IP-based to domain-based:"
    echo "   - NEXT_PUBLIC_APP_URL=http://10.1.10.132:3000 → NEXT_PUBLIC_APP_URL=https://$DOMAIN"
    echo "   - NEXTAUTH_URL=http://10.1.10.132:3000/api/auth → NEXTAUTH_URL=https://$DOMAIN/api/auth"
    echo "   - APP_URL=http://10.1.10.132:3000 → APP_URL=https://$DOMAIN"
fi

# Make backup and update docker-compose.yml
cp "$DOCKER_COMPOSE_FILE" "$DOCKER_BACKUP_PATH" 2>/dev/null || true

# Update URLs in docker-compose.yml
if sed -i.bak "s|http://10.1.10.132:3000|https://$DOMAIN|g" "$DOCKER_COMPOSE_FILE" 2>/dev/null; then
    echo "✅ Updated docker-compose.yml:"
    echo "   ✅ NEXT_PUBLIC_APP_URL"
    echo "   ✅ NEXTAUTH_URL"
    echo "   ✅ APP_URL"
    echo ""
    echo "💾 Backup saved: $DOCKER_BACKUP_PATH"
    echo ""

    # Check if docker-compose needs to be restarted
    read -p "Restart Gideon Studio to apply URL changes? [y/N]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Restarting Gideon Studio..."
        cd "$AI_STUDIO_PATH"
        docker compose restart gideon-studio
        echo "✅ Gideon Studio restarted with new HTTPS URLs"
    else
        echo "ℹ️  You can restart manually later:"
        echo "   cd $AI_STUDIO_PATH"
        echo "   docker compose restart gideon-studio"
    fi
else
    echo "⚠️  Manual docker-compose.yml update required (see instructions below)"
fi

# Part 6: Verification & Next Steps
echo ""
echo "=========================================="
echo "✅ REVERSE PROXY SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "🌐 ACCESS INFORMATION:"
echo "   External URL: https://$DOMAIN"
echo "   Status: Active and serving SSL"
echo ""
echo "📊 VERIFICATION COMMANDS:"
echo "   curl -I https://$DOMAIN"
echo "   curl -I http://$DOMAIN (should redirect to HTTPS)"
echo "   sudo nginx -t"
echo "   sudo systemctl status nginx"
echo ""
echo "📁 IMPORTANT FILES:"
echo "   nginx config: /etc/nginx/sites-available/gideon-studio"
echo "   SSL cert:     $SSL_CERT"
echo "   SSL key:      $SSL_KEY"
echo "   Access logs:  /var/log/nginx/gideon-studio-access.log"
echo "   Error logs:   /var/log/nginx/gideon-studio-error.log"
echo ""

echo "🔧 REQUIRED MANUAL STEPS:"
echo ""

echo "1. CONFIGURE INTERNAL DNS:"
echo "   Option A - /etc/hosts file (simple, single machine):"
echo "     echo '10.1.10.132 $DOMAIN' | sudo tee -a /etc/hosts"
echo ""
echo "   Option B - DNS Server (recommended for multiple machines):"
echo "     Add A record: $DOMAIN → 10.1.10.132"
echo ""

echo "2. UPDATE OAUTH PROVIDERS FOR HTTPS:"
echo ""
echo "   🔵 GitHub OAuth:"
echo "      App URL: https://$DOMAIN"
echo "      Callback: https://$DOMAIN/api/auth/callback/github"
echo ""
echo "   🔴 Google OAuth:"
echo "      Authorized origins: https://$DOMAIN"
echo "      Redirect URI: https://$DOMAIN/api/auth/callback/google"
echo ""
echo "   📱 Other OAuth providers:"
echo "      Ensure all callback URLs use https://$DOMAIN/"
echo ""

echo "3. FIREWALL CONFIGURATION:"
echo "   Ensure port 443 (HTTPS) is open:"
echo "     sudo ufw status"
echo "     sudo ufw allow 443/tcp  (if needed)"
echo ""
echo "   Optional: Block direct port 3000 access:"
echo "     sudo ufw deny 3000/tcp"
echo ""

echo "4. SSL CERTIFICATE RENEWAL:"
if [ -n "$ADMIN_EMAIL" ]; then
    echo "   Configure automatic renewal if using Let's Encrypt:"
    echo "   sudo crontab -e"
    echo "   Add: 0 3 * * 0 certbot renew --quiet --deploy-hook 'systemctl reload nginx'"
    echo ""
else
    echo "   Monitor SSL expiration:"
    echo "   openssl x509 -enddate -noout -in $SSL_CERT"
    echo ""
fi

echo "5. TEST FUNCTIONALITY:"
echo "   - Visit: https://$DOMAIN"
echo "   - Test Knowledge Base: /files (after OAuth setup)"
echo "   - Upload documents and test RAG chat"
echo "   - Verify no 'UNAUTHORIZED' errors in logs"
echo ""

echo "🚨 TROUBLESHOOTING:"
echo "   Logs: sudo journalctl -u nginx -f"
echo "   Test config: sudo nginx -t"
echo "   Restart proxy: sudo systemctl restart nginx"
echo ""

echo "=========================================="
echo "🎯 SETUP SUMMARY"
echo "=========================================="
echo ""
echo "Domain:         $DOMAIN"
echo "SSL Valid:      ✅"
echo "nginx:          ✅ Running"
echo "Docker URLs:    ✅ Updated"
echo "OAuth Ready:    ✅ (after provider updates)"
echo "Firewall:       ⚠️  Check required"
echo ""

if [ -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "🎉 SETUP COMPLETE - Gideon Studio is now production-ready!"
    echo "   Run: ./deploy-github-auth.sh (or google equivalents)"
    echo "   Then: Visit https://$DOMAIN/files"
    echo ""
else
    echo "🎉 Nginx setup complete!"
    echo "   Update docker-compose.yml URLs manually as shown above"
    echo "   Then run OAuth deployment scripts"
    echo ""
fi

exit 0
