#!/usr/bin/env bash
# =============================================================================
# install.sh
# Installs claude-pack into a target project.
#
# Usage:
#   ./install.sh                          # Install into current directory
#   ./install.sh /path/to/my-project     # Install into specific project
#   ./install.sh --update                # Update existing installation
#   ./install.sh --skip-config           # Skip Supabase auto-configuration
# =============================================================================

set -euo pipefail

PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET=""
UPDATE_MODE=false
SKIP_CONFIG=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --update)
      UPDATE_MODE=true
      ;;
    --skip-config)
      SKIP_CONFIG=true
      ;;
    *)
      TARGET="$arg"
      ;;
  esac
done

TARGET="${TARGET:-$(pwd)}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${BLUE}[install]${NC} $1"; }
ok()   { echo -e "${GREEN}[install]${NC} ✓ $1"; }
warn() { echo -e "${YELLOW}[install]${NC} ⚠ $1"; }
err()  { echo -e "${RED}[install]${NC} ✗ $1" >&2; exit 1; }
step() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# Validate target is a git repo
if [[ ! -d "$TARGET/.git" ]]; then
  err "$TARGET is not a git repository"
fi

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         Claude Pack Installer                ║${NC}"
echo -e "${CYAN}║   Agentic workflow superpowers for Claude    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""
log "Target project: $TARGET"
echo ""

# ─────────────────────────────────────────────────────────────
step "1. Installing .claude/ directory"
# ─────────────────────────────────────────────────────────────

CLAUDE_TARGET="$TARGET/.claude"

if [[ -d "$CLAUDE_TARGET" && "$UPDATE_MODE" == "false" ]]; then
  warn ".claude/ already exists in target project"
  echo ""
  read -p "  Merge with existing? (y/N): " -r
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "  Skipping .claude/ installation"
  else
    UPDATE_MODE=true
  fi
fi

mkdir -p "$CLAUDE_TARGET"/{commands,skills,agents,hooks}

# Copy agent files
for f in "$PACK_DIR/.claude/agents/"*.md; do
  dest="$CLAUDE_TARGET/agents/$(basename "$f")"
  if [[ ! -f "$dest" || "$UPDATE_MODE" == "true" ]]; then
    cp "$f" "$dest"
    ok "agents/$(basename "$f")"
  else
    warn "agents/$(basename "$f") already exists — skipping (use --update to overwrite)"
  fi
done

# Copy skill files
for f in "$PACK_DIR/.claude/skills/"*.md; do
  dest="$CLAUDE_TARGET/skills/$(basename "$f")"
  if [[ ! -f "$dest" || "$UPDATE_MODE" == "true" ]]; then
    cp "$f" "$dest"
    ok "skills/$(basename "$f")"
  else
    warn "skills/$(basename "$f") already exists — skipping"
  fi
done

# Copy command files
for f in "$PACK_DIR/.claude/commands/"*.md; do
  dest="$CLAUDE_TARGET/commands/$(basename "$f")"
  if [[ ! -f "$dest" || "$UPDATE_MODE" == "true" ]]; then
    cp "$f" "$dest"
    ok "commands/$(basename "$f")"
  else
    warn "commands/$(basename "$f") already exists — skipping"
  fi
done

# ─────────────────────────────────────────────────────────────
step "2. Installing CLAUDE.md"
# ─────────────────────────────────────────────────────────────

CLAUDE_MD="$TARGET/CLAUDE.md"

if [[ -f "$CLAUDE_MD" && "$UPDATE_MODE" == "false" ]]; then
  warn "CLAUDE.md already exists"
  echo ""
  read -p "  Replace it? (y/N): " -r
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    warn "Skipping CLAUDE.md — you'll need to manually merge .claude/CLAUDE.md into yours"
    cp "$PACK_DIR/.claude/CLAUDE.md" "$CLAUDE_TARGET/CLAUDE.template.md"
    ok "Saved template to .claude/CLAUDE.template.md for manual merge"
  else
    # Back up existing
    cp "$CLAUDE_MD" "$CLAUDE_MD.backup"
    ok "Backed up existing CLAUDE.md to CLAUDE.md.backup"
    cp "$PACK_DIR/.claude/CLAUDE.md" "$CLAUDE_MD"
    ok "CLAUDE.md installed"
  fi
else
  cp "$PACK_DIR/.claude/CLAUDE.md" "$CLAUDE_MD"
  ok "CLAUDE.md installed"
fi

# ─────────────────────────────────────────────────────────────
step "3. Installing config files"
# ─────────────────────────────────────────────────────────────

mkdir -p "$TARGET/config"

# claude-pack.yaml — always prompt, never overwrite silently
CONFIG_TARGET="$TARGET/config/claude-pack.yaml"
if [[ -f "$CONFIG_TARGET" ]]; then
  warn "config/claude-pack.yaml already exists — skipping (edit it manually)"
else
  cp "$PACK_DIR/config/claude-pack.yaml" "$CONFIG_TARGET"
  ok "config/claude-pack.yaml installed"
