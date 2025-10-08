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
```

### 4. COMPLETE CLEANUP (removes all conflicting containers/volumes)
```bash
# Run the comprehensive cleanup script
./CLEAN_RESET.sh
```

### 5. Fix OAuth environment variables in .env
```bash
nano .env
# Add these lines with your real OAuth credentials:
AUTH_GITHUB_ID=your-actual-github-client-id
AUTH_GITHUB_SECRET=your-actual-github-client-secret
AUTH_GOOGLE_ID=your-actual-google-client-id
AUTH_GOOGLE_SECRET=your-actual-google-client-secret

# Make sure credentials look EXACTLY like this (NO quotes, NO spaces):
# AUTH_GITHUB_ID=ya29.abc123...
# AUTH_GITHUB_SECRET=abc123...
# NOT: AUTH_GITHUB_ID="ya29.abc123..."  # Quotes break OAuth!
```

### 6. Force fresh build (bypasses all cached containers)
```bash
# CRITICAL: Build from lobe-chat-custom directory
cd lobe-chat-custom
export DOCKER_BUILDKIT=0
docker build --no-cache -f Dockerfile.database .
cd ..
```

### 7. Start single container system
```bash
docker compose up -d --scale gideon-studio=1
```

### 8. Monitor startup
```bash
docker compose logs -f gideon-studio
```

Look for successful indicators!

### 9. Test authentication
```bash
# Check app is responding
curl -I https://studio.euctools.ai

# Visit in browser to test:
# https://studio.euctools.ai
```

## Troubleshooting

### OAuth credentials fail
```bash
# Verify credentials loaded in container
docker compose exec gideon-studio env | grep -E "AUTH_GITHUB_ID"
# Should show your actual client ID
```

### GitHub OAuth "incorrect_client_credentials"
- Ensure your .env has AUTH_GITHUB_ID=your-actual-id (no quotes)
- Check GitHub OAuth app settings match the domain
- Verify the callback URLs: https://studio.euctools.ai/api/auth/callback/github
