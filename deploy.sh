#!/bin/bash

# Gideon Studio Deployment Script
# This script has been updated - please use deploy-gideon.sh for customized deployment

echo "=== Gideon Studio AI Studio Server (Legacy Script) ==="
echo "⚠️  This script is deprecated. Use deploy-gideon.sh for the customized version."
echo ""
echo "To use the new deployment script:"
echo "  ./deploy-gideon.sh"
echo ""
echo "Or run legacy deployment:"

# Check if we're already in the repository directory
if [[ -f "README.md" && -f "docker-compose.yml" && -f "deploy.sh" ]]; then
    echo "Already in Gideon Studio directory"
    REPO_DIR=$(pwd)
else
    # Setup deployment directory
    DEPLOY_DIR="$HOME/gideon-studio-deployment"

    if [[ ! -d "$DEPLOY_DIR" ]]; then
        echo "Creating deployment directory: $DEPLOY_DIR"
        mkdir -p "$DEPLOY_DIR"
    fi

    cd "$DEPLOY_DIR"

    # Clone repository if not already there
    if [[ ! -d "ai-studio-server" ]]; then
        echo "Cloning Gideon Studio repository..."
        git clone https://github.com/roguedev-ai/ai-studio-server.git
    else
        echo "Repository already cloned, updating..."
        cd ai-studio-server
        git pull
        cd ..
    fi

    REPO_DIR="$DEPLOY_DIR/ai-studio-server"
fi

cd "$REPO_DIR"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh

    # Add current user to docker group
    sudo usermod -aG docker $USER
    echo ""
    echo "⚠️  IMPORTANT: Docker installed successfully!"
    echo "   You may need to log out and back in for Docker group changes to take effect."
    echo "   Or run: newgrp docker"
    echo ""
fi

# Install Docker Compose (try different methods)
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."

    # Try apt install docker-compose first (older versions)
    if sudo apt update && sudo apt install -y docker-compose 2>/dev/null; then
        echo "Docker Compose installed via apt"
    else
        # Fallback: install docker-compose-plugin (newer Docker versions)
        echo "Trying docker-compose-plugin..."
        if sudo apt update && sudo apt install -y docker-compose-plugin; then
            echo "Docker Compose plugin installed"
            # Create symlink for compatibility
            sudo ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose
        else
            echo ""
            echo "⚠️  Docker Compose installation failed. Installing manually..."

            # Manual installation as last resort
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose

            if ! command -v docker-compose &> /dev/null; then
                echo "❌ Docker Compose installation failed completely"
                echo "Please install Docker Compose manually and rerun this script"
                exit 1
            fi
        fi
    fi
fi

echo ""
echo "✅ Docker ecosystem ready!"
echo ""

echo "Configuration Setup:"
echo "===================="

# Create .env.local if it doesn't exist
if [[ ! -f ".env.local" ]]; then
    echo "# This file was created during deployment" > .env.local
    echo "# App Configuration" >> .env.local
    echo 'NEXT_PUBLIC_APP_NAME="Gideon Studio"' >> .env.local
    echo 'NEXT_PUBLIC_APP_DESCRIPTION="Your Personal AI Studio"' >> .env.local
    echo "" >> .env.local
    echo "# Authentication" >> .env.local
    echo "NEXTAUTH_URL=http://localhost:3000" >> .env.local
    echo "" >> .env.local
    echo "# Database" >> .env.local
    echo "NEXT_PUBLIC_SERVICE_MODE=server" >> .env.local
    echo "DATABASE_URL=postgresql://gideon:password@localhost:5432/gideon_studio" >> .env.local
    echo "" >> .env.local
    echo "# Placeholder - will be replaced" >> .env.local
    echo "GOOGLE_API_KEY=your-google-gemini-api-key" >> .env.local
fi

# Prompt for API keys and configuration
echo "Enter your Google Gemini API Key:"
echo "  (Leave empty to use placeholder for manual configuration later)"
read -s GOOGLE_API_KEY
if [[ -n "$GOOGLE_API_KEY" ]]; then
    sed -i "s|GOOGLE_API_KEY=.*|GOOGLE_API_KEY=$GOOGLE_API_KEY|" .env.local
    echo ""
    echo "✅ Google Gemini API key configured"
else
    echo ""
    echo "⚠️  No API key entered. You'll need to configure it manually later."
fi

