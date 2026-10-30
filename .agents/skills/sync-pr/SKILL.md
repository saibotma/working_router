---
name: sync-pr
description:
  Use to synchronize a PR/MR source branch with its target, validate and push
  the result, and refresh its title and description. Does not monitor CI or
  handle review comments.
---

# Sync PR

Run one target-branch synchronization using `git` and the forge CLI skill of the
PR's host, `gitlab-cli` or `github-cli`. An initial `prepare-pr` handoff may
supply source and target before a PR exists. Do not handle comments or merge the
PR yourself.

1. Inspect live PR state when present. Return immediately if closed or merged.
   Work on its actual source branch, distinct from the target; before PR
   creation use the dedicated source branch supplied by `prepare-pr`. Preserve
   unrelated uncommitted work and never switch or overwrite it unsafely.
2. Fetch the remote source if present and integrate remote source changes before
   target changes. Fetch the target at the start and before every push.
   Integrate it whenever the source is behind. Before the source exists
   remotely, rebase is allowed; afterward merge the target and never rebase or
   force-push.
3. Do not review a clean integration or invalidate unchanged review coverage
   just because its base moved. If integration conflicts, run `review` only over
   the manual resolutions and additional integration edits before completing the
   merge/rebase. Supply conflicted paths, resolved hunks, both sides, and
   existing validation; exclude unchanged content from both branches. Fix all
   relevant findings. Validate the integrated result even when integration was
   clean.
4. Push all committed source history, including others' commits. Recheck target
   freshness before pushing and repeat integration/validation if needed. Reuse
   applicable validation when nothing changed. If synchronization changes active
   skill instructions, reread them before continuing.
5. For an existing PR, refresh its title and description using `pr-description`,
   even when no integration was needed but metadata is stale. Preserve live
   draft status and enabled squash/source-deletion options, as the forge CLI
   skill's `Merge Options` describes; only change merge strategy or mark a draft
   ready on explicit user direction. Return the source revision, validation, PR
   status, and whether a new pipeline needs checking to the caller. Do not wait
   for CI or claim pipeline readiness.
