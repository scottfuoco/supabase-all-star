#!/usr/bin/env bash
# =============================================================================
# scripts/db-setup.sh
# =============================================================================
# Creates and manages per-branch Postgres schemas within the local Supabase instance.
# Called automatically by the orchestrator when creating a new feature worktree.
#
# Usage:
#   ./scripts/db-setup.sh create <branch-name>   # Create + migrate + seed
#   ./scripts/db-setup.sh reset <branch-name>    # Drop + recreate + seed
#   ./scripts/db-setup.sh drop <branch-name>     # Drop schema (cleanup)
#   ./scripts/db-setup.sh status <branch-name>   # Print connection info
#   ./scripts/db-setup.sh list                   # List all feature schemas
#   ./scripts/db-setup.sh check                  # Validate Supabase connection
#
# Options:
#   --config <path>   Path to claude-pack.yaml (default: config/claude-pack.yaml)
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[db-setup]${NC} $1"; }
ok()  { echo -e "${GREEN}[db-setup]${NC} $1"; }
err() { echo -e "${RED}[db-setup]${NC} $1" >&2; exit 1; }
warn(){ echo -e "${YELLOW}[db-setup]${NC} $1"; }

# =============================================================================
# Parse arguments — extract --config before positional args
# =============================================================================
CUSTOM_CONFIG=""
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CUSTOM_CONFIG="$2"
      shift 2
      ;;
    --config=*)
      CUSTOM_CONFIG="${1#*=}"
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

CMD="${POSITIONAL_ARGS[0]:-help}"
BRANCH="${POSITIONAL_ARGS[1]:-}"

# =============================================================================
# Locate config
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -n "$CUSTOM_CONFIG" ]]; then
  if [[ ! -f "$CUSTOM_CONFIG" ]]; then
    err "Config file not found: $CUSTOM_CONFIG"
  fi
  CONFIG="$CUSTOM_CONFIG"
else
  CONFIG="$REPO_ROOT/config/claude-pack.yaml"
fi

if [[ ! -f "$CONFIG" ]]; then
  err "Config file not found at $CONFIG. Run install.sh first or specify --config <path>."
fi

