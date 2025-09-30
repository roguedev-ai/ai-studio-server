# Gideon Studio Maintenance Guide

## Overview
Gideon Studio is a customized fork of LobeChat with the following modifications:
- Discover/Market feature disabled via `FEATURE_FLAGS=-market`
- Rebranded as "Gideon Studio"
- Integrated with PostgreSQL database backend
- Optimized for local deployment

## Key Customizations
Located in the `lobe-chat-custom/` directory:
- Feature flags configured in `.env.local`
- Branding environment variables set
- Source code ready for deployment

## Updating LobeChat Upstream

### Step 1: Check for Updates
```bash
cd lobe-chat-custom
git remote add upstream https://github.com/lobehub/lobe-chat.git
git fetch upstream
```

### Step 2: Create Update Branch
```bash
git checkout -b update-upstream
git merge upstream/main
```

### Step 3: Resolve Conflicts
If there are conflicts, resolve them manually, particularly:
- `.env.local` - preserve Gideon Studio configuration
- `src/assets/` - preserve custom logos if any
- `src/app/` - check for UI changes that affect branding

### Step 4: Test Build
```bash
pnpm install
pnpm build
```

### Step 5: Test Deployment
```bash
# In parent directory (ai-studio-server)
docker-compose build --no-cache
docker-compose up -d
```

## Environment Variables Reference

### Required for Basic Operation
```env
FEATURE_FLAGS=-market
NEXT_PUBLIC_APP_NAME="Gideon Studio"
DATABASE_URL=postgresql://gideon:password@localhost:5432/gideon_studio
GOOGLE_API_KEY=your-google-gemini-api-key
```

### Optional Enhancements
```env
OPENAI_API_KEY=your-openai-key
ANTHROPIC_API_KEY=your-anthropic-key
OLLAMA_PROXY_URL=http://127.0.0.1:11434
```

## Feature Flags
- `-market` - Disables assistant market/discover feature
- `-welcome_suggest` - Disables welcome suggestions
- `-check_updates` - Disables update checking

## Troubleshooting

### Build Issues
- Clear Docker cache: `docker system prune -a`
- Clear pnpm cache: `pnpm store prune`
- Reinstall dependencies: `pnpm install --frozen-lockfile`

### Runtime Issues
- Check logs: `docker-compose logs gideon-studio`
- Database connection: Verify PostgreSQL is running on port 5432
- Environment variables: Check `.env.local` for correct values

## Performance Optimization
- Enable Docker layer caching for faster rebuilds
- Use `docker build --build-arg BUILDKIT_INLINE_CACHE=1` for layer caching
- Consider using a reverse proxy (nginx) for production deployments

## Backup Strategy
- Database backups: Use PostgreSQL pg_dump regularly
- Configuration backups: Backup `.env.local` file securely
- Code backups: Keep the custom fork in a private repository

## Contact
For issues specific to Gideon Studio customizations, check this documentation first before consulting LobeChat upstream documentation.
