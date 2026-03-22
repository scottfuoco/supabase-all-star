# /init — Validate Supabase setup and diagnose configuration

Run diagnostics on your local Supabase instance and claude-pack configuration.
Use this command after installation or whenever something seems misconfigured.

## What this does

1. Checks that `config/claude-pack.yaml` exists and is readable
2. Validates all Supabase config values (db_url, api_url, keys, ports)
3. Tests the database connection
4. Checks if the Supabase API is reachable
5. Lists any existing per-branch schemas
6. Reports clear next steps for any issues found

## Usage

```
/init
```

## Steps Claude will follow

1. **Check config file exists**
   ```bash
   test -f config/claude-pack.yaml && echo "Config found" || echo "MISSING: config/claude-pack.yaml"
   ```

2. **Run the db-setup check command** which validates the full Supabase setup:
   ```bash
   ./scripts/db-setup.sh check
   ```
   This will:
   - Test the database connection (psql to db_url)
   - Check if the API URL is reachable
   - Verify anon_key and service_role_key are configured
   - List existing feature schemas

3. **Check if `supabase` CLI is available**
   ```bash
   command -v supabase && supabase --version
   ```

4. **If supabase CLI is available, check status**
   ```bash
   supabase status
   ```
   Compare the output values against what is in `config/claude-pack.yaml`.
   If they differ, tell the user which config values to update.

5. **Check that required directories exist**
   - `supabase/migrations/` — migration files
   - `supabase/seed.sql` — seed data
   - `.claude/` — agent commands and skills

6. **Report results** with a clear summary:

   If everything is good:
   ```
   All checks passed. Your Supabase setup is ready.
   You can now run: /feature <description>
   ```

   If there are issues, list them with specific fix instructions:
   ```
   Issues found:
   - Database connection failed: Run `supabase start`
   - anon_key not configured: Copy from `supabase status` output into config/claude-pack.yaml
   - service_role_key not configured: Copy from `supabase status` output into config/claude-pack.yaml
   ```

## When to use this

- After running `install.sh` for the first time
- After running `supabase start` to populate config values
- When a `/feature` command fails with database errors
- When switching between Supabase instances (local vs remote)
- After updating `config/claude-pack.yaml` to verify changes

## Auto-fix capability

If `supabase status` is available and the config has placeholder/empty values,
offer to auto-populate the config:

```
The following values can be auto-populated from `supabase status`:
  - db_url
  - api_url
  - anon_key
  - service_role_key

Would you like me to update config/claude-pack.yaml with these values?
```

If the user agrees, read the values from `supabase status` output and update
the YAML config file directly.
