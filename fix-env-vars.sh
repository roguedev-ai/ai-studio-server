#!/bin/bash
# Fix Environment Variables for Gideon Studio OAuth
# Run this script if OAuth deployment scripts don't work properly

echo "🔧 Gideon Studio Environment Variable Fix"
echo "=========================================="
echo ""
echo "This script manually creates/updates the .env file with OAuth variables."
echo "Use this if the automatic OAuth deployment scripts fail to create .env"
echo ""

# Check if curl is available
if ! command -v curl >/dev/null 2>&1; then
    echo "❌ curl not found - needed for API tests"
    echo "   Install: sudo apt install curl"
fi

echo "📋 OAuth Credentials Setup"
echo "--------------------------"

# GitHub OAuth (optional)
read -p "Do you have GitHub OAuth credentials? [y/N]: " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔑 GitHub OAuth Setup:"
    read -p "   GitHub Client ID: " GITHUB_CLIENT_ID
    read -sp "   GitHub Client Secret: " GITHUB_CLIENT_SECRET
    echo ""
    HAS_GITHUB=true
else
    echo "ℹ️  Skipping GitHub OAuth"
    HAS_GITHUB=false
fi

# Google OAuth (optional)
if [ "$HAS_GITHUB" = false ]; then
    read -p "Do you have Google OAuth credentials? [y/N]: " -n 1 -r
    echo ""
else
    read -p "Also set up Google OAuth credentials? [y/N]: " -n 1 -r
    echo ""
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔑 Google OAuth Setup:"
    read -p "   Google Client ID: " GOOGLE_CLIENT_ID
    read -sp "   Google Client Secret: " GOOGLE_CLIENT_SECRET
    echo ""
    HAS_GOOGLE=true
else
    echo "ℹ️  Skipping Google OAuth"
    HAS_GOOGLE=false
fi

# Validate we have at least one provider
if [ "$HAS_GITHUB" = false ] && [ "$HAS_GOOGLE" = false ]; then
    echo "❌ No OAuth providers configured!"
    echo "   You need at least one: GitHub or Google OAuth"
    exit 1
fi

# Generate secrets
echo "🔐 Generating secure secrets..."
NEXT_AUTH_SECRET=$(openssl rand -base64 32)
KEY_VAULTS_SECRET=$(openssl rand -base64 32)

# Create .env file
echo "📝 Creating .env file..."
cat > .env << EOF
# NextAuth Configuration
NEXT_AUTH_SECRET=$NEXT_AUTH_SECRET
KEY_VAULTS_SECRET=$KEY_VAULTS_SECRET

EOF

# Add OAuth settings
if [ "$HAS_GITHUB" = true ]; then
    cat >> .env << EOF
# GitHub OAuth
GITHUB_CLIENT_ID=$GITHUB_CLIENT_ID
GITHUB_CLIENT_SECRET=$GITHUB_CLIENT_SECRET
EOF
fi

if [ "$HAS_GOOGLE" = true ]; then
    cat >> .env << EOF
# Google OAuth
GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET
EOF
fi

# Add Google API key
cat >> .env << EOF

# Google Gemini API
GOOGLE_API_KEY=your_google_api_key_here
EOF

echo "✅ Created .env file"
echo ""
echo "📁 Contents of .env file:"
echo "   $(wc -l .env | cut -d' ' -f1) lines"
echo ""
echo "🔍 Testing Docker Compose variable substitution..."

# Test Docker Compose environment loading (if docker is available)
if command -v docker >/dev/null 2>&1; then
    echo "🐳 Docker detected - testing configuration..."
    echo ""

    # Try to validate environment loading
    echo "🔧 Testing environment variable substitution:"
    echo "   GITHUB_CLIENT_ID: $([ -n "$GITHUB_CLIENT_ID" ] && echo "Set (${#GITHUB_CLIENT_ID} chars)" || echo "Not set")"
    echo "   GITHUB_CLIENT_SECRET: $([ -n "$GITHUB_CLIENT_SECRET" ] && echo "Set (${#GITHUB_CLIENT_SECRET} chars)" || echo "Not set")"
    echo "   GOOGLE_CLIENT_ID: $([ -n "$GOOGLE_CLIENT_ID" ] && echo "Set (${#GOOGLE_CLIENT_ID} chars)" || echo "Not set")"
    echo "   GOOGLE_CLIENT_SECRET: $([ -n "$GOOGLE_CLIENT_SECRET" ] && echo "Set (${#GOOGLE_CLIENT_SECRET} chars)" || echo "Not set")"
    echo ""

    echo "🚀 Ready to restart Gideon Studio:"
    echo "   docker compose restart gideon-studio"
    echo ""
    echo "📝 Then test with:"
    echo "   docker compose logs -f gideon-studio"
    echo "   curl -I http://localhost:3000"
else
    echo "🐳 Docker not available in this environment"
    echo "   Copy .env to your server and run:"
    echo "   docker compose restart gideon-studio"
fi

echo ""
echo "==============================================="
echo "🎉 Environment variables configured!"
echo "==============================================="
echo ""
echo "Next steps:"
echo "1. Run: docker compose restart gideon-studio"
echo "2. Check logs for 'MissingSecret' errors (should be gone)"
echo "3. Visit http://localhost:3000 for OAuth login"
echo "4. For production: Update OAuth provider callback URLs"
echo ""

exit 0
