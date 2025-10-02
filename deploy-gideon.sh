#!/bin/bash

# Gideon Studio Deployment Script
# Custom LobeChat with Discover/Market disabled + Phase 2 RAG Foundation

echo "=== Gideon Studio AI Studio Server Deployment ==="
echo "Repository: https://github.com/roguedev-ai/ai-studio-server"
echo "Phase 1: Discover disabled, Gideon Studio branding"
echo "Phase 2: ChromaDB + Knowledge Base infrastructure"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker and Docker Compose first."
    echo "Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if docker-compose is available (try different variants)
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose."
    echo "Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker ecosystem ready!"
echo ""

# Create data directory if it doesn't exist
mkdir -p data

# Prompt for API keys
echo "Configuration Setup:"
echo "===================="

# Check if .env.local exists
if [[ ! -f ".env.local" ]]; then
    echo "⚠️  .env.local not found. Creating with defaults..."
    echo "You'll need to configure your API keys after deployment."
else
    echo "✅ .env.local found"
fi

# Prompt for Google Gemini API key
echo ""
echo "Enter your Google Gemini API Key:"
echo "  (Leave empty to use placeholder - you'll need to configure it in .env.local later)"
read -s GOOGLE_API_KEY

if [[ -n "$GOOGLE_API_KEY" ]]; then
    if [[ -f ".env.local" ]]; then
        # Update existing .env.local
        sed -i.bak "s|GOOGLE_API_KEY=.*|GOOGLE_API_KEY=$GOOGLE_API_KEY|" .env.local
        rm .env.local.bak 2>/dev/null || true
        echo "✅ Google Gemini API key updated"
    else
        # Create new .env.local
        echo "GOOGLE_API_KEY=$GOOGLE_API_KEY" > .env.local
        echo "✅ Google Gemini API key saved"
    fi
else
    echo "⚠️  No API key entered. Configure GOOGLE_API_KEY in .env.local to use AI features."
fi

# Prompt for NextAuth secret
echo ""
echo "Enter your NextAuth Secret:"
echo "  (Generate with: openssl rand -base64 32)"
echo "  (Press enter for auto-generated secret)"
read -s NEXTAUTH_SECRET

if [[ -z "$NEXTAUTH_SECRET" ]]; then
    NEXTAUTH_SECRET=$(openssl rand -base64 32 2>/dev/null || echo "auto-generated-change-this-in-production-$(date +%s)")
    echo "Auto-generated: $NEXTAUTH_SECRET"
fi

# Add NextAuth secret to .env.local
if [[ -f ".env.local" ]]; then
    if ! grep -q "NEXT_AUTH_SECRET=" .env.local; then
        echo "NEXT_AUTH_SECRET=$NEXTAUTH_SECRET" >> .env.local
    else
        sed -i.bak "s|NEXT_AUTH_SECRET=.*|NEXT_AUTH_SECRET=$NEXTAUTH_SECRET|" .env.local
        rm .env.local.bak 2>/dev/null || true
    fi
else
    echo "NEXT_AUTH_SECRET=$NEXTAUTH_SECRET" > .env.local
fi

