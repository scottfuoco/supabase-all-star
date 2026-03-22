# Claude Pack — Agentic Workflow System

This file is the master context for all agents and sessions in this project.
It is automatically loaded by Claude Code and all spawned sub-agents.

---

## Project Identity

<!-- CONFIGURE: These values are set in config/claude-pack.yaml. Replace the placeholders below
     with your project's actual name and description, or keep them as references to the config file. -->
```yaml
project_name: "{{PROJECT_NAME}}"       # ← Set in config/claude-pack.yaml → project.name
description: "{{PROJECT_DESCRIPTION}}" # ← Set in config/claude-pack.yaml → project.description
monorepo: turborepo
primary_language: TypeScript
```

---

## Tech Stack

- **Monorepo**: Turborepo
- **Frontend**: Next.js (apps/web)
- **Shared packages**: packages/types, packages/utils (and others defined in config)
- **Database**: Supabase (local CLI via Docker, schema-per-worktree isolation)
- **Testing**: Vitest (unit + integration), Playwright (E2E + visual QA)
- **CI**: GitHub Actions
- **Package manager**: pnpm

---

## The Agentic Workflow

Every feature goes through this exact sequence. No stage may be skipped.
The orchestrator enforces this loop and retries failed stages up to `max_retries` times.

```
1. RESEARCH      → Understand the codebase, write spec
2. BUILD         → Implement (CLI-first, then web)
3. CLI-VALIDATE  → Validate all functionality via CLI before touching UI
4. UNIT-TEST     → vitest unit + integration tests
5. PLAYWRIGHT    → Visual + functional E2E (only if UI was modified)
6. LINT-TYPECHECK → tsc + eslint (must pass clean)
7. PR            → Open PR against staging with full context
```

On any stage failure → return to BUILD with full failure context attached.
Max retries per feature: defined in `config/claude-pack.yaml`.

### CLI-First Rule
All functionality MUST work via CLI before any UI work begins.
The CLI validator runs the feature through the CLI, captures output, and confirms correctness.
Only after CLI-VALIDATE passes does the builder proceed to UI implementation.

---

## Database Rules

Every feature runs in its own isolated Postgres schema within the local Supabase instance.

- Schema name = sanitized git branch name (e.g. `feat_workspace_invitations`)
- Schema is created automatically when the worktree is created
- Schema is seeded from `supabase/seed.sql` (project-specific)
- Agents may freely mutate, reset, or destroy the schema — it is isolated
- Connection string is written to `.env.local` in the worktree automatically
- To reset: run `/seed` slash command or `scripts/db-setup.sh reset`

**Never touch the `public` schema or the `main` local Supabase instance directly.**

---

## Git Rules

- All feature branches cut from `origin/staging`
- Branch naming: `feat/[slug]` (e.g. `feat/workspace-invitations`)
- Each branch has a corresponding git worktree at `../worktrees/[slug]`
- PRs target `staging` branch
- Agents may push branches and open PRs automatically
- Commit messages follow Conventional Commits: `feat:`, `fix:`, `test:`, `chore:`

---

## Testing Standards

### Vitest
- Unit tests live alongside source: `*.test.ts`
- Integration tests: `*.integration.test.ts`
- All tests must pass before Playwright runs
- Coverage threshold defined in `vitest.config.ts`

### Playwright
- Config at `playwright.config.ts`
- Tests in `e2e/` directory
- Visual QA: screenshots captured → analyzed by Claude vision against `config/branding.md`
- Playwright runs against the feature's local dev server on its assigned port
- All visual QA failures are reported with screenshot paths + specific issues

---

## Code Style & Best Practices

- Strict TypeScript — no `any`, no suppressed errors
- All Supabase queries go through typed client from `packages/types`
- Run `supabase gen types typescript --local` after every migration
- RLS policies required on all new tables
- No secrets in code — use `.env.local` (gitignored)
- Prefer server components in Next.js unless client interactivity is needed

---

## Agent Communication Protocol

Agents communicate via files in the worktree's `.claude/task/` directory:

```
.claude/task/
  spec.md          ← researcher writes this
  research.md      ← researcher writes this
  cli-results.md   ← cli-validator writes this
  test-results.md  ← tester writes this
  visual-qa.md     ← playwright-validator writes this
  failures.md      ← any agent writes failures here for builder to read
  status.md        ← orchestrator maintains current stage
```

Always read `status.md` first to understand current stage.
Always write results to the appropriate file before signaling completion.

---

## What Agents Should NOT Do

- Never commit directly to `staging` or `main`
- Never modify another worktree's files
- Never drop the `public` schema
- Never skip the CLI-VALIDATE stage
- Never open a PR if tests are failing
- Never modify `config/claude-pack.yaml` or `supabase/seed.sql` without explicit user instruction
