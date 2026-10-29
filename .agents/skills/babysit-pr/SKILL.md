---
name: babysit-pr
description:
  Use for ongoing PR/MR monitoring of comments, target changes, CI, and merge
  cleanup.
---

# Babysit PR

Monitor one PR through human review and merge. Use the forge CLI skill of the
PR's host, `gitlab-cli` or `github-cli`. Never merge the PR yourself. Follow
`pr-monitoring` when creating or changing monitors or handling automated passes.

## Pass

1. Inspect live PR status. If closed without merge, delete the monitor and stop.
   If merged, delete it, perform the cleanup below, and report once.
2. Invoke [address-pr-comments](../address-pr-comments/SKILL.md) for one
   feedback pass. Preserve its pending decisions and material review advisories.
3. Invoke `sync-pr` if the feedback pass did not already synchronize the source,
   then invoke `babysit-pipeline` for one pass under this monitor.
4. Pause and report when a decision is needed. Otherwise continue monitoring. A
   T3 watch needs no intervals; pace a heartbeat at about five minutes for
   pending CI; start around fifteen minutes awaiting review and back off on
   unchanged checks to at most one hour; hourly after approval until merge.
   Reset backoff on state changes or explicit rechecks. Green CI ends pipeline
   work, not this PR monitoring.

## Cleanup After Merge

Verify there are no unpushed commits or uncommitted changes before cleanup;
preserve any such work and report what remains. Leave the source branch, update
the target branch, and try `git branch -d`. Use `git branch -D` only when squash
merge alone prevents safe deletion. If the target is checked out in another
worktree, detach at the fetched target commit instead. Report cleanup failures
without keeping the recurring monitor active.
