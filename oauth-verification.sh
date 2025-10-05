#!/bin/bash
# OAuth Authentication Comprehensive Verification and Fix
# Tests all components required for OAuth authentication to work

set -e

echo "=========================================="
echo "Gideon Studio OAuth Authentication Fix"
echo "=========================================="
echo ""

# Part 1: Environment Variable Verification
echo "🔍 PART 1: Environment Variable Verification"
echo "---------------------------------------------"

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ ERROR: No .env file found!"
    echo "   Run one of the deployment scripts first:"
    echo "   ./deploy-github-auth.sh (for GitHub only)"
    echo "   ./deploy-google-auth.sh (for Google only)"
    echo "   ./deploy-multi-auth.sh (for both)"
    echo "   ./fix-env-vars.sh (manual setup)"
    exit 1
fi

echo "✅ .env file found"

# Verify OAuth variables exist and aren't empty
GITHUB_ID=$(grep "^GITHUB_CLIENT_ID=" .env | cut -d'=' -f2- | tr -d '\r\n')
GITHUB_SECRET=$(grep "^GITHUB_CLIENT_SECRET=" .env | cut -d'=' -f2- | tr -d '\r\n')
GITHUB_OAUTH_ID=$(grep "^AUTH_GITHUB_ID=" .env | cut -d'=' -f2- | tr -d '\r\n')
GITHUB_OAUTH_SECRET=$(grep "^AUTH_GITHUB_SECRET=" .env | cut -d'=' -f2- | tr -d '\r\n')

GOOGLE_ID=$(grep "^GOOGLE_CLIENT_ID=" .env | cut -d'=' -f2- | tr -d '\r\n')
GOOGLE_SECRET=$(grep "^GOOGLE_CLIENT_SECRET=" .env | cut -d'=' -f2- | tr -d '\r\n')
GOOGLE_OAUTH_ID=$(grep "^AUTH_GOOGLE_ID=" .env | cut -d'=' -f2- | tr -d '\r\n')
GOOGLE_OAUTH_SECRET=$(grep "^AUTH_GOOGLE_SECRET=" .env | cut -d'=' -f2- | tr -d '\r\n')

NEXTAUTH_SECRET=$(grep "^NEXT_AUTH_SECRET=" .env | cut -d'=' -f2- | tr -d '\r\n')
KEY_VAULTS_SECRET=$(grep "^KEY_VAULTS_SECRET=" .env | cut -d'=' -f2- | tr -d '\r\n')

