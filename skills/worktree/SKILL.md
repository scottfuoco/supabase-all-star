---
name: worktree
description: "Create and manage git worktrees for parallel feature development with isolated environments"
---

# Skill: Git Worktree Management

This skill teaches Claude how to create and manage git worktrees for
parallel feature development, each with its own isolated environment.

## What is a worktree?

A git worktree is a separate checkout of the same repository in a different
directory. Multiple worktrees share the same `.git` folder but have independent
working directories, branches, and `.env.local` files.

This means you can have 5 features being built simultaneously in:
```
../worktrees/workspace-invitations/   ← feat/workspace-invitations
../worktrees/stripe-webhooks/         ← feat/stripe-webhooks
../worktrees/avatar-upload/           ← feat/avatar-upload
```

Each with its own DB schema, its own `node_modules`, its own `.env.local`.

## Creating a Worktree (Full Setup)

Always use the script — it handles git, DB, and env in one step:

```bash
./scripts/worktree-setup.sh create "workspace invitations"
```

This will:
1. Create branch `feat/workspace-invitations` from `origin/staging`
2. Create worktree at `../worktrees/workspace-invitations`
3. Run `pnpm install`
4. Create DB schema `feat_workspace_invitations`
5. Run migrations + seed
6. Write `.env.local`
7. Create `.claude/task/` directory with initial files

## Manual Worktree Commands

If you need to do steps individually:

```bash
# Create branch from staging
git fetch origin staging
git branch feat/my-feature origin/staging

# Add worktree
git worktree add ../worktrees/my-feature feat/my-feature

# List all worktrees
git worktree list

# Remove a worktree
git worktree remove ../worktrees/my-feature --force
git worktree prune
```

## Working in a Worktree

Each worktree is a full repo checkout. When an agent is working on a feature,
it should `cd` into the worktree directory first:

```bash
cd ../worktrees/workspace-invitations
source .env.local
pnpm dev
```

## Worktree Structure

After `worktree-setup.sh create`, a worktree contains:

```
../worktrees/workspace-invitations/
  .env.local                    ← auto-generated, correct DB schema
  .claude/
    task/
      status.md                 ← current workflow stage
      spec.md                   ← researcher writes this
      research.md               ← researcher writes this
      cli-results.md            ← cli-validator writes this
      test-results.md           ← tester writes this
      visual-qa.md              ← playwright-validator writes this
      failures.md               ← populated on failures
      screenshots/              ← playwright screenshots
  apps/
  packages/
  supabase/
  ... (rest of repo)
```

## Teardown After PR Merge

```bash
./scripts/worktree-setup.sh teardown feat/workspace-invitations
```

Or clean up all merged branches at once:
```bash
# List branches merged into staging
git branch --merged origin/staging | grep "feat/" | while read branch; do
  ./scripts/worktree-setup.sh teardown "$branch"
done
```

## Listing Active Worktrees

```bash
./scripts/worktree-setup.sh list
```

Shows git worktrees + their associated DB schemas.

## Troubleshooting

### "fatal: '[path]' already exists"
The worktree directory exists but isn't registered. Remove it:
```bash
rm -rf ../worktrees/my-feature
git worktree prune
./scripts/worktree-setup.sh create "my feature"
```

### "branch already exists"
```bash
# Reuse the existing branch
git worktree add ../worktrees/my-feature feat/my-feature
```

### Worktree has wrong base branch
```bash
# Check what the branch is based on
git log --oneline feat/my-feature ^origin/staging | head -5
# If wrong, reset
git -C ../worktrees/my-feature reset --hard origin/staging
```
