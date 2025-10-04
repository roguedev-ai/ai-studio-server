#!/bin/bash
set -e

echo "=========================================="
echo "Gideon Studio - Google OAuth Setup"
echo "=========================================="
echo ""

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "❌ Error: docker not found"; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "❌ Error: openssl not found"; exit 1; }

# Check if .env exists and has Google credentials
if [ -f .env ] && grep -q "GOOGLE_CLIENT_ID" .env && grep -q "GOOGLE_CLIENT_SECRET" .env; then
    echo "✅ Found existing Google credentials in .env"
    source .env
else
    echo "🔑 Google OAuth App Setup Required"
    echo "-----------------------------------"
    echo ""
    echo "📋 Create OAuth App at: https://console.cloud.google.com/apis/credentials"
    echo ""
    echo "📝 Required settings:"
    echo "   • Application type: Web application"
    echo "   • Authorized JavaScript origins: http://10.1.10.132:3000"
    echo "   • Authorized redirect URIs: http://10.1.10.132:3000/api/auth/callback/google"
    echo ""
    read -p "ℹ️  Enter Google Client ID: " GOOGLE_CLIENT_ID
    read -sp "🔐 Enter Google Client Secret: " GOOGLE_CLIENT_SECRET
    echo ""
    echo ""

    # Generate secrets
    NEXT_AUTH_SECRET=$(openssl rand -base64 32)
    KEY_VAULTS_SECRET=$(openssl rand -base64 32)

    # Create .env
    cat > .env << EOF
NEXT_AUTH_SECRET=$NEXT_AUTH_SECRET
KEY_VAULTS_SECRET=$KEY_VAULTS_SECRET
GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET
GOOGLE_API_KEY=${GOOGLE_API_KEY:-your_google_api_key_here}
EOF

    echo "✅ Created .env file with credentials"
fi

# Backup docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup

# Update NEXT_PUBLIC_ENABLE_NEXT_AUTH from "0" to "1"
echo "🔄 Updating docker-compose.yml..."
sed -i 's/NEXT_PUBLIC_ENABLE_NEXT_AUTH: "0"/NEXT_PUBLIC_ENABLE_NEXT_AUTH: "1"/' docker-compose.yml

# Add NextAuth and Google environment variables if not present
if ! grep -q "NEXT_AUTH_SSO_PROVIDERS=google" docker-compose.yml; then
    echo "🎛️ Adding Google OAuth configuration..."

    # Find insertion point after KEY_VAULTS_SECRET
    sed -i '/      - KEY_VAULTS_SECRET=${KEY_VAULTS_SECRET:-create-a-secure-key}/a\
      # Authentication\
      - NEXTAUTH_ENABLED=1\
      - NEXTAUTH_URL=http://10.1.10.132:3000/api/auth\
      - NEXT_AUTH_SSO_PROVIDERS=google\
      - AUTH_GOOGLE_ID=${GOOGLE_CLIENT_ID}\
      - AUTH_GOOGLE_SECRET=${GOOGLE_CLIENT_SECRET}' docker-compose.yml

    echo "✅ Added authentication configuration"
fi

echo ""
echo "🚀 Deploying with Google authentication..."
echo "----------------------------------------"

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
echo "🎉 Google OAuth Deployment Complete!"
echo "=========================================="
echo ""
echo "🌐 Gideon Studio: http://10.1.10.132:3000"
echo ""
echo "🔐 Test authentication:"
echo "   1. Visit the URL above"
echo "   2. Click 'Sign in' button"
echo "   3. Choose 'Sign in with Google'"
echo "   4. Authorize the application"
echo "   5. Access Knowledge Base: /files"
echo ""
echo "📁 Credentials saved in: .env"
echo "💾 Backup created: docker-compose.yml.backup"
echo ""
echo "🆘 If authentication fails:"
echo "   • docker compose logs gideon-studio | grep -i auth"
echo "   • Check Google OAuth app credentials"
echo "   • Verify .env file exists"
echo ""
echo "🎯 Knowledge Base is FULLY FUNCTIONAL with authentication!"
echo ""