# =============================================================================
# Parse config values with defaults
# =============================================================================
# Simple yaml value extractor — works without external deps (yq, python, etc.)
yaml_get() {
  local key="$1"
  local default="${2:-}"
  local val
  # Match key: value — strip only the 'key:' prefix, preserving colons in the value (e.g. URLs)
  val=$(grep -m1 "[[:space:]]*${key}:" "$CONFIG" 2>/dev/null | sed "s/^[[:space:]]*${key}:[[:space:]]*//" | sed 's/[[:space:]]*#.*//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/" | xargs) || true
  if [[ -z "$val" || "$val" == '""' || "$val" == "''" ]]; then
    echo "$default"
  else
    echo "$val"
  fi
}

DB_URL=$(yaml_get "db_url" "postgresql://postgres:postgres@127.0.0.1:54322/postgres")
# Support legacy config key name (local_db_url) for backward compatibility
if [[ "$DB_URL" == "postgresql://postgres:postgres@127.0.0.1:54322/postgres" ]]; then
  LEGACY_URL=$(yaml_get "local_db_url" "")
  if [[ -n "$LEGACY_URL" ]]; then
    DB_URL="$LEGACY_URL"
  fi
fi

API_URL=$(yaml_get "api_url" "http://127.0.0.1:54321")
# Legacy fallback
if [[ "$API_URL" == "http://127.0.0.1:54321" ]]; then
  LEGACY_API=$(yaml_get "local_api_url" "")
  if [[ -n "$LEGACY_API" ]]; then
    API_URL="$LEGACY_API"
  fi
fi

ANON_KEY=$(yaml_get "anon_key" "")
# Legacy fallback
if [[ -z "$ANON_KEY" ]]; then
  ANON_KEY=$(yaml_get "local_anon_key" "")
fi

SERVICE_KEY=$(yaml_get "service_role_key" "")
# Legacy fallback
if [[ -z "$SERVICE_KEY" ]]; then
  SERVICE_KEY=$(yaml_get "local_service_key" "")
fi

SCHEMA_PREFIX=$(yaml_get "schema_prefix" "feat")
AUTO_CREATE=$(yaml_get "auto_create_schema" "true")
SEED_FILE_REL=$(yaml_get "seed_file" "supabase/seed.sql")
SEED_FILE="$REPO_ROOT/$SEED_FILE_REL"
MIGRATIONS_DIR_REL=$(yaml_get "migrations_dir" "supabase/migrations")
MIGRATIONS_DIR="$REPO_ROOT/$MIGRATIONS_DIR_REL"
AUTO_GEN_TYPES=$(yaml_get "auto_gen_types" "true")
TYPES_OUTPUT_REL=$(yaml_get "types_output" "packages/types/src/database.types.ts")
TYPES_OUTPUT="$REPO_ROOT/$TYPES_OUTPUT_REL"
WORKTREE_BASE=$(yaml_get "worktree_base_dir" "../worktrees")

# Validate SCHEMA_PREFIX to prevent SQL injection
if [[ ! "$SCHEMA_PREFIX" =~ ^[a-z0-9_]+$ ]]; then
  err "SCHEMA_PREFIX must contain only lowercase letters, numbers, and underscores"
fi

# =============================================================================
# Helper functions
# =============================================================================

# Convert branch name to valid schema name
# feat/workspace-invitations -> feat_workspace_invitations
branch_to_schema() {
  local branch="$1"
  # Remove feat/ prefix if present, replace slashes and hyphens with underscores
  echo "${SCHEMA_PREFIX}_$(echo "$branch" | sed 's|feat/||' | tr '/-' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g')"
}

# Check local Supabase is running by attempting a connection
check_supabase() {
  log "Checking Supabase connection..."

  # Check if psql is available
  if ! command -v psql &>/dev/null; then
    err "psql is not installed. Install it with: brew install libpq"
  fi

  # Try connecting
  if ! psql "$DB_URL" -c "SELECT 1" &>/dev/null 2>&1; then
    echo ""
    echo -e "${RED}Cannot connect to Supabase database.${NC}"
    echo ""
    echo "  DB URL: $DB_URL"
    echo ""
    echo "  Possible fixes:"
    echo "    1. Start Supabase:     supabase start"
    echo "    2. Check status:       supabase status"
    echo "    3. Verify db_url in:   $CONFIG"
    echo ""
    echo "  If using a custom port, update supabase.db_url in config/claude-pack.yaml"
    echo ""
    exit 1
  fi

  ok "Connected to Supabase at $DB_URL"
}

# Validate the full Supabase setup (connection + keys + API)
check_full() {
  check_supabase

  # Check API URL is reachable
  if command -v curl &>/dev/null; then
    if curl -sf "${API_URL}/rest/v1/" -o /dev/null 2>/dev/null; then
      ok "Supabase API reachable at $API_URL"
    else
      warn "Supabase API not reachable at $API_URL (REST endpoint may require auth header)"
    fi
  fi

  # Check keys are configured
  if [[ -z "$ANON_KEY" || "$ANON_KEY" == "your-local-anon-key-here" ]]; then
    warn "anon_key is not configured in $CONFIG"
    echo "     Run 'supabase status' to get the key, then update config/claude-pack.yaml"
  else
    ok "anon_key is configured (${ANON_KEY:0:20}...)"
  fi

  if [[ -z "$SERVICE_KEY" || "$SERVICE_KEY" == "your-local-service-key-here" ]]; then
    warn "service_role_key is not configured in $CONFIG"
    echo "     Run 'supabase status' to get the key, then update config/claude-pack.yaml"
  else
    ok "service_role_key is configured (${SERVICE_KEY:0:20}...)"
  fi

  # Check schema prefix
  ok "Schema prefix: $SCHEMA_PREFIX"
  ok "Auto-create schemas: $AUTO_CREATE"

  # List existing feature schemas
  echo ""
  log "Existing feature schemas:"
  psql "$DB_URL" -t -c "
    SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name LIKE '${SCHEMA_PREFIX}_%'
    ORDER BY schema_name;
  " 2>/dev/null || warn "Could not list schemas"
}

# =============================================================================
# Schema operations
# =============================================================================

# Create schema and apply migrations + seed
create_schema() {
  local branch="$1"
  local schema
  schema=$(branch_to_schema "$branch")

  log "Creating schema '$schema' for branch '$branch'..."
  check_supabase

  # Create schema
  psql "$DB_URL" -c "CREATE SCHEMA IF NOT EXISTS \"$schema\";" || err "Failed to create schema"
  ok "Schema '$schema' created"

  # Grant permissions (Supabase roles)
  psql "$DB_URL" <<SQL
    GRANT USAGE ON SCHEMA "$schema" TO anon, authenticated, service_role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA "$schema" GRANT ALL ON TABLES TO authenticated, service_role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA "$schema" GRANT SELECT ON TABLES TO anon;
    ALTER DEFAULT PRIVILEGES IN SCHEMA "$schema" GRANT ALL ON SEQUENCES TO authenticated, service_role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA "$schema" GRANT SELECT, USAGE ON SEQUENCES TO anon;
    ALTER DEFAULT PRIVILEGES IN SCHEMA "$schema" GRANT EXECUTE ON FUNCTIONS TO authenticated, service_role;
SQL
  ok "Permissions granted"

  # Run migrations against this schema
  run_migrations "$schema"

  # Seed
  seed_schema "$schema"

  # Write .env.local for the worktree
  write_env "$branch" "$schema"

  # Generate TypeScript types
  if [[ "$AUTO_GEN_TYPES" == "true" ]]; then
    gen_types "$schema" || true
  fi

  ok "Schema '$schema' ready"
  print_status "$branch" "$schema"
}

# Run all migrations against the schema
run_migrations() {
  local schema="$1"

  if [[ ! -d "$MIGRATIONS_DIR" ]]; then
    warn "No migrations directory found at $MIGRATIONS_DIR — skipping migrations"
    return
  fi

  local migration_files
  migration_files=$(ls "$MIGRATIONS_DIR"/*.sql 2>/dev/null | sort || true)

  if [[ -z "$migration_files" ]]; then
    warn "No migration files found — skipping"
    return
  fi

  log "Running migrations against schema '$schema'..."
  local count=0
  for f in $migration_files; do
    log "  -> $(basename "$f")"
    PGOPTIONS="--search_path=$schema,public" psql "$DB_URL" -f "$f" || err "Migration failed: $f"
    count=$((count + 1))
  done
  ok "$count migration(s) applied"
}

# Seed the schema
seed_schema() {
  local schema="$1"

  if [[ ! -f "$SEED_FILE" ]]; then
    warn "No seed file found at $SEED_FILE — skipping seed"
    return
  fi

  log "Seeding schema '$schema'..."
  PGOPTIONS="--search_path=$schema,public" psql "$DB_URL" -f "$SEED_FILE" || err "Seeding failed"
  ok "Schema seeded from $(basename "$SEED_FILE")"
}

# Write .env.local into the worktree
write_env() {
  local branch="$1"
  local schema="$2"
  local slug
  slug=$(echo "$branch" | sed 's|feat/||' | tr '/' '-')

  # Find the worktree directory
  local worktree_dir="$REPO_ROOT/$WORKTREE_BASE/$slug"

  # Fall back to repo root if worktree does not exist (single-branch mode)
  if [[ ! -d "$worktree_dir" ]]; then
    if [[ -d "$REPO_ROOT" ]]; then
      worktree_dir="$REPO_ROOT"
      warn "Worktree not found at $REPO_ROOT/$WORKTREE_BASE/$slug — writing .env.local to repo root"
    else
      warn "Cannot determine worktree location — skipping .env.local write"
      return
    fi
  fi

  cat > "$worktree_dir/.env.local" <<'ENV'
# Auto-generated by claude-pack db-setup.sh
# Do not commit this file.
ENV
  {
    printf '# Branch: %s\n' "$branch"
    printf '# Schema: %s\n\n' "$schema"
    printf 'NEXT_PUBLIC_SUPABASE_URL=%s\n' "$API_URL"
    printf 'NEXT_PUBLIC_SUPABASE_ANON_KEY=%s\n' "$ANON_KEY"
    printf 'SUPABASE_SERVICE_ROLE_KEY=%s\n\n' "$SERVICE_KEY"
    printf '# Schema isolation — this branch'\''s isolated Postgres schema\n'
    printf 'DB_SCHEMA=%s\n' "$schema"
    printf 'DATABASE_URL=%s?options=-csearch_path%%3D%s\n\n' "$DB_URL" "$schema"
    printf '# Feature branch context\n'
    printf 'FEATURE_BRANCH=%s\n' "$branch"
    printf 'FEATURE_SCHEMA=%s\n' "$schema"
  } >> "$worktree_dir/.env.local"

  ok ".env.local written to $worktree_dir"
}

# Generate TypeScript types from the schema
gen_types() {
  local schema="$1"
  log "Generating TypeScript types..."

  if ! command -v supabase &>/dev/null; then
    warn "supabase CLI not found — skipping type generation"
    return
  fi

  supabase gen types typescript --local --schema "$schema" > "$TYPES_OUTPUT" 2>/dev/null || {
    warn "Type generation failed — continuing anyway"
    return
  }
  ok "Types written to $TYPES_OUTPUT"
}

# Print connection info
print_status() {
  local branch="${1:-}"
  local schema="${2:-}"

  if [[ -z "$schema" && -n "$branch" ]]; then
    schema=$(branch_to_schema "$branch")
  fi

  echo ""
  echo -e "${GREEN}================================================${NC}"
  echo -e "${GREEN}  Schema ready: $schema${NC}"
  echo -e "${GREEN}================================================${NC}"
  echo "  DB URL:      $DB_URL"
  echo "  API URL:     $API_URL"
  echo "  Schema:      $schema"
  echo "  Connection:  ${DB_URL}?options=-csearch_path%3D${schema}"
  echo ""
}

# Drop schema
drop_schema() {
  local branch="$1"
  local schema
  schema=$(branch_to_schema "$branch")

  warn "Dropping schema '$schema'..."
  check_supabase
  psql "$DB_URL" -c "DROP SCHEMA IF EXISTS \"$schema\" CASCADE;" || err "Failed to drop schema"
  ok "Schema '$schema' dropped"
}

# List all feature schemas
list_schemas() {
  check_supabase
  log "Feature schemas in local Supabase (prefix: ${SCHEMA_PREFIX}_):"
  psql "$DB_URL" -t -c "
    SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name LIKE '${SCHEMA_PREFIX}_%'
    ORDER BY schema_name;
  "
}

# Clean up schemas whose git branches no longer exist
cleanup_schemas() {
  check_supabase

  local schemas
  schemas=$(psql "$DB_URL" -t -A -c "
    SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name LIKE '${SCHEMA_PREFIX}_%'
    ORDER BY schema_name;
  " 2>/dev/null) || err "Failed to list schemas"

  if [[ -z "$schemas" ]]; then
    ok "No feature schemas found — nothing to clean up"
    return
  fi

  # Get list of current git branches
  local branches
  branches=$(git branch -a --format='%(refname:short)' 2>/dev/null || true)

  local stale=()
  local active=()

  while IFS= read -r schema_name; do
    [[ -z "$schema_name" ]] && continue
    # Convert schema name back to possible branch patterns
    local suffix="${schema_name#${SCHEMA_PREFIX}_}"
    local found=false

    # Check if any branch matches this schema
    while IFS= read -r branch; do
      [[ -z "$branch" ]] && continue
      local branch_schema
      branch_schema=$(branch_to_schema "$branch")
      if [[ "$branch_schema" == "$schema_name" ]]; then
        found=true
        break
      fi
    done <<< "$branches"

    if [[ "$found" == "true" ]]; then
      active+=("$schema_name")
    else
      stale+=("$schema_name")
    fi
  done <<< "$schemas"

  echo ""
  if [[ ${#active[@]} -gt 0 ]]; then
    log "Active schemas (branch exists):"
    for s in "${active[@]}"; do
      echo "  ${GREEN}✓${NC} $s"
    done
  fi

  if [[ ${#stale[@]} -eq 0 ]]; then
    echo ""
    ok "No stale schemas found — all schemas have matching branches"
    return
  fi

  echo ""
  warn "Stale schemas (no matching branch found):"
  for s in "${stale[@]}"; do
    echo "  ${RED}✗${NC} $s"
  done

  echo ""
  echo -n "Drop all ${#stale[@]} stale schema(s)? [y/N] "
  read -r confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    for s in "${stale[@]}"; do
      psql "$DB_URL" -c "DROP SCHEMA IF EXISTS \"$s\" CASCADE;" &>/dev/null
      ok "Dropped $s"
    done
    ok "Cleanup complete — ${#stale[@]} schema(s) removed"
  else
    log "Skipped — no schemas dropped"
  fi
}

# Drop all feature schemas
drop_all_schemas() {
  check_supabase

  local schemas
  schemas=$(psql "$DB_URL" -t -A -c "
    SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name LIKE '${SCHEMA_PREFIX}_%'
    ORDER BY schema_name;
  " 2>/dev/null) || err "Failed to list schemas"

  if [[ -z "$schemas" ]]; then
    ok "No feature schemas found — nothing to drop"
    return
  fi

  local count=0
  echo ""
  warn "The following schemas will be dropped:"
  while IFS= read -r schema_name; do
    [[ -z "$schema_name" ]] && continue
    echo "  ${RED}✗${NC} $schema_name"
    count=$((count + 1))
  done <<< "$schemas"

  echo ""
  echo -n "Drop all $count schema(s)? [y/N] "
  read -r confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    while IFS= read -r schema_name; do
      [[ -z "$schema_name" ]] && continue
      psql "$DB_URL" -c "DROP SCHEMA IF EXISTS \"$schema_name\" CASCADE;" &>/dev/null
      ok "Dropped $schema_name"
    done <<< "$schemas"
    ok "All $count feature schema(s) dropped"
  else
    log "Skipped — no schemas dropped"
  fi
}

# =============================================================================
# Main
# =============================================================================

case "$CMD" in
  create)
    [[ -z "$BRANCH" ]] && err "Usage: $0 create <branch-name>"
    create_schema "$BRANCH"
    ;;
  reset)
    [[ -z "$BRANCH" ]] && err "Usage: $0 reset <branch-name>"
    drop_schema "$BRANCH"
    create_schema "$BRANCH"
    ;;
  drop)
    [[ -z "$BRANCH" ]] && err "Usage: $0 drop <branch-name>"
    drop_schema "$BRANCH"
    ;;
  drop-all)
    drop_all_schemas
    ;;
  status)
    [[ -z "$BRANCH" ]] && err "Usage: $0 status <branch-name>"
    check_supabase
    print_status "$BRANCH"
    ;;
  list)
    list_schemas
    ;;
  cleanup)
    cleanup_schemas
    ;;
  check)
    check_full
    ;;
  *)
    echo "Usage: $0 [--config <path>] {create|reset|drop|drop-all|status|list|cleanup|check} [branch-name]"
    echo ""
    echo "  create <branch>  Create schema, run migrations, seed"
    echo "  reset <branch>   Drop and recreate schema"
    echo "  drop <branch>    Drop schema (cleanup after PR merge)"
    echo "  drop-all         Drop ALL feature schemas (with confirmation)"
    echo "  status <branch>  Print connection info"
    echo "  list             List all feature schemas"
    echo "  cleanup          Find and drop schemas whose branches no longer exist"
    echo "  check            Validate Supabase connection and config"
    echo ""
    echo "Options:"
    echo "  --config <path>  Path to claude-pack.yaml (default: config/claude-pack.yaml)"
    exit 1
    ;;
esac
