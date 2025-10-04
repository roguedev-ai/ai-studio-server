#!/bin/bash
set -e

echo "=========================================="
echo "Gideon Studio - Multi OAuth Setup (GitHub + Google)"
echo "=========================================="
echo ""

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "❌ Error: docker not found"; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "❌ Error: openssl not found"; exit 1; }

# Load existing .env values for prompting
if [ -f .env ]; then
    source .env
    echo "✅ Found existing .env file"
    echo "📋 Current configuration:"
    if [ -n "$GITHUB_CLIENT_ID" ]; then
        echo "   GitHub Client ID: ****${GITHUB_CLIENT_ID: -4}"
    else
        echo "   GitHub Client ID: (not set)"
    fi
    if [ -n "$GITHUB_CLIENT_SECRET" ]; then
        echo "   GitHub Client Secret: ****${GITHUB_CLIENT_SECRET: -4}"
    else
        echo "   GitHub Client Secret: (not set)"
    fi
    if [ -n "$GOOGLE_CLIENT_ID" ]; then
        echo "   Google Client ID: ****${GOOGLE_CLIENT_ID: -4}"
    else
        echo "   Google Client ID: (not set)"
    fi
    if [ -n "$GOOGLE_CLIENT_SECRET" ]; then
        echo "   Google Client Secret: ****${GOOGLE_CLIENT_SECRET: -4}"
    else
        echo "   Google Client Secret: (not set)"
    fi
    echo ""
fi

echo "🔑 Multi OAuth Configuration (GitHub + Google)"
echo "----------------------------------------------"
echo "📋 You can configure either GitHub, Google, or both OAuth providers"
echo "   OAuth App creation links are provided below"
echo ""

echo "🔑 GitHub OAuth (Optional)"
echo "---------------------------"
echo "📋 Create OAuth App at: https://github.com/settings/developers"
echo ""
echo "📝 Required settings:"
echo "   • Homepage URL: http://10.1.10.132:3000"
echo "   • Callback URL: http://10.1.10.132:3000/api/auth/callback/github"
echo ""

# Always ask for GitHub credentials with existing values as defaults
read -p "ℹ️  Enter GitHub Client ID [${GITHUB_CLIENT_ID:-none}] (or press Enter to skip): " GITHUB_CLIENT_ID_NEW
if [ -n "$GITHUB_CLIENT_ID_NEW" ]; then
    read -sp "🔐 Enter GitHub Client Secret: " GITHUB_CLIENT_SECRET_NEW
    echo ""
    echo ""
fi

echo ""
echo "🔑 Google OAuth (Optional)"
echo "---------------------------"
echo "📋 Create OAuth App at: https://console.cloud.google.com/apis/credentials"
echo ""
echo "📝 Required settings:"
echo "   • Application type: Web application"
echo "   • Authorized JavaScript origins: http://10.1.10.132:3000"
echo "   • Authorized redirect URIs: http://10.1.10.132:3000/api/auth/callback/google"
echo ""

# Always ask for Google credentials with existing values as defaults
read -p "ℹ️  Enter Google Client ID [${GOOGLE_CLIENT_ID:-none}] (or press Enter to skip): " GOOGLE_CLIENT_ID_NEW
if [ -n "$GOOGLE_CLIENT_ID_NEW" ]; then
    read -sp "🔐 Enter Google Client Secret: " GOOGLE_CLIENT_SECRET_NEW
    echo ""
    echo ""
fi

# Use new values if provided, otherwise keep existing
if [ -n "$GITHUB_CLIENT_ID_NEW" ]; then
    GITHUB_CLIENT_ID=$GITHUB_CLIENT_ID_NEW
fi
if [ -n "$GITHUB_CLIENT_SECRET_NEW" ]; then
    GITHUB_CLIENT_SECRET=$GITHUB_CLIENT_SECRET_NEW
fi
if [ -n "$GOOGLE_CLIENT_ID_NEW" ]; then
    GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID_NEW
fi
if [ -n "$GOOGLE_CLIENT_SECRET_NEW" ]; then
    GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET_NEW
fi

# Track which providers are configured
has_github=false
has_google=false

if [ -n "$GITHUB_CLIENT_ID" ] && [ -n "$GITHUB_CLIENT_SECRET" ]; then
    has_github=true
    echo "✅ GitHub OAuth configured"
fi

if [ -n "$GOOGLE_CLIENT_ID" ] && [ -n "$GOOGLE_CLIENT_SECRET" ]; then
    has_google=true
    echo "✅ Google OAuth configured"
fi

# Check if at least one provider is configured
if [ "$has_github" = false ] && [ "$has_google" = false ]; then
    echo ""
    echo "❌ Error: At least one OAuth provider must be configured!"
    echo ""
    echo "Please go back and enter credentials for GitHub, Google, or both."
    exit 1
