#!/bin/bash
# Gideon Studio Safe Branding Deployment Script
# Safely deploys custom branding with backup and rollback capabilities

set -e  # Exit on any error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./branding-backups/$TIMESTAMP"

# Safety flags
DRY_RUN=false
FORCE=false

# Show usage
usage() {
    cat << EOF
Gideon Studio Safe Branding Deployment Script

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --dry-run       Preview changes without making them
  --force         Skip confirmations (not recommended)
  --help          Show this help message

DESCRIPTION:
  This script safely deploys custom branding assets with full backup
  and rollback capability for your Gideon Studio deployment.

FEATURES:
  • Automatic backups before any changes
  • File validation before copying
  • Generated rollback scripts
  • Dry-run mode to preview changes
  • Safe docker rebuilds

EXAMPLES:
  $0                           # Interactive deployment
  $0 --dry-run                 # Preview changes only
  $0 --help                    # Show this help
EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            echo ""
            usage
            ;;
    esac
done

# Safety check - running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: This script should not be run as root.${NC}"
    exit 1
fi

# Header
echo "=========================================="
echo "Gideon Studio Branding Deployment"
echo "=========================================="
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}⚠️  DRY RUN MODE - No changes will be made${NC}"
else
    echo -e "${GREEN}✓ Full deployment mode${NC}"
fi

echo ""

# Check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker not found. Please install Docker.${NC}"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Error: docker-compose not found. Please install docker-compose.${NC}"
        exit 1
    fi

    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}Error: docker-compose.yml not found. Are you in the right directory?${NC}"
        exit 1
    fi

    if docker compose ps | grep -q "gideon-studio.*Up"; then
        echo -e "${GREEN}✓ Container is running${NC}"
    else
        echo -e "${YELLOW}⚠️  Container is not running. Will not perform live restart.${NC}"
    fi

    echo -e "${GREEN}✓ Prerequisites check passed${NC}"
}

# Confirm operation
confirm_operation() {
    if [ "$FORCE" = true ] || [ "$DRY_RUN" = true ]; then
        return 0
    fi

    echo "=========================================="
    echo "DEPLOYMENT INFORMATION"
    echo "=========================================="
    echo "This script will:"
    echo "  1. 📦 Copy custom branding assets"
    echo "  2. 💾 Create automatic backups"
    echo "  3. 🔧 Update configuration files"
    echo "  4. 🔄 Generate rollback scripts"
    echo "  5. 🚀 Rebuild containers (if confirmed)"
    echo ""
    echo -e "${YELLOW}⚠️  All changes will be backed up automatically${NC}"

    echo ""
    read -p "Continue with branding deployment? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted by user."
        exit 0
    fi
    echo ""
}