echo ""
echo "Enter your NextAuth Secret (generate a secure one with: openssl rand -base64 32)"
echo "  (Or press enter to auto-generate one)"
read -s NEXTAUTH_SECRET
if [[ -z "$NEXTAUTH_SECRET" ]]; then
    NEXTAUTH_SECRET=$(openssl rand -base64 32 2>/dev/null || echo "auto-generated-secret-change-this-in-production")
    echo "Auto-generated NextAuth secret: $NEXTAUTH_SECRET"
fi

# Add NextAuth secret if not present
if ! grep -q "NEXT_AUTH_SECRET=" .env.local; then
    echo "NEXT_AUTH_SECRET=$NEXTAUTH_SECRET" >> .env.local
else
    sed -i "s|NEXT_AUTH_SECRET=.*|NEXT_AUTH_SECRET=$NEXTAUTH_SECRET|" .env.local
fi

echo ""
echo "Enter PostgreSQL password (press enter for default 'password')"
read -s DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-password}

# Update docker-compose.yml password
if [[ -f "docker-compose.yml" ]]; then
    sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$DB_PASSWORD|g" docker-compose.yml
    sed -i "s|DATABASE_URL=.*gideon_studio.*|DATABASE_URL=postgresql://gideon:$DB_PASSWORD@localhost:5432/gideon_studio|g" .env.local
else
    echo "⚠️  docker-compose.yml not found!"
fi

echo ""
echo "Enter the domain/URL for your deployment (e.g., http://10.1.10.132:3000)"
echo "  (Press enter for http://localhost:3000)"
read NEXTAUTH_URL
NEXTAUTH_URL=${NEXTAUTH_URL:-http://localhost:3000}

sed -i "s|NEXTAUTH_URL=.*|NEXTAUTH_URL=$NEXTAUTH_URL|" .env.local

echo ""
echo "🎯 Deployment Configuration Complete!"
echo "====================================="
echo "📍 URL: $NEXTAUTH_URL"
echo "🐘 Database Password: $DB_PASSWORD"
echo ""

# Build and start services
echo "🚀 Building and starting services..."
echo ""

# Stop any existing containers first
docker-compose down 2>/dev/null || true

# Build and start (capture build output but show progress)
echo "Building Docker images... (this may take a few minutes)"
if docker-compose build --no-cache 2>&1; then
    echo "✅ Build successful, starting containers..."
    if docker-compose up -d 2>&1; then
        echo ""
        echo "✅ Services started successfully!"
    else
        echo ""
        echo "❌ Failed to start services. Check logs below:"
        docker-compose logs
        exit 1
    fi
else
    echo ""
    echo "❌ Build failed. Check the errors above."
    exit 1
fi

# Health check
echo ""
echo "⏳ Waiting for services to start..."
sleep 30

echo "🔍 Checking service health..."
if curl -f --max-time 10 "$NEXTAUTH_URL" > /dev/null 2>&1; then
    echo ""
    echo "🎉 DEPLOYMENT SUCCESSFUL! 🎉"
    echo ""
    echo "📖 Gideon Studio is now running at:"
    echo "   🌐 $NEXTAUTH_URL"
    echo ""
    echo "🔒 Security notes:"
    echo "   • Change default database password in production"
    echo "   • Configure HTTPS/SSL if public-facing"
    echo "   • Review firewall settings"
    echo ""
else
    echo ""
    echo "⚠️  Service may be starting slowly or there could be issues..."
    echo "🔍 Running diagnostics:"
    echo ""
    docker-compose ps
    echo ""
    echo "📄 Last 50 lines of logs:"
    docker-compose logs --tail=50 2>/dev/null || docker-compose logs -n 50 2>/dev/null || echo "Could not retrieve logs"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   • Check logs: docker-compose logs -f"
    echo "   • View containers: docker ps"
    echo "   • Check port conflicts: netstat -tulpn | grep :3000"
    echo ""
fi

echo "Management commands:"
echo "==================="
echo "📄 View logs:          docker-compose logs -f"
echo "⏹️  Stop services:      docker-compose down"
echo "🔄 Restart services:   docker-compose restart"
echo "🔧 Update & restart:   git pull && docker-compose up -d --build"
echo ""
echo "🎯 Gideon Studio Phase 1 MVP deployed successfully!"
echo "   Your personal AI studio is ready for use."
echo ""

# Show final status
docker-compose ps 2>/dev/null || echo "Could not check status"