fi

# branding.md — always prompt
BRANDING_TARGET="$TARGET/config/branding.md"
if [[ -f "$BRANDING_TARGET" ]]; then
  warn "config/branding.md already exists — skipping"
else
  cp "$PACK_DIR/config/branding.md" "$BRANDING_TARGET"
  ok "config/branding.md installed (fill this in with your brand guidelines)"
fi

# ─────────────────────────────────────────────────────────────
step "4. Installing scripts"
# ─────────────────────────────────────────────────────────────

mkdir -p "$TARGET/scripts"

for f in "$PACK_DIR/scripts/"*.sh; do
  dest="$TARGET/scripts/$(basename "$f")"
  if [[ ! -f "$dest" || "$UPDATE_MODE" == "true" ]]; then
    cp "$f" "$dest"
    chmod +x "$dest"
    ok "scripts/$(basename "$f")"
  else
    warn "scripts/$(basename "$f") already exists — skipping"
  fi
done

# ─────────────────────────────────────────────────────────────
step "5. Installing seed template"
# ─────────────────────────────────────────────────────────────

mkdir -p "$TARGET/supabase"

SEED_TARGET="$TARGET/supabase/seed.sql"
if [[ -f "$SEED_TARGET" ]]; then
  warn "supabase/seed.sql already exists — skipping (your existing seed is preserved)"
else
  cp "$PACK_DIR/supabase/seed.sql" "$SEED_TARGET"
  ok "supabase/seed.sql installed (add your project-specific seed data)"
fi

# ─────────────────────────────────────────────────────────────
step "6. Installing GitHub Actions"
# ─────────────────────────────────────────────────────────────

mkdir -p "$TARGET/.github/workflows"

CI_TARGET="$TARGET/.github/workflows/ci.yml"
if [[ -f "$CI_TARGET" ]]; then
  warn ".github/workflows/ci.yml already exists"
  echo ""
  read -p "  Replace it? (y/N): " -r
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    cp "$CI_TARGET" "$CI_TARGET.backup"
    cp "$PACK_DIR/.github/workflows/ci.yml" "$CI_TARGET"
    ok "ci.yml installed (backup at ci.yml.backup)"
  else
    cp "$PACK_DIR/.github/workflows/ci.yml" "$TARGET/.github/workflows/ci.claude-pack.yml"
    ok "Saved as ci.claude-pack.yml for manual merge"
  fi
else
  cp "$PACK_DIR/.github/workflows/ci.yml" "$CI_TARGET"
  ok ".github/workflows/ci.yml installed"
fi

# ─────────────────────────────────────────────────────────────
step "7. Updating .gitignore"
# ─────────────────────────────────────────────────────────────

GITIGNORE="$TARGET/.gitignore"
ENTRIES=(
  ".env.local"
  ".claude/task/"
  "worktrees/"
  "../worktrees/"
)

for entry in "${ENTRIES[@]}"; do
  if ! grep -qF "$entry" "$GITIGNORE" 2>/dev/null; then
    echo "$entry" >> "$GITIGNORE"
    ok "Added '$entry' to .gitignore"
  fi
done

# ─────────────────────────────────────────────────────────────
step "8. Configuring Supabase"
# ─────────────────────────────────────────────────────────────

CONFIG_TARGET="$TARGET/config/claude-pack.yaml"
SUPABASE_CONFIGURED=false

if [[ "$SKIP_CONFIG" == "true" ]]; then
  warn "Skipping Supabase configuration (--skip-config)"
  echo "     Run the /init command later to configure and validate."