# Part 1: Information Gathering
gather_branding_info() {
    echo "📋 Branding Asset Configuration"
    echo "-------------------------------"
    echo "Provide paths to your custom branding files."
    echo "Press Enter to skip optional items (will use defaults)."
    echo ""

    # Logo file
    while true; do
        read -p "Path to logo file (SVG/PNG) [./assets/logo.svg or leave empty for default]: " LOGO_PATH
        if [ -z "$LOGO_PATH" ]; then
            LOGO_PATH=""
            break
        elif [ -f "$LOGO_PATH" ]; then
            break
        else
            echo -e "${YELLOW}⚠️  File not found: $LOGO_PATH${NC}"
            echo "Please provide a valid path or press Enter for default."
        fi
    done

    # Favicon
    while true; do
        read -p "Path to favicon (ICO/PNG/SVG) [./assets/favicon.ico or leave empty]: " FAVICON_PATH
        if [ -z "$FAVICON_PATH" ]; then
            FAVICON_PATH=""
            break
        elif [ -f "$FAVICON_PATH" ]; then
            break
        else
            echo -e "${YELLOW}⚠️  File not found: $FAVICON_PATH${NC}"
            echo "Please provide a valid path or press Enter for default."
        fi
    done

    # Custom CSS
    while true; do
        read -p "Path to custom CSS file [./assets/custom.css or leave empty for generated]: " CSS_PATH
        if [ -z "$CSS_PATH" ]; then
            CSS_PATH=""
            break
        elif [ -f "$CSS_PATH" ]; then
            break
        else
            echo -e "${YELLOW}⚠️  File not found: $CSS_PATH${NC}"
            echo "Please provide a valid path or press Enter for default."
        fi
    done

    # Welcome content
    while true; do
        read -p "Path to welcome markdown [./assets/welcome.md or leave empty for default]: " WELCOME_PATH
        if [ -z "$WELCOME_PATH" ]; then
            WELCOME_PATH=""
            break
        elif [ -f "$WELCOME_PATH" ]; then
            break
        else
            echo -e "${YELLOW}⚠️  File not found: $WELCOME_PATH${NC}"
            echo "Please provide a valid path or press Enter for default."
        fi
    done

    echo ""
    echo "🏢 Application Branding Information"
    echo "-----------------------------------"

    read -p "Application name [Gideon Studio]: " APP_NAME
    APP_NAME=${APP_NAME:-"Gideon Studio"}

    read -p "Application description [Your Personal AI Studio]: " APP_DESC
    APP_DESC=${APP_DESC:-"Your Personal AI Studio"}

    read -p "Company name [EUC Tools]: " COMPANY_NAME
    COMPANY_NAME=${COMPANY_NAME:-"EUC Tools"}

    read -p "Support email [support@euctools.ai]: " SUPPORT_EMAIL
    SUPPORT_EMAIL=${SUPPORT_EMAIL:-"support@euctools.ai"}

    while true; do
        read -p "Primary color (hex) [#2563eb]: " PRIMARY_COLOR
        PRIMARY_COLOR=${PRIMARY_COLOR:-"#2563eb"}
        # Basic hex validation
        if [[ ! $PRIMARY_COLOR =~ ^#[0-9A-Fa-f]{6}$ ]] && [[ ! $PRIMARY_COLOR =~ ^#[0-9A-Fa-f]{3}$ ]]; then
            echo -e "${YELLOW}⚠️  Invalid hex color: $PRIMARY_COLOR${NC}"
            echo "Please use format like #2563eb or #25e"
        else
            break
        fi
    done

    while true; do
        read -p "Accent color (hex) [#7c3aed]: " ACCENT_COLOR
        ACCENT_COLOR=${ACCENT_COLOR:-"#7c3aed"}
        # Basic hex validation
        if [[ ! $ACCENT_COLOR =~ ^#[0-9A-Fa-f]{6}$ ]] && [[ ! $ACCENT_COLOR =~ ^#[0-9A-Fa-f]{3}$ ]]; then
            echo -e "${YELLOW}⚠️  Invalid hex color: $ACCENT_COLOR${NC}"
            echo "Please use format like #7c3aed or #7ca"
        else
            break
        fi
    done

    # Sanitize for filenames
    APP_NAME_SAFE=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g')

    echo ""
    echo -e "${GREEN}✓ Branding configuration gathered${NC}"
    echo ""

    # Show summary
    echo "Branding Summary:"
    echo "  App Name: $APP_NAME"
    echo "  Description: $APP_DESC"
    echo "  Company: $COMPANY_NAME"
    echo "  Primary: $PRIMARY_COLOR"
    echo "  Accent: $ACCENT_COLOR"
    echo ""

    if [ -n "$LOGO_PATH" ]; then
        echo -e "  Logo: ${GREEN}✓ Will copy from $LOGO_PATH${NC}"
    else
        echo -e "  Logo: ${YELLOW}⚠️  Will generate default${NC}"
    fi

    if [ -n "$FAVICON_PATH" ]; then
        echo -e "  Favicon: ${GREEN}✓ Will copy from $FAVICON_PATH${NC}"
    else
        echo -e "  Favicon: ${YELLOW}⚠️  Will use default${NC}"
    fi

    if [ -n "$CSS_PATH" ]; then
        echo -e "  CSS: ${GREEN}✓ Will copy from $CSS_PATH${NC}"
    else
        echo -e "  CSS: ${YELLOW}⚠️  Will generate with colors${NC}"
    fi

    if [ -n "$WELCOME_PATH" ]; then
        echo -e "  Welcome: ${GREEN}✓ Will copy from $WELCOME_PATH${NC}"
    else
        echo -e "  Welcome: ${YELLOW}⚠️  Will generate default${NC}"
    fi
    echo ""
}

# Part 2: Create Backups
create_backups() {
    echo "💾 Creating Backups"
    echo "-------------------"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}⚠️  DRY RUN: Would create backup directory: $BACKUP_DIR${NC}"
        echo -e "${YELLOW}⚠️  DRY RUN: Would backup docker-compose.yml, public/, styles/, README.md${NC}"
        return 0
    fi

    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    echo -e "${GREEN}✓ Created backup directory: $BACKUP_DIR${NC}"

    # Backup docker-compose.yml
    if [ -f "docker-compose.yml" ]; then
        cp "docker-compose.yml" "$BACKUP_DIR/docker-compose.yml.backup"
        echo -e "${GREEN}✓ Backed up docker-compose.yml${NC}"
    else
        echo -e "${YELLOW}⚠️  docker-compose.yml not found, skipping backup${NC}"
    fi

    # Backup .env file
    if [ -f ".env" ]; then
        cp ".env" "$BACKUP_DIR/.env.backup"
        echo -e "${GREEN}✓ Backed up .env file${NC}"
    fi

    # Backup public assets
    if [ -d "public" ]; then
        cp -r "public" "$BACKUP_DIR/public.backup" 2>/dev/null || true
        echo -e "${GREEN}✓ Backed up public/ directory${NC}"
    fi

    # Backup styles
    if [ -d "styles" ]; then
        cp -r "styles" "$BACKUP_DIR/styles.backup" 2>/dev/null || true
        echo -e "${GREEN}✓ Backed up styles/ directory${NC}"
    fi

    # Backup root README if exists
    if [ -f "README.md" ]; then
        cp "README.md" "$BACKUP_DIR/README.md.backup"
        echo -e "${GREEN}✓ Backed up README.md${NC}"
    fi

    echo -e "${GREEN}✓ All backups saved to: $BACKUP_DIR${NC}"
}

# Part 3: Deploy Branding Assets
deploy_assets() {
    echo "📦 Deploying Branding Assets"
    echo "----------------------------"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}⚠️  DRY RUN: Would create public/images/, styles/ directories${NC}"
        echo -e "${YELLOW}⚠️  DRY RUN: Would deploy logo, favicon, CSS, welcome content${NC}"
        return 0
    fi

    # Create necessary directories
    mkdir -p "public/images"
    mkdir -p "styles"

    # Deploy logo
    if [ -n "$LOGO_PATH" ]; then
        LOGO_EXT=$(basename "$LOGO_PATH" | sed 's/.*\.//')
        LOGO_FILENAME="gideon-logo.$LOGO_EXT"
        cp "$LOGO_PATH" "public/images/$LOGO_FILENAME"
        LOGO_URL="/images/$LOGO_FILENAME"
        echo -e "${GREEN}✓ Copied logo → public/images/$LOGO_FILENAME${NC}"
    else
        # Generate default logo with SVG
        LOGO_FILENAME="gideon-logo.svg"
        cat > "public/images/$LOGO_FILENAME" << EOF
<svg width="200" height="50" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" style="stop-color="$PRIMARY_COLOR" stop-opacity="1" />
      <stop offset="100%" style="stop-color="$ACCENT_COLOR" stop-opacity="1" />
    </linearGradient>
  </defs>
  <circle cx="25" cy="25" r="20" fill="url(#grad1)" />
  <text x="55" y="32" font-family="Arial,sans-serif" font-size="18" font-weight="600" fill="#1e293b">$APP_NAME</text>
</svg>
EOF
        LOGO_URL="/images/$LOGO_FILENAME"
        echo -e "${GREEN}✓ Generated default logo → public/images/$LOGO_FILENAME${NC}"
    fi

    # Deploy favicon
    if [ -n "$FAVICON_PATH" ]; then
        cp "$FAVICON_PATH" "public/favicon.ico"
        echo -e "${GREEN}✓ Copied favicon → public/favicon.ico${NC}"
    else
        echo -e "${YELLOW}⚠️  No favicon provided - using default if available${NC}"
    fi

    # Deploy custom CSS or generate default
    if [ -n "$CSS_PATH" ]; then
        cp "$CSS_PATH" "styles/gideon-custom.css"
        echo -e "${GREEN}✓ Copied custom CSS → styles/gideon-custom.css${NC}"
    else
        # Generate CSS with user's colors
        cat > "styles/gideon-custom.css" << EOF
:root {
  --gideon-primary: $PRIMARY_COLOR;
  --gideon-accent: $ACCENT_COLOR;
}

.site-logo {
  content: url('$LOGO_URL');
}

button[data-primary="true"], .btn-primary {
  background: linear-gradient(135deg, var(--gideon-primary), var(--gideon-accent));
}

.site-header {
  background: linear-gradient(135deg, $PRIMARY_COLOR, $ACCENT_COLOR);
}

.site-title {
  color: $PRIMARY_COLOR;
}
EOF
        echo -e "${GREEN}✓ Generated custom CSS with your colors → styles/gideon-custom.css${NC}"
    fi

    # Deploy welcome content
    if [ -n "$WELCOME_PATH" ]; then
        cp "$WELCOME_PATH" "public/welcome.md"
        echo -e "${GREEN}✓ Copied welcome content → public/welcome.md${NC}"
    else
        cat > "public/welcome.md" << EOF
# Welcome to $APP_NAME

$APP_DESC

Powered by $COMPANY_NAME

## Support
For support, please contact: $SUPPORT_EMAIL

## Features
- AI-powered document analysis
- Knowledge base management
- Secure file processing
- OAuth authentication

---

© $(date +%Y) $APP_NAME by $COMPANY_NAME
EOF
        echo -e "${GREEN}✓ Generated welcome content → public/welcome.md${NC}"
    fi

    echo -e "${GREEN}✓ All branding assets deployed${NC}"
}

# Part 4: Update Configuration
update_config() {
    echo "🔧 Updating Configuration"
    echo "------------------------"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}⚠️  DRY RUN: Would update docker-compose.yml with branding variables${NC}"
        echo -e "${YELLOW}⚠️  DRY RUN: Would create .env.branding with new variables${NC}"
        return 0
    fi

    # Create branding environment variables
    cat >> ".env.branding.$TIMESTAMP" << EOF
# Gideon Studio Branding Configuration - Generated $TIMESTAMP
NEXT_PUBLIC_APP_NAME=$APP_NAME
NEXT_PUBLIC_APP_DESCRIPTION=$APP_DESC
NEXT_PUBLIC_COMPANY_NAME=$COMPANY_NAME
NEXT_PUBLIC_SUPPORT_EMAIL=$SUPPORT_EMAIL
NEXT_PUBLIC_BRANDING_LOGO_URL=$LOGO_URL
NEXT_PUBLIC_THEME_PRIMARY_COLOR=$PRIMARY_COLOR
NEXT_PUBLIC_THEME_ACCENT_COLOR=$ACCENT_COLOR
NEXT_PUBLIC_FOOTER_TEXT=© $(date +%Y) $COMPANY_NAME
EOF

    echo -e "${GREEN}✓ Created branding configuration → .env.branding.$TIMESTAMP${NC}"
    echo ""
    echo -e "${YELLOW}📋 MANUAL STEP REQUIRED:${NC}"
    echo "  Add the contents of '.env.branding.$TIMESTAMP' to your .env file"
    echo ""
    echo "  Example commands:"
    echo "    cat .env.branding.$TIMESTAMP >> .env"
    echo "    # Then restart container: docker compose restart gideon-studio"
    echo ""
    echo -e "${BLUE}Note: This approach avoids modifying your .env file automatically${NC}"
    echo ""
}

# Part 5: Create Rollback Script
create_rollback() {
    echo "🔄 Creating Rollback Script"
    echo "---------------------------"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}⚠️  DRY RUN: Would create rollback script: rollback-branding-$TIMESTAMP.sh${NC}"
        return 0
    fi

    cat > "rollback-branding-$TIMESTAMP.sh" << EOF
#!/bin/bash
# Rollback script for branding deployed at $TIMESTAMP
# Restores all files from backup directory: $BACKUP_DIR

set -e

echo "=========================================="
echo "BRANDING ROLLBACK - $TIMESTAMP"
echo "=========================================="
echo ""
echo "This will restore all files to their state BEFORE branding deployment."
echo "Original branding files will be moved to 'brand-archive/' directory."
echo ""
read -p "Proceed with rollback? (yes/no): " CONFIRM
if [ "\$CONFIRM" != "yes" ]; then
    echo "Rollback cancelled."
    exit 0
fi

echo ""
echo "🔄 Starting rollback..."

# Archive current branding files
BRAND_ARCHIVE="brand-archive-$TIMESTAMP"
mkdir -p "\$BRAND_ARCHIVE"

# Move current branding files to archive
[ -d "public" ] && mv "public" "\$BRAND_ARCHIVE/" 2>/dev/null || true
[ -d "styles" ] && mv "styles" "\$BRAND_ARCHIVE/" 2>/dev/null || true

echo "✓ Archived current branding to: \$BRAND_ARCHIVE"

# Restore backups
if [ -f "$BACKUP_DIR/docker-compose.yml.backup" ]; then
    cp "$BACKUP_DIR/docker-compose.yml.backup" docker-compose.yml
    echo "✓ Restored docker-compose.yml"
else
    echo "⚠️  No docker-compose.yml backup found"
fi

if [ -f "$BACKUP_DIR/.env.backup" ]; then
    cp "$BACKUP_DIR/.env.backup" .env
    echo "✓ Restored .env file"
else
    echo "⚠️  No .env backup found"
fi

# Restore directories
if [ -d "$BACKUP_DIR/public.backup" ]; then
    cp -r "$BACKUP_DIR/public.backup" public
    echo "✓ Restored public/ directory"
fi

if [ -d "$BACKUP_DIR/styles.backup" ]; then
    cp -r "$BACKUP_DIR/styles.backup" styles
    echo "✓ Restored styles/ directory"
fi

if [ -f "$BACKUP_DIR/README.md.backup" ]; then
    cp "$BACKUP_DIR/README.md.backup" README.md
    echo "✓ Restored README.md"
fi

# Rebuild container
echo ""
echo "🔄 Rebuilding container..."
docker compose down
docker compose build --no-cache gideon-studio --pull 2>/dev/null || docker compose build --no-cache gideon-studio
docker compose up -d git pull origin main

echo ""
echo "✓ Rollback complete!"
echo ""
echo "Archived branding: ./\$BRAND_ARCHIVE/"
echo ""
echo "=========================================="

EOF

    chmod +x "rollback-branding-$TIMESTAMP.sh"
    echo -e "${GREEN}✓ Created rollback script: rollback-branding-$TIMESTAMP.sh${NC}"

    # Show rollback script content summary
    echo ""
    echo "Rollback script will restore:"
    echo "  • docker-compose.yml"
    echo "  • .env file"
    echo "  • public/ directory"
    echo "  • styles/ directory"
    echo "  • Then rebuild container"
    echo ""
}

