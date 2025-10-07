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

### 4. Stop and clean existing deployment
```bash
docker compose down
docker rmi ai-studio-server-gideon-studio
docker builder prune -f
```

### 5. Rebuild with new configuration
```bash
docker compose build --no-cache gideon-studio
```

### 6. Start services
```bash
docker compose up -d
```

### 7. Monitor startup
```bash
docker compose logs -f gideon-studio
```

Look for:
- ✓ Ready in XXXms - App started
- ✓ NO errors about port 3000
- ✓ NO ECONNREFUSED errors

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