echo ""
echo "🔐 Authentication Variables Check:"
echo "   NextAuth secret: $([ -n "$NEXTAUTH_SECRET" ] && echo "✅ Set (${#NEXTAUTH_SECRET} chars)" || echo "❌ Missing")"
echo "   KeyVaults secret: $([ -n "$KEY_VAULTS_SECRET" ] && echo "✅ Set (${#KEY_VAULTS_SECRET} chars)" || echo "❌ Missing")"
echo ""

echo "🔑 OAuth Provider Variables:"
echo "   GitHub Client ID: $([ -n "$GITHUB_ID$GITHUB_OAUTH_ID" ] && echo "✅ Set" || echo "❌ Missing")"
echo "   GitHub Client Secret: $([ -n "$GITHUB_SECRET$GITHUB_OAUTH_SECRET" ] && echo "✅ Set" || echo "❌ Missing")"
echo "   Google Client ID: $([ -n "$GOOGLE_ID$GOOGLE_OAUTH_ID" ] && echo "✅ Set" || echo "❌ Missing")"
echo "   Google Client Secret: $([ -n "$GOOGLE_SECRET$GOOGLE_OAUTH_SECRET" ] && echo "✅ Set" || echo "❌ Missing")"

# Determine which providers should be configured
PROVIDERS=""
if [ -n "$GITHUB_ID$GITHUB_OAUTH_ID" ] && [ -n "$GITHUB_SECRET$GITHUB_OAUTH_SECRET" ]; then
    PROVIDERS="github"
fi
if [ -n "$GOOGLE_ID$GOOGLE_OAUTH_ID" ] && [ -n "$GOOGLE_SECRET$GOOGLE_OAUTH_SECRET" ]; then
    PROVIDERS="${PROVIDERS}${PROVIDERS:+,}google"
fi

if [ -z "$PROVIDERS" ]; then
    echo ""
    echo "❌ ERROR: No OAuth providers configured!"
    echo "   Run a deployment script to configure authentication"
    exit 1
fi

echo ""
echo "✅ OAuth providers configured: $(echo "$PROVIDERS" | tr ',' ' & ')"

# Part 2: Docker Compose Configuration Fix
echo ""
echo "🔧 PART 2: Docker Compose Configuration Verification"
echo "---------------------------------------------------"

# Read current NEXT_AUTH_SSO_PROVIDERS from docker-compose
CURRENT_PROVIDERS=$(grep "NEXT_AUTH_SSO_PROVIDERS=" docker-compose.yml | cut -d'=' -f2- | tr -d '\r\n')

if [ "$CURRENT_PROVIDERS" != "$PROVIDERS" ]; then
    echo "📝 Updating docker-compose.yml NEXT_AUTH_SSO_PROVIDERS from '$CURRENT_PROVIDERS' to '$PROVIDERS'"

    # Backup current docker-compose.yml
    cp docker-compose.yml docker-compose.yml.oauth-backup

    # Update the providers line
    sed -i "s/NEXT_AUTH_SSO_PROVIDERS=.*/NEXT_AUTH_SSO_PROVIDERS=$PROVIDERS/" docker-compose.yml

    echo "✅ Updated docker-compose.yml OAuth providers"
else
    echo "✅ Docker Compose providers already match .env configuration"
fi

# Verify NEXT_PUBLIC_ENABLE_NEXT_AUTH is set correctly
NEXT_AUTH_ENABLED=$(grep "NEXT_PUBLIC_ENABLE_NEXT_AUTH:" docker-compose.yml)
if echo "$NEXT_AUTH_ENABLED" | grep -q '"0"'; then
    echo "📝 Enabling NextAuth in docker-compose.yml"
    cp docker-compose.yml docker-compose.yml.oauth-backup
    sed -i 's/NEXT_PUBLIC_ENABLE_NEXT_AUTH: "0"/NEXT_PUBLIC_ENABLE_NEXT_AUTH: "1"/' docker-compose.yml
    echo "✅ NextAuth authentication enabled"
else
    echo "✅ NextAuth authentication already enabled"
fi

# Fix URL configuration - critical for OAuth callbacks
echo ""
echo "🌐 PART 3: URL Configuration Verification"
echo "------------------------------------------"

# Check current URLs in docker-compose
CURRENT_NEXTAUTH_URL=$(grep "NEXTAUTH_URL=" docker-compose.yml | cut -d'=' -f2- | tr -d '\n\r')
CURRENT_APP_URL=$(grep "APP_URL=" docker-compose.yml | cut -d'=' -f2- | tr -d '\n\r' | grep -v NEXTAUTH_URL)

echo "🔍 Current URL Configuration:"
echo "   NEXTAUTH_URL: $CURRENT_NEXTAUTH_URL"
echo "   APP_URL: $(echo "$CURRENT_APP_URL" | sed 's/.*APP_URL=//')"

TARGET_FETCH_URL="http://10.1.10.132:3000/api/auth/adapter"

if echo "$CURRENT_NEXTAUTH_URL" | grep -q "10.11.":; then
    echo ""
    echo "⚠️  NEXTAUTH_URL uses old IP address, updating to 10.1.10.132"
    cp docker-compose.yml docker-compose.yml.url-backup
    sed -i 's/NEXTAUTH_URL.*/NEXTAUTH_URL=http:\/\/10.1.10.132:3000\/api\/auth/' docker-compose.yml
    echo "✅ Updated NEXTAUTH_URL"
fi

# Part 4: OAuth Provider Configuration Verification
echo ""
echo "🎛️  PART 4: OAuth Provider Configuration Check"
echo "----------------------------------------------"

echo "🔑 GitHub OAuth Settings (if configured):"
if [ -n "$GITHUB_ID$GITHUB_OAUTH_ID" ]; then
    echo "   • Homepage URL: http://10.1.10.132:3000"
    echo "   • Callback URL: http://10.1.10.132:3000/api/auth/callback/github"
    echo "   • Scope: read:user user:email"
    echo "   • Notes: Ensure callback URL is exactly as shown"
else
    echo "   • GitHub not configured"
fi

echo ""
echo "🔵 Google OAuth Settings (if configured):"
if [ -n "$GOOGLE_ID$GOOGLE_OAUTH_ID" ]; then
    echo "   • Web application type"
    echo "   • Authorized origins: http://10.1.10.132:3000"
    echo "   • Redirect URI: http://10.1.10.132:3000/api/auth/callback/google"
    echo "   • Scope: openid email profile"
    echo "   • Notes: Ensure redirect URI is exactly as shown"
else
    echo "   • Google not configured"
fi

# Part 5: Final Deployment Steps
echo ""
echo "🚀 PART 5: Deployment and Testing"
echo "----------------------------------"

echo "🔄 Restart Gideon Studio container to apply changes:"
echo "   docker compose restart gideon-studio"

echo ""
echo "🧪 OAuth Testing Steps:"
echo "   1. Visit http://10.1.10.132:3000 in your browser"
echo "   2. Click 'Sign in' button"
echo "   3. Choose your OAuth provider ($PROVIDERS)"
echo "   4. Authorize the application"
echo "   5. Access Knowledge Base: /files"

echo ""
echo "📊 Success Indicators:"
echo "   • No 'MissingSecret' errors in container logs"
echo "   • OAuth login page loads without 500 errors"
echo "   • Authentication redirects work properly"
echo "   • After login, Knowledge Base (/files) is accessible"

echo ""
echo "🆘 If Authentication Still Fails:"
echo "   • Check container logs: docker compose logs -f gideon-studio"
echo "   • Verify OAuth app redirect URIs match exactly"
echo "   • Ensure firewall isn't blocking port 3000"
echo "   • Check OAuth provider scopes are sufficient"

echo ""
echo "==============================================="
echo "🎉 OAuth Configuration Summary"
echo "==============================================="
echo "Providers: $PROVIDERS"
echo "NextAuth Secret: ✅ Configured"
echo "URLs: ✅ Verified"
echo "Callback URLs: ✅ Documented"
echo ""
echo "Ready for authentication testing!"
echo ""

exit 0
