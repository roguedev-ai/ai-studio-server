#!/bin/bash

# Gideon Studio Deployment Script
# This script sets up and deploys Gideon Studio on a remote server

echo "=== Gideon Studio AI Studio Server Deployment ==="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "Docker installed. You may need to log out and back in for group changes."
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo apt update
    sudo apt install -y docker-compose-plugin
fi

# Clone or update repository (if not already done)
if [ ! -d "gideon-studio" ]; then
    echo "Cloning Gideon Studio repository..."
    git clone https://github.com/roguedev-ai/ai-studio-server.git gideon-studio
fi

cd gideon-studio

echo ""
echo "Configuration Setup:"
echo "======================"

# Prompt for API keys and configuration
echo "Enter your Google Gemini API Key:"
read -s GOOGLE_API_KEY
echo ""

echo "Enter your NextAuth Secret (generate a secure one with: openssl rand -base64 32):"
read -s NEXTAUTH_SECRET
echo ""

echo "Enter PostgreSQL password (press enter for default 'password'):"
read -s DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-password}

echo "Enter the domain/URL for NextAuth (e.g., https://yourdomain.com):"
read NEXTAUTH_URL
NEXTAUTH_URL=${NEXTAUTH_URL:-http://localhost:3000}

# Update .env.local file
echo "Updating environment configuration..."
sed -i "s|GOOGLE_API_KEY=your-google-gemini-api-key|GOOGLE_API_KEY=$GOOGLE_API_KEY|" .env.local
sed -i "s|NEXT_AUTH_SECRET=your-nextauth-secret-key|NEXT_AUTH_SECRET=$NEXTAUTH_SECRET|" .env.local
sed -i "s|password|$DB_PASSWORD|" docker-compose.yml
sed -i "s|postgresql://gideon:password@localhost:5432/gideon_studio|postgresql://gideon:$DB_PASSWORD@localhost:5432/gideon_studio|" docker-compose.yml
sed -i "s|NEXTAUTH_URL=http://localhost:3000|NEXTAUTH_URL=$NEXTAUTH_URL|" .env.local

# Build and start services
echo "Building and starting services..."
docker-compose build --no-cache
docker-compose up -d

# Health check
echo "Waiting for services to start..."
sleep 30

if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo ""
    echo "🎉 Deployment successful!"
    echo "📖 Gideon Studio is now running at: $NEXTAUTH_URL"
    echo "🔒 Make sure to configure your firewall and SSL certificates if deploying to production"
else
    echo ""
    echo "⚠️  Deployment may have issues. Check logs with: docker-compose logs"
    echo "🔍 Troubleshooting: docker ps"
fi

echo ""
echo "Management commands:"
echo "- View logs: docker-compose logs -f"
echo "- Stop: docker-compose down"
echo "- Update: git pull && docker-compose up -d"
