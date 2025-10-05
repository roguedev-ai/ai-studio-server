# Setup Guides - Production Deployment

## 🎯 Deployment Scripts Overview

This folder contains all automated deployment and setup scripts for Gideon Studio production environments.

## 📁 Available Scripts

### OAuth Authentication Deployment
- **`deploy-github-auth.sh`** - GitHub OAuth single-provider setup
- **`deploy-google-auth.sh`** - Google OAuth single-provider setup
- **`deploy-multi-auth.sh`** - GitHub + Google multi-provider OAuth setup

**Purpose**: Enables Knowledge Base authentication with GitHub/Google OAuth

### Production Infrastructure Setup
- **`setup-reverse-proxy.sh`** - Nginx SSL reverse proxy configuration

**Purpose**: Transforms development server to production HTTPS deployment

## 🚀 Quick Start Production Deployment

### 1. Choose Authentication Provider
```bash
# GitHub OAuth setup (most popular)
./deploy-github-auth.sh

# OR Google OAuth setup
./deploy-google-auth.sh

# OR Both providers
./deploy-multi-auth.sh
```

**Input Required:** OAuth credentials, auto-generates secrets, tests configuration

### 2. Configure SSL/HTTPS (If needed)
```bash
# For production OAuth compatibility
sudo ./setup-reverse-proxy.sh
```

**Input Required:** SSL certificates, domain configuration, automatic docker-compose updates

### 3. Access Production System
- **URL**: `https://your-domain.com`
- **Authentication**: OAuth provider login
- **Knowledge Base**: `/files` endpoint fully accessible

## 📊 Deployment Flow

```
1. Authentication Setup
   └── Choose provider (GitHub/Google/Multi)
   └── Enter OAuth credentials
   └── Generate secure secrets

2. SSL Reverse Proxy (Optional)
   └── Configure nginx
   └── Update Docker URLs
   └── Enable HTTPS access

3. Production Access
   └── Update OAuth provider callbacks
   └── Access via HTTPS domain
   └── Full Knowledge Base functionality
```

## 📋 Prerequisites by Environment

### Local Development
- **Required**: Gideon Studio running on port 3000
- **Required**: Docker and docker-compose
- **Optional**: Local domain resolution

### Production Server
- **Required**: SSL certificate and private key
- **Required**: Root/sudo access
- **Required**: Domain name with DNS resolution
- **Recommended**: Let's Encrypt certificates

## 🎯 What Each Script Does

### GitHub OAuth Script (`deploy-github-auth.sh`)
- Prompts for existing or new GitHub OAuth credentials
- Generates secure NextAuth secrets
- Updates docker-compose.yml authentication config
- Tests container health and connectivity
- Shows next steps for OAuth provider configuration

### Google OAuth Script (`deploy-google-auth.sh`)
- Prompts for existing or new Google OAuth credentials
- Generates secure NextAuth secrets
- Updates docker-compose.yml authentication config
- Tests container health and connectivity
- Shows next steps for OAuth provider configuration

### Multi OAuth Script (`deploy-multi-auth.sh`)
- Prompts for existing or new GitHub and/or Google credentials
- Supports partial provider configuration
- Updates docker-compose.yml for multiple providers
- Shows OAuth configuration for each enabled provider

### Reverse Proxy Script (`setup-reverse-proxy.sh`)
- Configures professional nginx reverse proxy
- Implements SSL termination with security headers
- Updates Docker environment variables to HTTPS URLs
- Enables WebSocket support and large file handling
- Provides automatic backups and recovery

## 🔐 Security Features

- **Credential Masking**: Secrets displayed with "****last4" format
- **Secure Permissions**: SSL keys set to 600 permissions
- **Environment Isolation**: .env files included in .gitignore
- **Automated Backup**: All configurations backed up before modification

## 🆘 Troubleshooting Guide

### Common OAuth Issues
- **"MissingSecret" Error**: Rerun deployment script - secrets generated automatically
- **OAuth Provider Errors**: Verify callback URLs match exactly
- **No Knowledge Base Access**: Ensure OAuth authentication completed

### Common SSL Issues
- **Certificate Validation**: Run `openssl x509 -checkend 0 -noout -in cert.crt`
- **Permissions Error**: SSL keys need 600 permissions for nginx
- **Port Conflicts**: Check port 443 availability with `netstat -tuln`

### Recovery Procedures
- **OAuth Reconfiguration**: Rerun deployment script with new credentials
- **SSL Reconfiguration**: Nginx backups in `/etc/nginx/backup-pre-gideon-*.tar.gz`
- **Docker Configuration**: Saved in `/opt/gideon-docker-compose-*.yml.backup`

## 📊 Script Specifications

| Script | Input Required | Time | Root Access | Services Modified |
|--------|---------------|------|-------------|-------------------|
| GitHub OAuth | Credentials | 15min | No | Docker containers |
| Google OAuth | Credentials | 15min | No | Docker containers |
| Multi OAuth | 1-2 Providers | 15min | No | Docker containers |
| Reverse Proxy | SSL certs, domain | 5min | Yes | nginx + Docker |

## 🎉 Success Criteria

### OAuth Deployment Success
- ✅ Containers restart successfully
- ✅ No "MissingSecret" errors in logs
- ✅ Gideon Studio accessible via OAuth login
- ✅ Knowledge Base `/files` route accessible
- ✅ Document upload and RAG chat working

### Reverse Proxy Success
- ✅ HTTPS redirects from HTTP working
- ✅ SSL certificate validation passing
- ✅ nginx logs clean of errors
- ✅ OAuth providers accept HTTPS callbacks
- ✅ Domain-based access working

## 📚 Related Documentation

- **[REVERSE-PROXY-README.md](../REVERSE-PROXY-README.md)** - Full reverse proxy guide
- **[MANUAL-OAUTH-SETUP.md](../MANUAL-OAUTH-SETUP.md)** - Manual OAuth configuration
- **[PHASE-2-COMPLETION-SUMMARY.md](PHASE-2-COMPLETION-SUMMARY.md)** - Phase 2 achievement overview

## 🚀 Next Steps After Setup

1. **OAuth Provider Updates** (as shown in script output)
2. **Internal DNS Configuration** (for consistent domain access)
3. **Knowledge Base Testing** (upload documents, test RAG)
4. **Performance Monitoring** (nginx logs, Docker resource usage)

---

**Setup Guides: Transform development builds into production deployment in minutes!** 🚀
