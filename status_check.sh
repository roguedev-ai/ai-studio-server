#!/bin/bash

echo "=========================================="
echo "Gideon Studio STATUS CHECK"
echo "=========================================="
echo ""

# Check current git status
echo "🔄 Git Status:"
if git status --porcelain | grep -q "ahead\|behind"; then
    echo "   ⚠️  Local branch may be out of sync with remote"
else
    echo "   ✅ Local git appears synced" 
fi
echo "   Latest commit: $(git log --oneline -1)"
echo ""

# Check current config status
echo "📋 Current Configuration:"
echo "   NEXTAUTH_SSO_PROVIDERS in docker-compose.yml:"
grep "NEXT_AUTH_SSO_PROVIDERS=" docker-compose.yml || echo "   ❌ Not found"
echo ""

echo "   OAuth variables in .env:"
grep -c "GITHUB_CLIENT_ID=" .env >/dev/null && echo "   ✅ GitHub Client ID found" || echo "   ❌ GitHub Client ID missing"
grep -c "GOOGLE_CLIENT_ID=" .env >/dev/null && echo "   ✅ Google Client ID found" || echo "   ❌ Google Client ID missing"
echo ""

# Check if using real or placeholder credentials
echo "🔐 Credential Status Check:"
GITHUB_ID=$(grep "^GITHUB_CLIENT_ID=" .env | cut -d"=" -f2)
GOOGLE_ID=$(grep "^GOOGLE_CLIENT_ID=" .env | cut -d"=" -f2)

if echo "$GITHUB_ID" | grep -q "replace-this"; then
    echo "   ❌ GitHub: Using PLACEHOLDER credentials"
else
    echo "   ✅ GitHub: Using real credentials"
fi

if echo "$GOOGLE_ID" | grep -q "replace-this"; then
    echo "   ❌ Google: Using PLACEHOLDER credentials"
else
    echo "   ✅ Google: Using real credentials"  
fi
echo ""

# Check container status
echo "🐳 Container Status:"
if docker ps | grep -q gideon-studio; then
    echo "   ✅ Gideon Studio container is running"
else
    echo "   ❌ Gideon Studio container is not running"
fi

# Check which providers NextAuth thinks are available
echo ""
echo "🎯 NextAuth Provider Status:"
if [ -n "$DOCKER_CONTAINER" ] || docker info >/dev/null 2>&1; then
    echo "   Running SSO providers check..."
    if docker compose exec -T gideon-studio printenv NEXT_AUTH_SSO_PROVIDERS 2>/dev/null; then
        echo "   (NextAuth configured providers above)"
    else
        echo "   ❌ Cannot check container environment"
    fi
else
    echo "   ❌ Docker not available for environment check"
fi

echo ""
echo "=========================================="
echo "🚀 QUICK FIX COMMANDS:"
echo "=========================================="
echo "git pull origin main                                    # Sync latest changes"
echo "docker compose restart gideon-studio                   # Restart with new config"  
echo "docker compose logs -f gideon-studio | grep provider   # Check provider loading"
echo ""