# Part 6: Container Deployment
deploy_container() {
    echo "🚀 Container Deployment"
    echo "----------------------"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}⚠️  DRY RUN: Would stop and rebuild container${NC}"
        return 0
    fi

    if [ "$FORCE" = true ]; then
        REBUILD="yes"
    else
        echo "Branding deployment complete. The container needs to rebuild to apply changes."
        echo ""
        read -p "Rebuild and restart container now? (yes/no): " REBUILD
    fi

    if [ "$REBUILD" = "yes" ]; then
        echo -e "${BLUE}Stopping containers...${NC}"
        docker compose down

        echo -e "${BLUE}Building container with new branding...${NC}"
        docker compose build --no-cache gideon-studio --pull 2>/dev/null || docker compose build --no-cache gideon-studio

        echo -e "${BLUE}Starting containers...${NC}"
        docker compose up -d

        echo -e "${BLUE}Waiting for startup...${NC}"
        sleep 30

        # Check if container started successfully
        if docker compose ps | grep -q "gideon-studio.*Up"; then
            echo -e "${GREEN}✓ Container restarted successfully${NC}"

            # Check if it's responding
            if timeout 10 docker compose exec -T gideon-studio curl -f http://localhost:3210/health 2>/dev/null; then
                echo -e "${GREEN}✓ Application is responding${NC}"
            else
                echo -e "${YELLOW}⚠️  Application may still be starting, health check timed out${NC}"
            fi
        else
            echo -e "${RED}❌ Container failed to start${NC}"
            echo -e "${YELLOW}⚠️  Run 'docker compose logs gideon-studio' for details${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Skipped rebuild. Run manually:${NC}"
        echo "  docker compose down"
        echo "  docker compose build --no-cache gideon-studio"
        echo "  docker compose up -d"
        echo ""
        echo "Or use the rollback script if needed."
    fi
}

