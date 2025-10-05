# Nginx Reverse Proxy Setup for Gideon Studio

## Overview

This script (`setup-reverse-proxy.sh`) configures nginx as a secure reverse proxy for Gideon Studio, enabling OAuth-compatible HTTPS access. It transforms your deployment from IP-based internal access to production-ready SSL-secured domain access.

## Why This Is Needed

- **OAuth Requirements**: GitHub/Google OAuth require HTTPS on standard ports
- **Security**: SSL termination with modern cipher suites
- **Production Ready**: Load balancing and DDoS protection capabilities
- **Unified Access**: Same domain for internal/external users

## What It Sets Up

```
Internet (HTTPS) ←→ nginx (SSL Termination) ←→ Docker Container (HTTP)
       ↓                                                ↓
     studio.euctools.ai                              localhost:3000
```

### Features Included

- ✅ **SSL Termination**: Modern TLSv1.2/TLSv1.3 with security headers
- ✅ **HTTP→HTTPS Redirect**: Automatic secure redirects
- ✅ **WebSocket Support**: For real-time features
- ✅ **Large File Uploads**: 100MB client_max_body_size with extended timeouts
- ✅ **Security Headers**: HSTS, CSP, X-Frame-Options
- ✅ **Let's Encrypt Ready**: ACME challenge support for renewals
- ✅ **MinIO Integration**: Optional S3 service proxying
- ✅ **Health Monitoring**: Proper timeouts and proxy buffers
- ✅ **Docker Integration**: Automatic URL updates in docker-compose.yml

## Quick Start

### Prerequisites
- SSL certificate and private key files
- Root access (`sudo`)
- Domain name (e.g., `studio.euctools.ai`)
- Gideon Studio running on port 3000

### Usage

```bash
# Make executable (first time only)
chmod +x setup-reverse-proxy.sh

# Run as root
sudo ./setup-reverse-proxy.sh
```

### Input Prompts
```
Domain name [studio.euctools.ai]:
SSL certificate path (full path):
SSL private key path (full path):
Internal Gideon Studio port [3000]:
Admin email for notifications (optional):
```

## SSL Certificate Setup

### Option 1: Let's Encrypt (Recommended)

```bash
# Install certbot
sudo apt install certbot

# Generate certificate
sudo certbot certonly --standalone --agree-tos -m admin@euctools.ai -d studio.euctools.ai

# Certificate location will be:
# /etc/letsencrypt/live/studio.euctools.ai/fullchain.pem
# /etc/letsencrypt/live/studio.euctools.ai/privkey.pem
```

### Option 2: Commercial Certificate

Place your certificate files in standard locations like:
- `/etc/ssl/certs/studio.euctools.ai.crt`
- `/etc/ssl/private/studio.euctools.ai.key`

## Post-Installation Steps

The script handles most configuration, but these steps remain manual:

### 1. Internal DNS Setup
**For workstations to access via the same domain:**

#### Single Workstation
```bash
# Add to /etc/hosts
echo '10.1.10.132 studio.euctools.ai' | sudo tee -a /etc/hosts
```

#### Multiple Machines (Recommended)
Add DNS A record:
```
studio.euctools.ai → 10.1.10.132
```

### 2. OAuth Provider Updates

#### GitHub OAuth App
```
Homepage URL: https://studio.euctools.ai
Callback URL:  https://studio.euctools.ai/api/auth/callback/github
```

#### Google OAuth App
```
Authorized Origins: https://studio.euctools.ai
Redirect URIs:      https://studio.euctools.ai/api/auth/callback/google
```

### 3. Firewall Configuration
```bash
# Check firewall status
sudo ufw status

# Allow HTTPS access
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp  # For HTTP redirect

# Optional: Block direct Docker access
sudo ufw deny 3000/tcp
```

### 4. SSL Certificate Renewal

#### Let's Encrypt Automatic
```bash
# Add to crontab
sudo crontab -e

# Weekly renewal (Sunday at 3 AM)
0 3 * * 0 certbot renew --quiet --deploy-hook 'systemctl reload nginx'
```

#### Commercial Certificate
```bash
# Monitor expiration
openssl x509 -enddate -noout -in /path/to/certificate.crt

# Add calendar reminder for renewal
```

## Verification Commands

### Test Nginx Configuration
```bash
# Test configuration syntax
sudo nginx -t

# Check nginx status
sudo systemctl status nginx
```

