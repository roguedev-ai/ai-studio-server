# Gideon Studio OAuth Setup Guide

## Overview

This guide explains how to set up OAuth authentication for Gideon Studio, enabling access to protected Knowledge Base features.

## Quick Start Options

Choose one of the automated deployment scripts:

### Option 1: GitHub OAuth
```bash
./deploy-github-auth.sh
```

### Option 2: Google OAuth
```bash
./deploy-google-auth.sh
```

### Option 3: Multi OAuth (GitHub + Google)
```bash
./deploy-multi-auth.sh
```

## Manual Setup (If you prefer manual configuration)

### Step 1: Enable Authentication in docker-compose.yml
Change the build argument from:
```yaml
NEXT_PUBLIC_ENABLE_NEXT_AUTH: "0"
```
To:
```yaml
NEXT_PUBLIC_ENABLE_NEXT_AUTH: "1"
```

### Step 2: Add Authentication Environment Variables
In the `gideon-studio` service's environment section, add:
```yaml
# Basic NextAuth configuration
- NEXTAUTH_ENABLED=1
- NEXTAUTH_URL=http://10.1.10.132:3000/api/auth

# Choose your providers:
- NEXT_AUTH_SSO_PROVIDERS=github
# OR
- NEXT_AUTH_SSO_PROVIDERS=google
# OR
- NEXT_AUTH_SSO_PROVIDERS=github,google
```

### Step 3: Configure OAuth Providers

#### GitHub OAuth Setup
1. **Create OAuth App:**
   - Go to https://github.com/settings/developers
   - Click "OAuth Apps" → "New OAuth App"

2. **Fill OAuth App Details:**
   - **Application Name:** Gideon Studio
   - **Homepage URL:** `http://10.1.10.132:3000`
   - **Authorization callback URL:** `http://10.1.10.132:3000/api/auth/callback/github`

3. **Get Credentials:**
   - **Client ID:** Copy the Client ID
   - **Client Secret:** Generate and copy the Client Secret

4. **Add to Environment:**
   ```yaml
   - AUTH_GITHUB_ID=your_github_client_id
   - AUTH_GITHUB_SECRET=your_github_client_secret
   ```

#### Google OAuth Setup
1. **Create OAuth App:**
   - Go to https://console.cloud.google.com/apis/credentials
   - Click "Create Credentials" → "OAuth client ID"

2. **Fill OAuth App Details:**
   - **Application type:** Web application
   - **Name:** Gideon Studio
   - **Authorized JavaScript origins:** `http://10.1.10.132:3000`
   - **Authorized redirect URIs:** `http://10.1.10.132:3000/api/auth/callback/google`

3. **Get Credentials:**
   - **Client ID:** Copy the Client ID
   - **Client Secret:** Copy the Client Secret

4. **Add to Environment:**
   ```yaml
   - AUTH_GOOGLE_ID=your_google_client_id
   - AUTH_GOOGLE_SECRET=your_google_client_secret
   ```

### Step 4: Generate NextAuth Secret
```bash
# Generate secure random secret
openssl rand -base64 32
```

Add to `.env`:
```bash
NEXT_AUTH_SECRET=your_generated_secret_here
KEY_VAULTS_SECRET=another_generated_secret_here
```

### Step 5: Create .env File
```bash
# .env file content
NEXT_AUTH_SECRET=your_next_auth_secret
KEY_VAULTS_SECRET=your_key_vaults_secret

# OAuth Credentials (add based on your chosen providers)
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret
# OR/AND
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Google API Key (separate from OAuth)
GOOGLE_API_KEY=your_google_gemini_api_key
```

## Testing Authentication

1. **Deploy the application:**
   ```bash
   docker compose down
   docker compose build --no-cache gideon-studio
   docker compose up -d
   ```

2. **Test the application:**
   - Visit: `http://10.1.10.132:3000`
   - Click "Sign in" button
   - Choose your configured OAuth provider
   - Complete the OAuth flow

3. **Test Knowledge Base:**
   - After login, visit: `http://10.1.10.132:3000/files`
   - Upload a document (PDF, Word, Excel)
   - Test RAG chat functionality

## Troubleshooting

### "provider is not supported" Error
- Ensure `NEXT_PUBLIC_ENABLE_NEXT_AUTH: "1"` is set as build argument
- Verify environment variables are properly set
- Check OAuth credentials are correct

### Authentication Still Fails
- Verify OAuth app callback URLs exactly match: `http://10.1.10.132:3000/api/auth/callback/{provider}`
- Check browser console for errors
- Review Docker logs: `docker compose logs gideon-studio | grep -i auth`

### 500 Errors Persist
- Ensure NextAuth is enabled at build-time, not just runtime
- Check `.env` file exists and is properly formatted
- Verify all required environment variables are set

## Security Notes

- **Keep secrets secure:** Never commit OAuth credentials to Git
- **HTTPS in production:** Use HTTPS for callback URLs in production
- **Environment separation:** Use different OAuth apps for different environments

## Configuration Reference

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `NEXTAUTH_ENABLED` | Enable NextAuth | Yes |
| `NEXT_PUBLIC_ENABLE_NEXT_AUTH` | Build-time auth enable | Yes |
| `NEXTAUTH_URL` | Base URL for NextAuth | Yes |
| `NEXT_AUTH_SECRET` | JWT signing secret | Yes |
| `NEXT_AUTH_SSO_PROVIDERS` | OAuth providers (comma-separated) | Yes |
| `AUTH_GITHUB_ID` | GitHub OAuth Client ID | If using GitHub |
| `AUTH_GITHUB_SECRET` | GitHub OAuth Client Secret | If using GitHub |
| `AUTH_GOOGLE_ID` | Google OAuth Client ID | If using Google |
| `AUTH_GOOGLE_SECRET` | Google OAuth Client Secret | If using Google |

### Build Arguments
- `NEXT_PUBLIC_ENABLE_NEXT_AUTH: "0|1"` - Controls authentication inclusion

## Next Steps

After successful authentication setup:
1. **Test Knowledge Base:** Upload documents and test RAG
2. **Phase 3 Planning:** Consider advanced features like document versioning
3. **Production Setup:** Configure HTTPS and production OAuth apps

## Support

If you encounter issues:
1. Check this manual
2. Review Docker logs for specific error messages
3. Verify OAuth app configurations
4. Test with automated scripts first

The Knowledge Base is fully functional once authentication is properly configured!