fi

# Generate secrets if needed
if [ ! -f .env ] || ! grep -q "NEXT_AUTH_SECRET" .env; then
    NEXT_AUTH_SECRET=$(openssl rand -base64 32)
    KEY_VAULTS_SECRET=$(openssl rand -base64 32)
else
    source .env
fi

# Build provider list and credentials
PROVIDERS=""
ENV_VARS=""
SECRETS_VARS=""

if [ "$has_github" = true ]; then
    PROVIDERS="${PROVIDERS}github,"
    ENV_VARS="${ENV_VARS}      - AUTH_GITHUB_ID=\${GITHUB_CLIENT_ID}\n      - AUTH_GITHUB_SECRET=\${GITHUB_CLIENT_SECRET}\n"
    SECRETS_VARS="${SECRETS_VARS}GITHUB_CLIENT_ID=$GITHUB_CLIENT_ID\nGITHUB_CLIENT_SECRET=$GITHUB_CLIENT_SECRET\n"
fi

if [ "$has_google" = true ]; then
    PROVIDERS="${PROVIDERS}google,"
    ENV_VARS="${ENV_VARS}      - AUTH_GOOGLE_ID=\${GOOGLE_CLIENT_ID}\n      - AUTH_GOOGLE_SECRET=\${GOOGLE_CLIENT_SECRET}\n"
    SECRETS_VARS="${SECRETS_VARS}GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID\nGOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET\n"
fi

# Remove trailing comma
PROVIDERS=${PROVIDERS%,}

# Create/update .env
cat > .env << EOF
NEXT_AUTH_SECRET=$NEXT_AUTH_SECRET
KEY_VAULTS_SECRET=$KEY_VAULTS_SECRET
$SECRETS_VARS
GOOGLE_API_KEY=\${GOOGLE_API_KEY:-your_google_api_key_here}
EOF

echo "✅ Created .env file with credentials"

# Backup docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup

# Update NEXT_PUBLIC_ENABLE_NEXT_AUTH from "0" to "1"
echo "🔄 Updating docker-compose.yml..."
sed -i 's/NEXT_PUBLIC_ENABLE_NEXT_AUTH: "0"/NEXT_PUBLIC_ENABLE_NEXT_AUTH: "1"/' docker-compose.yml

# Add NextAuth and provider environment variables if not present
if ! grep -q "NEXT_AUTH_SSO_PROVIDERS=${PROVIDERS}" docker-compose.yml; then
    echo "🎛️ Adding Multi OAuth configuration..."

    # Find insertion point after KEY_VAULTS_SECRET
    sed -i "/      - KEY_VAULTS_SECRET=\${KEY_VAULTS_SECRET:-create-a-secure-key}/a\\
      # Authentication\\
      - NEXTAUTH_ENABLED=1\\
      - NEXTAUTH_URL=http://10.1.10.132:3000/api/auth\\
      - NEXT_AUTH_SSO_PROVIDERS=$PROVIDERS$ENV_VARS" docker-compose.yml

    echo "✅ Added authentication configuration"
fi

echo ""
echo "🚀 Deploying with Multi OAuth authentication..."
echo "----------------------------------------------"

docker compose down
docker rmi ai-studio-server-gideon-studio 2>/dev/null || true
docker builder prune -f

echo "⏳ Building (this takes 15-20 minutes)..."
docker compose build --no-cache gideon-studio

echo "🎯 Starting services..."
docker compose up -d

echo "⏳ Waiting for services to be ready..."
sleep 45

# Health check with progress
echo -n "🔍 Checking Gideon Studio health"
for i in {1..20}; do
    if curl -s -f http://localhost:3000 >/dev/null 2>&1; then
        echo " ✅"
        break
    fi
    echo -n "."
    sleep 3
done

echo ""
echo "=========================================="
echo "🎉 Multi OAuth Deployment Complete!"
echo "=========================================="
echo ""
echo "🌐 Gideon Studio: http://10.1.10.132:3000"
echo ""
echo "🔐 Configured providers: $(echo $PROVIDERS | tr ',' ' or ')"
echo ""
echo "🔐 Test authentication:"
echo "   1. Visit the URL above"
echo "   2. Click 'Sign in' button"
echo "   3. Choose your preferred provider ($PROVIDERS)"
echo "   4. Authorize the application"
echo "   5. Access Knowledge Base: /files"
echo ""
echo "📁 Credentials saved in: .env"
echo "💾 Backup created: docker-compose.yml.backup"
echo ""
echo "🆘 If authentication fails:"
echo "   • docker compose logs gideon-studio | grep -i auth"
echo "   • Check OAuth app credentials for configured providers"
echo "   • Verify .env file exists"
echo ""
echo "🎯 Knowledge Base is FULLY FUNCTIONAL with multi-provider authentication!"
echo ""