elif command -v supabase &>/dev/null; then
  log "Supabase CLI found. Checking if local instance is running..."

  # Try to get supabase status output
  SUPABASE_STATUS=$(cd "$TARGET" && supabase status 2>/dev/null || true)

  if echo "$SUPABASE_STATUS" | grep -q "API URL"; then
    ok "Local Supabase instance is running"

    # Extract values from supabase status output
    SB_API_URL=$(echo "$SUPABASE_STATUS" | grep "API URL:" | sed 's/.*API URL: *//' | xargs)
    SB_DB_URL=$(echo "$SUPABASE_STATUS" | grep "DB URL:" | sed 's/.*DB URL: *//' | xargs)
    SB_STUDIO_URL=$(echo "$SUPABASE_STATUS" | grep "Studio URL:" | sed 's/.*Studio URL: *//' | xargs)
    SB_ANON_KEY=$(echo "$SUPABASE_STATUS" | grep "anon key:" | sed 's/.*anon key: *//' | xargs)
    SB_SERVICE_KEY=$(echo "$SUPABASE_STATUS" | grep "service_role key:" | sed 's/.*service_role key: *//' | xargs)

    echo ""
    echo "  Detected Supabase values:"
    [[ -n "$SB_API_URL" ]]     && echo "    API URL:          $SB_API_URL"
    [[ -n "$SB_DB_URL" ]]      && echo "    DB URL:           $SB_DB_URL"
    [[ -n "$SB_STUDIO_URL" ]]  && echo "    Studio URL:       $SB_STUDIO_URL"
    [[ -n "$SB_ANON_KEY" ]]    && echo "    anon key:         ${SB_ANON_KEY:0:30}..."
    [[ -n "$SB_SERVICE_KEY" ]] && echo "    service_role key: ${SB_SERVICE_KEY:0:30}..."
    echo ""

    read -p "  Auto-populate config/claude-pack.yaml with these values? (Y/n): " -r
    if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
      # Update config values using sed
      if [[ -n "$SB_DB_URL" ]]; then
        sed -i.bak "s|^\(\s*db_url:\).*|  db_url: \"$SB_DB_URL\"|" "$CONFIG_TARGET"
      fi
      if [[ -n "$SB_API_URL" ]]; then
        sed -i.bak "s|^\(\s*api_url:\).*|  api_url: \"$SB_API_URL\"|" "$CONFIG_TARGET"
        # Extract port from API URL
        SB_API_PORT=$(echo "$SB_API_URL" | sed 's|.*:\([0-9]*\)$|\1|')
        if [[ -n "$SB_API_PORT" ]]; then
          sed -i.bak "s|^\(\s*api_port:\).*|  api_port: $SB_API_PORT|" "$CONFIG_TARGET"
        fi
      fi
      if [[ -n "$SB_STUDIO_URL" ]]; then
        sed -i.bak "s|^\(\s*studio_url:\).*|  studio_url: \"$SB_STUDIO_URL\"|" "$CONFIG_TARGET"
      fi
      if [[ -n "$SB_ANON_KEY" ]]; then
        sed -i.bak "s|^\(\s*anon_key:\).*|  anon_key: \"$SB_ANON_KEY\"|" "$CONFIG_TARGET"
      fi
      if [[ -n "$SB_SERVICE_KEY" ]]; then
        sed -i.bak "s|^\(\s*service_role_key:\).*|  service_role_key: \"$SB_SERVICE_KEY\"|" "$CONFIG_TARGET"
      fi

      # Clean up sed backup files
      rm -f "$CONFIG_TARGET.bak"

      ok "config/claude-pack.yaml updated with Supabase values"
      SUPABASE_CONFIGURED=true
    else
      warn "Skipped — update config/claude-pack.yaml manually"
    fi
  else
    warn "Supabase is not running locally"
    echo "     Run 'supabase start' and then use the /init command to auto-configure."
  fi
else
  warn "Supabase CLI not found"
  echo "     Install it: https://supabase.com/docs/guides/cli"
  echo "     Then run 'supabase start' and use the /init command to configure."
fi

# ─────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Installation Complete!             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$SUPABASE_CONFIGURED" == "true" ]]; then
  echo "  Supabase is configured and ready!"
  echo ""
  echo "  Next steps:"
  echo ""
  echo -e "  ${CYAN}1.${NC} Edit ${YELLOW}config/claude-pack.yaml${NC}"
  echo "     → Set your project name and app paths"
  echo ""
  echo -e "  ${CYAN}2.${NC} Fill in ${YELLOW}config/branding.md${NC}"
  echo "     → Add your colors, typography, component patterns"
  echo ""
  echo -e "  ${CYAN}3.${NC} Edit ${YELLOW}supabase/seed.sql${NC}"
  echo "     → Add realistic seed data for agent development"
  echo ""
  echo -e "  ${CYAN}4.${NC} Validate your setup:"
  echo "     ${YELLOW}/init${NC}"
  echo ""
  echo -e "  ${CYAN}5.${NC} Start your first feature:"
  echo "     ${YELLOW}/feature add workspace invitations${NC}"
else
  echo "  Next steps:"
  echo ""
  echo -e "  ${CYAN}1.${NC} Start Supabase locally:"
  echo "     ${YELLOW}supabase start${NC}"
  echo ""
  echo -e "  ${CYAN}2.${NC} Validate and auto-configure:"
  echo "     ${YELLOW}/init${NC}"
  echo "     This will test the connection and populate config values."
  echo ""
  echo -e "  ${CYAN}3.${NC} Edit ${YELLOW}config/claude-pack.yaml${NC}"
  echo "     → Set your project name, app paths"
  echo ""
  echo -e "  ${CYAN}4.${NC} Fill in ${YELLOW}config/branding.md${NC}"
  echo "     → Add your colors, typography, component patterns"
  echo ""
  echo -e "  ${CYAN}5.${NC} Edit ${YELLOW}supabase/seed.sql${NC}"
  echo "     → Add realistic seed data for agent development"
  echo ""
  echo -e "  ${CYAN}6.${NC} Start your first feature:"
  echo "     ${YELLOW}/feature add workspace invitations${NC}"
fi

echo ""
echo "  While a feature runs, start another:"
echo "     ${YELLOW}/feature stripe webhook handling${NC}"
echo ""
