# /validate — Run the full validation suite on the current branch

Manually trigger the full test pipeline without waiting for the orchestrator.
Useful for checking your own work or re-running after a fix.

## Usage

```
/validate              # Full suite
/validate unit         # Unit tests only (vitest)
/validate e2e          # Playwright only
/validate types        # tsc + lint only
/validate cli          # CLI validation only
```

## What Claude will do

1. Read `config/claude-pack.yaml` for test commands
2. Ensure `.env.local` exists and DB schema is healthy
3. Run the requested suite(s) in order:

### Full suite order:
1. `pnpm tsc --noEmit` — TypeScript check
2. `pnpm lint` — ESLint
3. `pnpm test:run` — Vitest unit + integration
4. CLI validation (run CLI commands, check output)
5. `pnpm test:e2e` — Playwright (if UI files exist)
6. Screenshot analysis against `config/branding.md`

### Output
Results written to `.claude/task/test-results.md` and printed to terminal.
Visual QA screenshots saved to `.claude/task/screenshots/`.
