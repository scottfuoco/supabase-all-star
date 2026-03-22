#!/usr/bin/env bash
# =============================================================================
# scripts/worktree-setup.sh
# =============================================================================
# Creates a git worktree for a feature branch, sets up the DB schema,
# and prepares the environment for an agent to start working.
#
# Usage:
#   ./scripts/worktree-setup.sh create "workspace invitations"
#   ./scripts/worktree-setup.sh create "feat/workspace-invitations"  (explicit)
#   ./scripts/worktree-setup.sh teardown feat/workspace-invitations
#   ./scripts/worktree-setup.sh list
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO_ROOT/config/claude-pack.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[worktree]${NC} $1"; }
ok()  { echo -e "${GREEN}[worktree]${NC} ✓ $1"; }
err() { echo -e "${RED}[worktree]${NC} ✗ $1" >&2; exit 1; }
warn() { echo -e "${YELLOW}[worktree]${NC} ⚠ $1"; }

# Simple yaml value extractor with defaults
yaml_get() {
  local key="$1"
  local default="${2:-}"
  local val
  val=$(grep -m1 "^\s*${key}:" "$CONFIG" 2>/dev/null | sed 's/.*:\s*//' | tr -d '"' | tr -d "'" | sed 's/\s*#.*//' | xargs) || true
  if [[ -z "$val" || "$val" == '""' || "$val" == "''" ]]; then
    echo "$default"
  else
    echo "$val"
  fi
}

# Parse config
BASE_BRANCH=$(yaml_get "base_branch" "origin/staging")
WORKTREE_BASE=$(yaml_get "worktree_base_dir" "../worktrees")
WORKTREE_ROOT="$REPO_ROOT/$WORKTREE_BASE"
AUTO_CREATE_SCHEMA=$(yaml_get "auto_create_schema" "true")

# Convert a feature description to a branch slug
# "workspace invitations" → "workspace-invitations"
# "feat/workspace-invitations" → "workspace-invitations"
to_slug() {
  echo "$1" | sed 's|feat/||' | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

create_worktree() {
  local description="$1"
  local slug
  slug=$(to_slug "$description")
  local branch="feat/$slug"
  local worktree_dir="$WORKTREE_ROOT/$slug"

  log "Setting up worktree for: $description"
  log "Branch: $branch"
  log "Directory: $worktree_dir"
  echo ""

  # Ensure we're on the right base
  git fetch origin staging 2>/dev/null || warn "Could not fetch origin/staging — using local"

  # Create the branch from base
  if git show-ref --quiet "refs/heads/$branch"; then
    log "Branch '$branch' already exists — reusing"
  else
    log "Creating branch '$branch' from $BASE_BRANCH..."
    git branch "$branch" "$BASE_BRANCH" || err "Failed to create branch"
    ok "Branch created"
  fi

  # Create worktree
  mkdir -p "$WORKTREE_ROOT"
  if [[ -d "$worktree_dir" ]]; then
    warn "Worktree already exists at $worktree_dir — skipping git worktree add"
  else
    log "Creating worktree at $worktree_dir..."
    git worktree add "$worktree_dir" "$branch" || err "Failed to create worktree"
    ok "Worktree created"
  fi

  # Copy pnpm-lock and node_modules symlink for faster installs
  if [[ -f "$REPO_ROOT/pnpm-lock.yaml" ]]; then
    cp "$REPO_ROOT/pnpm-lock.yaml" "$worktree_dir/" 2>/dev/null || true
  fi

  # Install dependencies in worktree
  log "Installing dependencies..."
  (cd "$worktree_dir" && pnpm install --frozen-lockfile 2>/dev/null) || {
    warn "pnpm install failed — agent will need to handle this"
  }

  # Create task directory for agent communication
  mkdir -p "$worktree_dir/.claude/task/screenshots"

  # Compute schema name for status file
  local schema_name
  local schema_prefix
  schema_prefix=$(yaml_get "schema_prefix" "feat")
  schema_name="${schema_prefix}_$(echo "$slug" | tr '-' '_')"

  # Write initial status file
  cat > "$worktree_dir/.claude/task/status.md" <<STATUS
# Task Status

**Branch**: $branch
**Schema**: $schema_name
**Stage**: research
**Created**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Description**: $description

## Stage History
- $(date -u +"%H:%M:%S") — worktree created, ready for research
STATUS

  # Write initial spec file (agent will fill this in)
  cat > "$worktree_dir/.claude/task/spec.md" <<SPEC
# Feature Spec

**Branch**: $branch
**Description**: $description

<!-- Researcher agent fills this in -->
SPEC

  # Set up database schema (if auto_create_schema is enabled)
  if [[ "$AUTO_CREATE_SCHEMA" == "true" ]]; then
    log "Setting up database schema (auto_create_schema=true)..."
    "$SCRIPT_DIR/db-setup.sh" create "$branch" || {
      warn "Schema creation failed — the worktree is ready but has no isolated DB schema"
      warn "You can create it manually later with: ./scripts/db-setup.sh create $branch"
    }
  else
    warn "Skipping schema creation (auto_create_schema=false in config)"
    warn "Create it manually with: ./scripts/db-setup.sh create $branch"
  fi

  # Final summary
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  Worktree ready!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  Branch:    $branch"
  echo "  Worktree:  $worktree_dir"
  echo "  To work:   cd $worktree_dir"
  echo ""
  echo "  Agent communication files:"
  echo "    $worktree_dir/.claude/task/status.md"
  echo "    $worktree_dir/.claude/task/spec.md"
  echo ""
}

teardown_worktree() {
  local branch="$1"
  local slug
  slug=$(to_slug "$branch")
  local worktree_dir="$WORKTREE_ROOT/$slug"

  log "Tearing down worktree for branch: $branch"

  # Drop DB schema
  "$SCRIPT_DIR/db-setup.sh" drop "$branch" || warn "Failed to drop schema — continuing"

  # Remove worktree
  if [[ -d "$worktree_dir" ]]; then
    git worktree remove "$worktree_dir" --force || warn "Failed to remove worktree directory"
    ok "Worktree removed"
  else
    warn "Worktree directory not found: $worktree_dir"
  fi

  # Prune worktree list
  git worktree prune

  ok "Teardown complete for $branch"
}

list_worktrees() {
  log "Active worktrees:"
  git worktree list
  echo ""
  log "Feature schemas:"
  "$SCRIPT_DIR/db-setup.sh" list
}

# =============================================================================
# Main
# =============================================================================

CMD="${1:-help}"
ARG="${2:-}"

case "$CMD" in
  create)
    [[ -z "$ARG" ]] && err "Usage: $0 create \"feature description\""
    create_worktree "$ARG"
    ;;
  teardown)
    [[ -z "$ARG" ]] && err "Usage: $0 teardown <branch-name>"
    teardown_worktree "$ARG"
    ;;
  list)
    list_worktrees
    ;;
  *)
    echo "Usage: $0 {create|teardown|list} [args]"
    echo ""
    echo "  create \"description\"    Create worktree + DB schema + .env.local"
    echo "  teardown <branch>       Remove worktree + drop DB schema"
    echo "  list                    Show active worktrees and schemas"
    exit 1
    ;;
esac
