#!/bin/bash
# Final OAuth Completion Fix
# Addresses all remaining OAuth issues after pulling latest changes

echo "=========================================="
echo "FINAL OAUTH COMPLETION FIX"
echo "=========================================="
echo ""

# Check git status
echo "🔄 Checking git synchronization..."
if git status --porcelain | grep -q "^<<"; then
    echo "   ❌ Local repo conflicts - resolve first"
    echo "   Run: git status && git pull --no-edit origin main"
    exit 1
fi

if git log --oneline -1 | grep -q "both.*GitHub.*Google"; then
    echo "   ✅ Latest OAuth fix commit present"
else
    echo "   ❌ Latest OAuth fix missing - run: git pull origin main"
fi
echo ""

# Clean any corrupted .env values
echo "🧹 Checking for environment variable issues..."
echo "   Current .env variable status:"

# Extract credential values
GITHUB_ID=$(grep "^GITHUB_CLIENT_ID=" .env | cut -d'=' -f2- | tr -d '\r\n')
GITHUB_SECRET=$(grep "^GITHUB_CLIENT_SECRET=" .env | cut -d'=' -f2- | tr -d '\r\n')
GOOGLE_ID=$(grep "^GOOGLE_CLIENT_ID=" .env | cut -d'=' -f2- | tr -d '\r\n') 
GOOGLE_SECRET=$(grep "^GOOGLE_CLIENT_SECRET=" .env | cut -d'=' -f2- | tr -d '\r\n')

echo "   GitHub ID: ${GITHUB_ID:-"NOT SET"}"
echo "   Google ID: ${GOOGLE_ID:-"NOT SET"}"

# Check for placeholder values
PLACEHOLDER_FOUND=false
if echo "$GITHUB_ID" | grep -q "replace-this"; then
    echo "   ⚠️  GitHub using PLACEHOLDER credentials"
    PLACEHOLDER_FOUND=true
fi
if echo "$GOOGLE_ID" | grep -q "replace-this"; then
    echo "   ⚠️  Google using PLACEHOLDER credentials"
    PLACEHOLDER_FOUND=true
fi

if [ "$PLACEHOLDER_FOUND" = true ]; then
    echo ""
    echo "🚨 IMPORTANT: You still have placeholder credentials!"
    echo "   Replace these lines in your .env file:"
    echo ""
    echo "   GITHUB_CLIENT_ID=your-github-client-id-replace-this"
    echo "   GITHUB_CLIENT_SECRET=your-github-client-secret-replace-this"
    echo ""
    echo "   GOOGLE_CLIENT_ID=your-google-client-id-replace-this" 
    echo "   GOOGLE_CLIENT_SECRET=your-google-client-secret-replace-this"
    echo ""
    echo "   With your REAL OAuth app credentials"
    echo ""
fi

# Force container rebuild to ensure clean cache
echo "🔄 Ensuring clean container config..."
echo "   Stopping existing containers..."
docker compose down 2>/dev/null

echo "   Cleaning old container images..."
docker rmi ai-studio-server-gideon-studio 2>/dev/null || true

echo "   Rebuilding from scratch (this rebuilds with correct OAuth config)..."
docker compose build --no-cache gideon-studio

echo "   Starting fresh container..."
docker compose up -d

echo "   Waiting for container to be ready..."
sleep 30

# Verify OAuth providers
echo ""
echo "🎛️  Verifying OAuth provider status..."
if command -v docker >/dev/null 2>&1; then
    # Check what SSO providers NextAuth sees
    SSO_COUNT=$(docker compose exec -T gideon-studio bash -c 'echo $NEXT_AUTH_SSO_PROVIDERS' 2>/dev/null | tr ',' '\n' | wc -l)
    echo "   SSO providers loaded: $SSO_COUNT providers"
    
    if [ "$SSO_COUNT" -ge 2 ]; then
        echo "   ✅ Both GitHub and Google providers are enabled!"
    elif [ "$SSO_COUNT" -eq 1 ]; then
        echo "   ⚠️  Only one provider loaded"
        if echo "$GOOGLE_ID" | grep -q "replace-this"; then
            echo "       → Google disabled due to placeholder credentials"
        fi
    else
        echo "   ❌ No providers loaded!"
    fi
else
    echo "   ❌ Cannot verify - Docker not available"
fi

# Final success check
echo ""
echo "🎯 FINAL OAUTH STATUS:"
if [ "$PLACEHOLDER_FOUND" = true ]; then
    echo "   ❌ PLACEHOLDER credentials still in use"
    echo "   → Replace placeholders in .env, then restart"
else
    echo "   ✅ Real credentials detected"
fi

if docker compose ps | grep -q "gideon-studio.*Up"; then
    echo "   ✅ Container running successfully"
else
    echo "   ❌ Container not running properly"
fi

echo ""
echo "=========================================="
echo " 🚀 READY FOR OAUTH TESTING"
echo "=========================================="
echo ""
echo " Access your site:"
if [ "$PLACEHOLDER_FOUND" = false ]; then
    echo " 🔥 https://studio.euctools.ai"
    echo ""
    echo " You should see BOTH login buttons:"
    echo " • 🔵 Sign in with Google"
    echo " • ⚫ Sign in with GitHub"
    echo ""
    echo " Complete the OAuth flow for either provider and access Knowledge Base!"
else
    echo " ⚠️  Visit https://studio.euctools.ai AFTER replacing placeholder credentials"
    echo ""
    echo " Currently only GitHub will work until Google credentials are real"
fi
echo ""
echo " Troubleshooting:"
echo " • Logs: docker compose logs -f gideon-studio | grep -E 'auth|oauth|error'"
echo " • Config check: docker compose exec gideon-studio env | grep SSO"
echo ""

