# Gideon Studio - Personal AI Studio Platform

> 🤖 Your Personal AI Studio - Complete Control, Maximum Privacy, Unlimited Extensibility

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com)
[![TypeScript](https://img.shields.io/badge/typescript-%23007ACC.svg?style=for-the-badge&logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Next.js](https://img.shields.io/badge/Next.js-%23000000.svg?style=for-the-badge&logo=next.js&logoColor=white)](https://nextjs.org)
[![PostgreSQL](https://img.shields.io/badge/postgresql-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![React](https://img.shields.io/badge/react-%2320232a.svg?style=for-the-badge&logo=react&logoColor=%2361DAFB)](https://reactjs.org)

## 🔐 Privacy-First, AI-Powered Studio

Gideon Studio is a personal AI assistant platform built on Lobe Chat that gives you complete control over your data and AI interactions. Deploy locally or on your own infrastructure with support for multiple LLM providers (OpenAI, Anthropic, Google Gemini, Ollama, etc.).

## ✨ Key Features

- 🌐 **Browser-Based Access** - Secure local deployment with JWT authentication
- 🤖 **Multi-LLM Support** - Seamless switching between AI providers (GPT, Claude, Gemini, etc.)
- 🔧 **MCP Integration** - Extend functionality with Model Context Protocol servers
- 🧠 **RAG & Knowledge Base** - Upload documents and create private knowledge bases
- 🎨 **Personal Customization** - Themes, backgrounds, and branding (coming in Phase 4)
- 🔒 **Zero Data Leakage** - Complete local control over conversations and API keys
- 📱 **Modern UI** - Built with Next.js, React, and TailwindCSS

## 🚀 Quick Deploy

### Automatic Deployment (Recommended)

```bash
# Download and run the deployment script
wget https://raw.githubusercontent.com/roguedev-ai/ai-studio-server/main/deploy.sh
chmod +x deploy.sh
./deploy.sh
```

The script will:
- Install Docker and Docker Compose
- Prompt for your API keys (Google Gemini, NextAuth secret, etc.)
- Start all services automatically
- Run health checks

### Manual Docker Deployment

```bash
# Clone the repository
git clone https://github.com/roguedev-ai/ai-studio-server.git
cd ai-studio-server

# Configure environment (edit .env.local)
cp .env.local.example .env.local
# Add your API keys to .env.local

# Start with Docker Compose
docker-compose up -d
```

## 📦 Requirements

- Ubuntu/Debian server with sudo access
- 4GB+ RAM recommended
- Docker and Docker Compose will be installed automatically

## 🔧 Configuration

### Supported AI Providers (add to .env.local)

```env
# Google Gemini (primary)
GOOGLE_API_KEY=your-google-gemini-api-key

# Additional providers (optional)
OPENAI_API_KEY=your-openai-key
ANTHROPIC_API_KEY=your-anthropic-key
OLLAMA_PROXY_URL=http://127.0.0.1:11434
```

### Database Setup

PostgreSQL is included in the Docker Compose setup. Access at:
- **Internal:** `postgresql://gideon:password@postgres:5432/gideon_studio`
- **External (development):** `postgresql://localhost:5432/gideon_studio`

## 🛠️ Development

### Prerequisites

```bash
# Install Node.js (LTS 18+)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install dependencies
pnpm install

# Copy environment file
cp .env.example .env.local
# Configure your API keys in .env.local
```

### Start Development Server

```bash
pnpm dev
```

Open [http://localhost:3010](http://localhost:3010)

## 🗺️ Roadmap

### Phase 1: MVP ✅
- [x] Multi-LLM support with Google Gemini
- [x] JWT authentication
- [x] Docker deployment
- [x] Basic chat interface

### Phase 2: RAG & Knowledge (In Progress)
- [ ] ChromaDB integration
- [ ] Document upload and processing
- [ ] RAG-enhanced responses
- [ ] Knowledge base UI

### Phase 3: MCP Integration
- [ ] Model Context Protocol client
- [ ] MCP server marketplace
- [ ] Tool management interface

### Phase 4: Personalization Studio
- [ ] Advanced theme engine
- [ ] Custom backgrounds and branding
- [ ] Settings dashboard
- [ ] Multi-device responsive design

### Phase 5: Production Ready
- [ ] Enterprise security hardening
- [ ] Performance monitoring
- [ ] Backup and restore
- [ ] Multi-user support (family/team)

## 🤝 Contributing

This is a personal project based on the open-source [Lobe Chat](https://github.com/lobehub/lobe-chat) framework. Feel free to fork and customize for your needs.

## 📄 License

MIT License - see [LICENSE](./LICENSE)

## 🙏 Acknowledgments

Built on the excellent [Lobe Chat](https://github.com/lobehub/lobe-chat) framework by LobeHub team. Special thanks for the open-source foundation that makes personal AI deployment possible.

---

**🔔 Note:** This project is for personal use. For commercial deployment, please review the base framework's licensing.