### Test HTTPS Access
```bash
# Test HTTPS response
curl -I https://studio.euctools.ai

# Test HTTP redirect
curl -I http://studio.euctools.ai
```

### Test Internal Access
```bash
# From workstation with DNS setup
curl -I https://studio.euctools.ai/files
```

## Troubleshooting

### Common Issues

#### "nginx: [emerg] bind() to 0.0.0.0:443 failed (98: Address already in use)"
```bash
# Find what's using port 443
sudo netstat -tlnp | grep :443

# Stop conflicting service
sudo systemctl stop apache2  # or equivalent
sudo systemctl disable apache2
```

#### "SSL certificate verify failed"
```bash
# Check certificate validity
openssl x509 -checkend 0 -noout -in /path/to/cert.crt

# Check certificate and key match
openssl x509 -modulus -noout -in cert.crt | openssl md5
openssl rsa -modulus -noout -in cert.key | openssl md5
```

#### OAuth Still Fails After Updates
```bash
# Check OAuth provider callback URLs match exactly
# Verify domain accessibility from external network
# Check logic matches provider requirements
```

### Logs And Debugging

#### Nginx Logs
```bash
# Access logs
sudo tail -f /var/log/nginx/gideon-studio-access.log

# Error logs
sudo tail -f /var/log/nginx/gideon-studio-error.log

# System logs
sudo journalctl -u nginx -f
```

#### Docker Logs
```bash
# Gideon Studio logs
docker compose logs -f gideon-studio

# Check for OAuth-related errors
docker compose logs gideon-studio | grep -i auth
```

## Configuration Details

### Nginx Configuration Location
```
/etc/nginx/sites-available/gideon-studio
/etc/nginx/sites-enabled/gideon-studio (symlink)
```

### Key Configuration Features

- **SSL Protocols**: TLSv1.2 and TLSv1.3 only
- **Security Ciphers**: ECDHE with GCM-AES
- **Session Caching**: 10m shared SSL cache
- **HSTS**: 31536000 seconds (1 year)
- **WebSocket**: Proxy upgrade handling
- **Timeouts**: 600s for large file uploads
- **Buffers**: 100M client max body size

## Backup and Recovery

### Automatic Backups
The script creates backups of:
- `/etc/nginx/nginx.conf` → `/etc/nginx/backup-pre-gideon-{timestamp}.tar.gz`
- `docker-compose.yml` → `/opt/gideon-docker-compose-{timestamp}.yml.backup`

### Manual Recovery Scripts
```bash
# Restore nginx config
sudo tar -xzf /etc/nginx/backup-pre-gideon-{timestamp}.tar.gz -C /

# Restore docker-compose.yml
cp /opt/gideon-docker-compose-{timestamp}.yml.backup ./docker-compose.yml

# Restart services
sudo systemctl restart nginx
docker compose restart gideon-studio
```

## Security Considerations

### Production Hardening
- SSL certificates are world-readable (standard for nginx)
- Private keys are 600 permissions (root only)
- Default nginx site is disabled
- Security headers (HSTS, CSP, X-Frame-Options)

### Access Control
- HTTPS enforced for main application
- HTTP allowed only for ACME challenges
- Optional port 3000 blocking for direct access

## Advanced Configuration

### Custom SSL Settings
Edit `/etc/nginx/sites-available/gideon-studio`:

```nginx
# Custom SSL configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers EECDH+AESGCM:EECDH+AES256;
ssl_prefer_server_ciphers on;
```

### Additional Proxy Headers
```nginx
# Add custom headers
proxy_set_header X-Forwarded-Host $host;
proxy_set_header X-Forwarded-Port $server_port;
```

### Rate Limiting
```nginx
# Add rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req zone=api burst=20 nodelay;
```

## Summary

The reverse proxy setup transforms Gideon Studio from:
- **Internal-only**: `http://10.1.10.132:3000` (development)
- **Production-ready**: `https://studio.euctools.ai` (OAuth-compatible)

After running the script and completing manual steps:
- ✅ OAuth providers work with HTTPS domains
- ✅ Internal/external users access the same domain
- ✅ SSL security with automatic renewals
- ✅ Production-grade nginx configuration
- ✅ Knowledge Base fully accessible via `/files`

**Next step**: Run `sudo ./setup-reverse-proxy.sh` and configure OAuth providers for full production access! 🚀
