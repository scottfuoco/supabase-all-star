# /status — Check the status of active feature agents

Show what's happening across all active feature worktrees.

## Usage

```
/status              # Show all active features
/status [slug]       # Show detail for one feature
```

## What Claude will do

For each active worktree, read `.claude/task/status.md` and report:
- Current stage (research / build / cli-validate / unit-test / playwright / lint-typecheck / pr)
- Last activity timestamp
- Any failures logged in `.claude/task/failures.md`
- PR link if opened

Run: `./scripts/worktree-setup.sh list` to enumerate active worktrees, then read each status file.
