---
name: babysit-pr
description:
  Use for ongoing PR/MR monitoring of comments, target changes, CI, and merge
  cleanup.
---

# Babysit PR

Monitor one PR through review and merge. Use the forge skill of the PR's host,
`gitlab` or `github`. Merge the PR only as `babysit-pipeline` describes for a 🟢
Green PR; a human merges every other PR. Follow `pr-monitoring` when creating or
changing monitors or handling automated passes.

## Pass

1. Inspect live PR status. If closed without merge, delete the monitor and stop.
   If merged, delete it, perform the cleanup below, and report once.
2. Invoke [address-pr-comments](../address-pr-comments/SKILL.md) for one
   feedback pass. Preserve its pending decisions and material review advisories.
3. Invoke `sync-pr` if the feedback pass did not already synchronize the source,
   then invoke `babysit-pipeline` for one pass under this monitor. If it returns
   merged, continue as step 1 describes for a merged PR.
4. Pause and report when a decision is needed. Otherwise continue monitoring
   until the PR merges or closes. Green CI ends pipeline work, not this PR
   monitoring.

## Cleanup After Merge

Verify there are no unpushed commits or uncommitted changes before cleanup;
preserve any such work and report what remains. Leave the source branch, update
the target branch, and try `git branch -d`. Use `git branch -D` only when squash
merge alone prevents safe deletion. If the target is checked out in another
worktree, detach at the fetched target commit instead. Report cleanup failures
without keeping the recurring monitor active.
