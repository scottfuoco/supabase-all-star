# /feature — Start a new feature with full agentic workflow

Kick off a complete feature development cycle in an isolated worktree.

## What this does

1. Validates that Supabase is reachable (runs `./scripts/db-setup.sh check` first)
2. Creates a git worktree from `origin/staging`
3. Creates an isolated Postgres schema and seeds it (if `auto_create_schema: true` in config)
4. Writes `.env.local` with the correct connection string, API URL, and keys
5. Spawns an Agent Team with the full workflow:
   - **Researcher** — reads codebase, writes spec
   - **Builder** — implements (CLI first, then UI)
   - **CLI Validator** — validates via CLI before any UI work
   - **Tester** — vitest unit + integration
   - **Playwright Validator** — screenshots + visual QA (if UI touched)
   - **PR Creator** — opens PR against staging

## Usage

```
/feature <description>
```

## Examples

```
/feature add workspace invitations with email + link options
/feature stripe webhook handling for subscription lifecycle
/feature user avatar upload with image cropping
```

## Steps Claude will follow

1. Parse the description into a branch slug: `feat/[slug]`
2. Validate Supabase is accessible: `./scripts/db-setup.sh check`
   - If this fails, tell the user to run `supabase start` and then `/init` to diagnose
3. Run: `./scripts/worktree-setup.sh create "[description]"`
   - This creates the git worktree, branch, installs deps
   - This calls `db-setup.sh create` which creates the per-branch schema,
     runs migrations, seeds data, and writes `.env.local`
4. Verify the `.env.local` was written in the worktree:
   - Confirm `DATABASE_URL` points to the feature schema
   - Confirm `NEXT_PUBLIC_SUPABASE_URL` and keys are set
5. Read `config/claude-pack.yaml` to understand the full project config
6. Read `config/branding.md` for visual QA context
7. Create an Agent Team:

```
You are the Orchestrator for a feature development workflow.

Feature: $ARGUMENTS
Branch: feat/[slug]
Worktree: ../worktrees/[slug]
Config: config/claude-pack.yaml

Spawn the following agent team and coordinate them through the workflow stages
defined in CLAUDE.md. Each agent reads and writes to .claude/task/ files in the worktree.

Workflow stages (in order):
1. research -> researcher agent
2. build -> builder agent
3. cli-validate -> cli-validator agent
4. unit-test -> tester agent
5. playwright -> playwright-validator agent (only if UI files modified)
6. lint-typecheck -> builder agent (runs pnpm tsc && pnpm lint)
7. pr -> pr-creator agent

On failure at any stage: return to builder with .claude/task/failures.md populated.
Max retries: [from config].

The per-branch Supabase schema is already created and .env.local is configured.
The builder can immediately use the isolated schema without any additional setup.

Start by spawning the researcher agent in the worktree directory.
```

8. Monitor progress — you can check status any time with `/status [slug]`
9. Notify when PR is ready for review

## Error handling

- If `db-setup.sh check` fails: stop and tell the user to run `supabase start` first
- If `auto_create_schema` is `false` in config: skip schema creation, warn the user they need to create it manually
- If the worktree already exists: reuse it (worktree-setup.sh handles this)
- If the schema already exists: reuse it (CREATE SCHEMA IF NOT EXISTS)

## While this runs

You can start another feature immediately:
```
/feature another feature description
```

Each feature is completely isolated — separate worktree, separate DB schema, separate agent team.
