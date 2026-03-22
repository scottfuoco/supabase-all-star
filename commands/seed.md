# /seed — Reset and reseed the current branch's database schema

Wipes and recreates the feature schema for the current worktree. Useful when:
- The database got into a bad state during development
- You updated `supabase/seed.sql` and want to re-apply
- You want a clean slate for testing

## Usage

```
/seed                    # Reset current branch's schema
/seed [branch-name]      # Reset a specific branch's schema
```

## What Claude will do

1. Detect current branch: `git branch --show-current`
2. Run: `./scripts/db-setup.sh reset [branch]`
3. Confirm schema is healthy and `.env.local` is correct
4. Optionally regenerate TypeScript types if `auto_gen_types: true` in config

This is safe — it only affects the current feature's isolated schema.