# Part 7: Final Summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "BRANDING DEPLOYMENT SUMMARY"
    echo "=========================================="
    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}⚠️  DRY RUN COMPLETED - No changes made${NC}"
        echo ""
        echo "This was a preview. Run without --dry-run to make actual changes."
    else
        echo -e "${GREEN}✓ Branding deployment completed${NC}"
    fi

    echo ""
    echo "Branding Configuration:"
    echo "  Application: $APP_NAME"
    echo "  Company: $COMPANY_NAME"
    echo "  Primary Color: $PRIMARY_COLOR"
    echo "  Accent Color: $ACCENT_COLOR"

    echo ""
    echo "Deployed Assets:"
    if [ -n "$LOGO_PATH" ]; then
        echo -e "  ${GREEN}✓ Custom logo${NC}"
    else
        echo -e "  ${GREEN}✓ Generated logo${NC}"
    fi

    if [ -n "$FAVICON_PATH" ]; then
        echo -e "  ${GREEN}✓ Custom favicon${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Default favicon${NC}"
    fi

    if [ -n "$CSS_PATH" ]; then
        echo -e "  ${GREEN}✓ Custom CSS${NC}"
    else
        echo -e "  ${GREEN}✓ Generated CSS${NC}"
    fi

    if [ -n "$WELCOME_PATH" ]; then
        echo -e "  ${GREEN}✓ Custom welcome content${NC}"
    else
        echo -e "  ${GREEN}✓ Generated welcome content${NC}"
    fi

    if [ "$DRY_RUN" != true ]; then
        echo ""
        echo "Important Files:"
        echo "  📂 Backup Directory: $BACKUP_DIR"
        echo "  🔄 Rollback Script: rollback-branding-$TIMESTAMP.sh"
        echo "  📝 Branding Config: .env.branding.$TIMESTAMP"
        echo ""
        echo "Next Steps:"
        echo "  1. Add .env.branding.$TIMESTAMP to your .env file"
        echo "  2. Restart container: docker compose restart gideon-studio"
        echo "  3. Visit https://studio.euctools.ai to see branding"

        echo ""
        echo "If Issues Occur:"
        echo "  Run rollback script: ./rollback-branding-$TIMESTAMP.sh"
        echo ""
    fi

    echo "=========================================="

    if [ "$DRY_RUN" = true ]; then
        echo ""
        echo -e "${YELLOW}To apply changes: $0 --force (skips confirmations)${NC}"
        echo -e "${YELLOW}                $0 (interactive mode)${NC}"
    fi
}

# Main execution flow
main() {
    check_prerequisites
    confirm_operation
    gather_branding_info
    create_backups
    deploy_assets
    update_config
    create_rollback
    deploy_container
    show_summary

    echo ""
    echo -e "${GREEN}🎉 Branding deployment process complete!${NC}"
}

# Run main function
main "$@"
