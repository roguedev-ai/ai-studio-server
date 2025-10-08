# Remote Server Deployment Instructions

## After pulling latest changes, run these commands on jaymes@gideon-01:

### 1. Navigate to project directory
```bash
cd ~/ai-studio-server
```

### 2. Pull latest changes
```bash
git pull origin main
```

### 3. Verify .env file has correct values
```bash
# Check current .env
cat .env

# Make sure these are set:
# NEXT_AUTH_SECRET=<32+ character random string>
# GITHUB_CLIENT_ID=<your GitHub OAuth app client ID>
# GITHUB_CLIENT_SECRET=<your GitHub OAuth app client secret>
# GOOGLE_CLIENT_ID=<your Google OAuth app client ID>
# GOOGLE_CLIENT_SECRET=<your Google OAuth app client secret>
```

### 4. COMPLETE CLEANUP (removes all conflicting containers/volumes)
```bash
# Run the comprehensive cleanup script
./CLEAN_RESET.sh

# OR manually execute these commands:
docker stop $(docker ps -q) 2>/dev/null
docker rm -f $(docker ps -aq) 2>/dev/null
docker system prune -af --volumes
docker volume prune -f
docker volume rm ai-studio-server_chromadb_data ai-studio-server_minio_data 2>/dev/null || true
```

### 5. Verify credential format in .env
```bash
# Check for quotes/spaces that break OAuth (Docker Compose doesn't unquote values)
cat .env | grep -E "AUTH_GITHUB|AUTH_GOOGLE"

# Make sure credentials look EXACTLY like this (NO quotes, NO spaces):
# AUTH_GITHUB_ID=Ov23liMuXRCDw4gBgnyI
# AUTH_GITHUB_SECRET=A6c1c2c95ca2aee946ae443809a333940ab8a8a3
# NOT: AUTH_GITHUB_ID="Ov23liMuXRCDw4gBgnyI"  # Quotes break OAuth!
```

### 6. Force fresh build (bypasses all cached containers)
```bash
export DOCKER_BUILDKIT=0
docker build --no-cache -f lobe-chat-custom/Dockerfile.database -t ai-studio-server-gideon-studio .
```

### 7. Start single container system
```bash
docker compose up -d --scale gideon-studio=1
```

### 8. Monitor startup
```bash
docker compose logs -f gideon-studio
```

Look for:
- ✓ Ready in XXXms - App started
- ✓ Database migration pass - PostgreSQL ready
- ✓ NO errors about port 3000 - NextAuth URLs fixed
- ✓ NO `incorrect_client_credentials` - OAuth loaded properly

Press Ctrl+C to exit logs once you see successful startup.

### 8. Test authentication
```bash
# Check app is responding
curl -I https://studio.euctools.ai

# Visit in browser
# https://studio.euctools.ai
# Click "Sign In"
# Choose GitHub or Google
# Complete OAuth flow
```

## Troubleshooting

### If still seeing port 3000 errors:
```bash
# Check what URLs container sees
docker compose exec gideon-studio env | grep -E "APP_URL|NEXTAUTH_URL"

# Should show:
# APP_URL=http://localhost:3210
# NEXTAUTH_URL=http://localhost:3210/api/auth
```

### If OAuth credentials fail:
```bash
# Verify credentials loaded
docker compose exec gideon-studio env | grep -E "GITHUB_CLIENT|GOOGLE_CLIENT"

# Should show actual values, not "undefined"
```

### Check OAuth app settings match:
- **GitHub**: https://github.com/settings/developers
  - Homepage URL: https://studio.euctools.ai
  - Callback URL: https://studio.euctools.ai/api/auth/callback/github

- **Google**: https://console.cloud.google.com/apis/credentials
  - Authorized origins: https://studio.euctools.ai
  - Redirect URIs: https://studio.euctools.ai/api/auth/callback/google
