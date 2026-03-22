---
name: supabase-schema
description: "Create, manage, and interact with per-branch Postgres schemas within the local Supabase instance"
---

# Skill: Supabase Schema Management

This skill teaches Claude how to create, manage, and interact with
per-branch Postgres schemas within the local Supabase instance.

## When to use this skill

- Creating a new feature worktree
- Resetting a branch's database
- Running migrations against a feature schema
- Verifying data after CLI or integration tests
- Generating TypeScript types after schema changes

## Core Commands

### Create a schema for a branch
```bash
./scripts/db-setup.sh create feat/my-feature
```
Creates the schema, runs all migrations, seeds from `supabase/seed.sql`,
and writes `.env.local` to the worktree.

### Reset a schema (drop + recreate)
```bash
./scripts/db-setup.sh reset feat/my-feature
```
Use this after adding new migrations or when the DB is in a bad state.

### Drop a schema (cleanup)
```bash
./scripts/db-setup.sh drop feat/my-feature
```
Use this during teardown after a PR is merged.

### List all feature schemas
```bash
./scripts/db-setup.sh list
```

### Check connection info
```bash
./scripts/db-setup.sh status feat/my-feature
```

## Connecting to a Feature Schema

The `.env.local` in each worktree contains:
```
DATABASE_URL=postgresql://postgres:postgres@localhost:54322/postgres?options=-csearch_path%3Dfeat_my_feature
DB_SCHEMA=feat_my_feature
```

The `search_path` in the connection string means all queries automatically
hit the feature's schema without needing to prefix table names.

## Running Raw SQL Against a Schema

```bash
# Load the env first
source .env.local

# Then query — search_path is set automatically via DATABASE_URL
psql $DATABASE_URL -c "SELECT * FROM users LIMIT 5;"

# Or set search_path explicitly
psql postgresql://postgres:postgres@localhost:54322/postgres \
  -c "SET search_path TO feat_my_feature; SELECT * FROM users;"
```

## Adding a Migration

1. Create the migration file:
```bash
# Naming: YYYYMMDDHHMMSS_description.sql
touch supabase/migrations/$(date +%Y%m%d%H%M%S)_add_invitations.sql
```

2. Write the migration — always include RLS:
```sql
-- supabase/migrations/YYYYMMDDHHMMSS_add_invitations.sql

CREATE TABLE IF NOT EXISTS invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  invited_by UUID NOT NULL REFERENCES profiles(id),
  token TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(32), 'hex'),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired')),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org members can view invitations"
  ON invitations FOR SELECT
  USING (org_id IN (
    SELECT org_id FROM organization_members WHERE user_id = auth.uid()
  ));

CREATE POLICY "org admins can create invitations"
  ON invitations FOR INSERT
  WITH CHECK (org_id IN (
    SELECT org_id FROM organization_members
    WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
  ));
```

3. Apply to the feature schema:
```bash
./scripts/db-setup.sh reset feat/my-feature
```

4. Regenerate TypeScript types:
```bash
supabase gen types typescript --local --schema feat_my_feature \
  > packages/types/src/database.types.ts
```

## Verifying Data After Tests

```bash
source .env.local

# Check rows were inserted
psql $DATABASE_URL -c "SELECT COUNT(*) FROM invitations;"

# Check specific state
psql $DATABASE_URL -c "
  SELECT id, email, status, expires_at
  FROM invitations
  WHERE status = 'pending'
  ORDER BY created_at DESC
  LIMIT 10;
"
```

## Troubleshooting

### "Cannot connect to local Supabase"
```bash
supabase start  # Start the local stack
supabase status # Verify it's running and get credentials
```

### "Schema does not exist"
```bash
./scripts/db-setup.sh create feat/my-feature
```

### "Migration failed"
Check the migration SQL for syntax errors. Common issues:
- Referencing a table that doesn't exist yet (check migration order)
- RLS policy referencing `auth.uid()` — ensure auth schema is available
- Duplicate object names across migrations

### "Types are out of sync"
```bash
supabase gen types typescript --local > packages/types/src/database.types.ts
```
