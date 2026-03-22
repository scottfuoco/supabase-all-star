# claude-pack

> Agentic workflow superpowers for Claude Code. Install once, use on any project.

claude-pack turns Claude Code into a fully autonomous feature development system. You describe a feature, it researches the codebase, implements CLI-first, tests with Vitest and Playwright, validates the UI against your branding, and opens a PR — all in an isolated git worktree with its own Supabase database schema.

While one feature builds, you describe another. Fully parallel. Fully isolated.

---

## What's inside

```
claude-pack/
  install.sh                    ← Run this to install into any project
  
  .claude/
    CLAUDE.md                   ← Master workflow rules (installed at repo root)
    agents/
      orchestrator.md           ← Loop controller — coordinates all stages
      researcher.md             ← Reads codebase, writes implementation spec
      builder.md                ← Implements the feature (CLI-first)
      cli-validator.md          ← Validates via CLI before any UI work
      tester.md                 ← Vitest unit + integration tests
      playwright-validator.md   ← E2E + AI-powered visual QA
      pr-creator.md             ← Opens structured PR against staging
    commands/
      feature.md                ← /feature — kick off a new feature
      status.md                 ← /status — see what's running
      validate.md               ← /validate — run test suite manually
      seed.md                   ← /seed — reset the branch DB schema
      teardown.md               ← /teardown — clean up after merge
    skills/
      supabase-schema.md        ← How to manage per-branch schemas
      worktree.md               ← How to create/manage git worktrees
      playwright-visual-qa.md   ← How to run Playwright + visual analysis

  config/
    claude-pack.yaml            ← THE config file — edit this per project
    branding.md                 ← Your design system context for visual QA

  scripts/
    db-setup.sh                 ← Creates/resets/drops per-branch schemas
    worktree-setup.sh           ← Creates git worktrees with full environment

  supabase/
    seed.sql                    ← Project-specific seed data template

  .github/
    workflows/
      ci.yml                    ← GitHub Actions with per-branch schema support
```

---

## Requirements

- Claude Code Max ($200/mo recommended — parallel agents consume tokens fast)
- Supabase CLI + Docker (`brew install supabase/tap/supabase`)
- GitHub CLI (`brew install gh`) — for automated PR creation
- pnpm
- Node.js 20+
- Turborepo monorepo structure (adaptable to others)

---

## Installation

```bash
# Clone claude-pack somewhere on your machine (once)
git clone https://github.com/you/claude-pack ~/claude-pack

# Install into any project
cd ~/my-project
~/claude-pack/install.sh

# Update an existing installation
~/claude-pack/install.sh --update
```

---

## Configuration (the only file you edit per project)

Open `config/claude-pack.yaml` and fill in:

```yaml
project:
  name: "my-saas-app"

supabase:
  local_db_url: "postgresql://postgres:postgres@localhost:54322/postgres"
  local_anon_key: "your-key-from-supabase-start"
  local_service_key: "your-key-from-supabase-start"

git:
  base_branch: "origin/staging"

apps:
  web:
    path: "apps/web"
    port: 3000
  cli:
    path: "apps/cli"
```

Also fill in `config/branding.md` with your colors, typography, and design patterns.
And add your project-specific seed data to `supabase/seed.sql`.

---

## Workflow

### Start a feature

```
/feature add workspace invitations with email and link options
```

Claude will:
1. Create `feat/workspace-invitations` from `origin/staging`
2. Create git worktree at `../worktrees/workspace-invitations`
3. Create Postgres schema `feat_workspace_invitations`
4. Run migrations + seed from `supabase/seed.sql`
5. Write `.env.local` with correct connection string
6. Spawn agent team through the full workflow:

```
research → build → cli-validate → unit-test → playwright → lint-typecheck → PR
```

### While that's running, start another

```
/feature stripe webhook handling for subscription lifecycle
```

Completely separate worktree, separate schema, separate agent team. Parallel.

### Check status

```
/status
```

### Reset the database

```
/seed
```

### Run tests manually

```
/validate
/validate unit
/validate e2e
```

### Clean up after merge

```
/teardown feat/workspace-invitations
```

---

## The Workflow in Detail

### Stage 1: Research
The researcher agent reads your codebase, finds relevant patterns, and writes a complete implementation spec including exact CLI commands to validate against.

### Stage 2: Build
The builder implements CLI first — all functionality must work via CLI before any UI is touched. It creates migrations, generates TypeScript types, writes tests alongside code.

### Stage 3: CLI Validate
Every CLI command from the spec is run. Output is compared to expected. DB state is verified via direct Postgres queries. Failures loop back to the builder.

### Stage 4: Unit Test
Vitest runs the full suite. Integration tests hit the real isolated schema. Failures loop back to builder with full context.

### Stage 5: Playwright (UI features only)
E2E tests run against the feature's dev server. Screenshots are captured and analyzed against `config/branding.md` for color compliance, typography, spacing, component patterns. Hard failures loop back to builder.

### Stage 6: Lint + Types
`tsc --noEmit` and `eslint` must pass clean. Failures loop back to builder.

### Stage 7: PR
Opens a structured PR against `staging` with full test results, screenshots, DB changes documented, and reviewer instructions.

---

## Database Isolation

Each feature gets its own Postgres **schema** within the local Supabase instance:

```
Local Supabase (single Docker instance)
├── public schema          ← base/shared
├── feat_workspace_invitations    ← feature branch A
├── feat_stripe_webhooks          ← feature branch B  
└── feat_avatar_upload            ← feature branch C
```

Agents can break, reset, or nuke their schema freely. It never touches others.

The `.env.local` in each worktree sets `DATABASE_URL` with `search_path` pointing at the feature's schema, so all queries automatically land in the right place.

---

## Making It Your Own

### Different test commands
Edit `config/claude-pack.yaml`:
```yaml
testing:
  vitest:
    run_command: "pnpm test:ci"
  playwright:
    run_command: "pnpm e2e:headless"
```

### Different workflow stages
Edit `config/claude-pack.yaml`:
```yaml
workflow:
  stages:
    - research
    - build
    - unit-test      # Skip cli-validate for pure UI features
    - playwright
    - lint-typecheck
    - pr
```

### Custom agent behavior
Edit any file in `.claude/agents/` — they're just markdown prompts.

### Additional skills
Add `.md` files to `.claude/skills/` — Claude Code loads them automatically.

---

## Philosophy

This is not a framework in the traditional sense — it has no runtime, no package to install, no server to run. It's a structured set of markdown prompts, shell scripts, and configuration that teaches Claude Code how to be your autonomous development team.

The complexity lives in the prompts. The orchestration lives in Claude's Agent Teams. The isolation lives in Postgres schemas and git worktrees. The configuration lives in one YAML file.

You own every piece of it. Edit anything.