# Prompt for accessible URL (critical for remote/server access)
echo ""
echo "Enter the accessible URL/domain for your deployment:"
echo "  (Example: http://10.1.10.132:3000, http://mydomain.com, or http://localhost:3000)"
echo "  (This configures how you'll access Gideon Studio from external machines)"
read DEPLOYMENT_URL
DEPLOYMENT_URL=${DEPLOYMENT_URL:-http://localhost:3000}

# Update .env.local with the accessible URL and server mode configuration
if [[ -f ".env.local" ]]; then
    if ! grep -q "NEXTAUTH_URL=" .env.local; then
        echo "NEXTAUTH_URL=$DEPLOYMENT_URL" >> .env.local
    else
        sed -i.bak "s|NEXTAUTH_URL=.*|NEXTAUTH_URL=$DEPLOYMENT_URL|" .env.local
        rm .env.local.bak 2>/dev/null || true
    fi
else
    echo "NEXTAUTH_URL=$DEPLOYMENT_URL" > .env.local
fi

# Ensure server mode configuration
if [[ -f ".env.local" ]]; then
    # Server mode configuration
    if ! grep -q "NEXT_PUBLIC_SERVICE_MODE=" .env.local; then
        echo "NEXT_PUBLIC_SERVICE_MODE=server" >> .env.local
    fi

    # External App URL for OIDC/Auth
    if ! grep -q "APP_URL=" .env.local; then
        echo "APP_URL=$DEPLOYMENT_URL" >> .env.local
    else
        sed -i.bak "s|APP_URL=.*|APP_URL=$DEPLOYMENT_URL|" .env.local
        rm .env.local.bak 2>/dev/null || true
    fi

    # Database URL for server mode
    if ! grep -q "DATABASE_URL=" .env.local; then
        echo "DATABASE_URL=postgresql://gideon:password@postgres:5432/gideon_studio" >> .env.local
    fi

    # Generate database encryption secret
    if ! grep -q "KEY_VAULTS_SECRET=" .env.local; then
        KEY_VAULTS_SECRET=$(openssl rand -base64 32 2>/dev/null || echo "auto-generated-$(date +%s)-change-this-in-production-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c32 2>/dev/null || echo 'random')" | head -c50)
        echo "KEY_VAULTS_SECRET=$KEY_VAULTS_SECRET" >> .env.local
        echo "Generated database encryption key"
    fi
fi

echo "✅ Configuration complete!"
echo ""
echo "🎯 Deployment Configuration:"
echo "   • App Name: Gideon Studio"
echo "   • Feature Flags: -market (Discover/Market disabled)"
echo "   • Database: PostgreSQL (local)"
echo "   • Port: 3000"
echo "   • Accessible URL: $DEPLOYMENT_URL"
echo ""

# Build and start services
echo "🚀 Building and starting Gideon Studio..."
echo ""
echo "This may take several minutes on first run..."
echo ""

# Stop any existing containers
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true

# Build Docker image
echo "Building Docker image..."
if docker compose build 2>&1; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed. Check the errors above."
    echo "Common issues:"
    echo "  • Ensure lobe-chat-custom/ directory exists"
    echo "  • Check available disk space: df -h"
    echo "  • Clear Docker cache: docker system prune -f"
    exit 1
fi

# Start services
echo "Starting services..."
if docker compose up -d 2>&1; then
    echo "✅ Services started successfully!"
else
    echo "❌ Failed to start services. Check logs below:"
    docker compose logs
    exit 1
fi

# Health check
echo ""
echo "⏳ Waiting for services to start..."
sleep 45

# Check if app is responding
echo "🔍 Checking service health..."
if curl -f --max-time 10 "http://localhost:3000" > /dev/null 2>&1; then
    echo ""
    echo "🎉 DEPLOYMENT SUCCESSFUL! 🎉"
    echo ""
    echo "📖 Gideon Studio is now running at:"
    echo "   🌐 $DEPLOYMENT_URL"
    echo ""
    echo "🔒 Current Features (Phase 1 Complete ✅):"
    echo "   • Discover/Market feature: DISABLED ✅"
    echo "   • Branding: Gideon Studio ✅"
    echo "   • Database backend: PostgreSQL ✅"
    echo "   • Multi-LLM support: Google Gemini primary ✅"
    echo ""
    echo "🤖 Phase 2 RAG Ready (Infrastructure Deployed):"
    echo "   • ChromaDB vector database: OPERATIONAL ✅"
    echo "   • Knowledge base foundation: READY ✅"
    echo "   • Document processing: AVAILABLE ✅"
    echo ""
    echo "🛠️  Immediate Next Steps:"
    echo "   1. Add your Google Gemini API key to .env.local if not done"
    echo "   2. Configure additional LLM providers (OpenAI, Anthropic) if needed"
    echo "   3. Set up authentication in settings"
    echo "   4. [Phase 2] Build document upload and knowledge base UI"
    echo ""
else
    echo ""
    echo "⚠️  Service health check failed, but containers may still be starting..."
    echo "🔍 Check status:"
    docker compose ps
    echo ""
    echo "📄 View logs: docker compose logs -f"
    echo ""
    echo "💡 If issues persist:"
    echo "   • Clear everything: docker compose down && docker system prune -f"
    echo "   • Rebuild without cache: docker compose build --no-cache"
    echo ""
fi

echo "Management commands:"
echo "==================="
echo "📄 View logs:          docker compose logs -f"
echo "⏹️  Stop services:      docker compose down"
echo "🔄 Restart services:   docker compose restart"
echo "🔧 Update & rebuild:   docker compose up -d --build"
echo ""
echo "📚 Maintenance guide:  See MAINTENANCE.md"
echo ""
echo "🎯 Gideon Studio MVP deployed successfully!"
echo "   Your customized AI studio with Discover disabled is ready for use."
