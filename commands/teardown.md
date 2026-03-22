# /teardown — Remove a feature worktree and its database schema

Clean up after a feature is merged (or abandoned).

## Usage

```
/teardown                    # Teardown current branch
/teardown [branch-name]      # Teardown a specific branch
/teardown --all-merged       # Teardown all branches already merged to staging
```

## What Claude will do

1. Confirm the branch to teardown (asks if ambiguous)
2. Check that a PR is either merged or intentionally abandoned
3. Run: `./scripts/worktree-setup.sh teardown [branch]`
   - Drops the Postgres schema
   - Removes the git worktree
   - Runs `git worktree prune`
4. Optionally delete the local branch: `git branch -d feat/[slug]`

## Safety

Will warn (but not block) if:
- The PR is still open and unmerged
- There are uncommitted changes in the worktree
