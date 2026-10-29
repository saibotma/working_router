---
name: babysit-pipeline
description:
  Use when asked to monitor or fix CI for a PR/MR, or when prepare-pr hands off
  CI completion. Uses a monitor while pending and stops when green or blocked.
---

# Babysit Pipeline

Follow CI for the PR's current source revision, including replacement pipelines
created by fixes. Use the forge CLI skill of the PR's host, `gitlab-cli` or
`github-cli`, and read CI as the forge CLI skill's `CI` describes. Do not handle
review comments or wait for a human merge.

Follow `pr-monitoring` when creating or changing monitors or handling automated
passes. When invoked by `babysit-pr`, run one pipeline pass and return its
result; the parent keeps the sole monitor. Otherwise maintain one CI-only
monitor while pending; a heartbeat runs about every five minutes.

## Pass

1. Read live PR state, source revision, and applicable pipeline/jobs. For a
   closed or merged PR, end CI monitoring without local branch cleanup. Reuse
   valid review/validation evidence; do not rerun completed work on unchanged
   checks.
2. If pending, return pending to `babysit-pr`, or ensure the CI monitor exists
   and yield. Follow the current source revision after any new push; never
   accept an old revision's successful pipeline as readiness.
3. For failure, apply the relevance rules below. For an attributable failure,
   read [Publishing changes](../prepare-pr/references/publishing-changes.md),
   implement a coherent fix, validate and run `review`, commit, then `sync-pr`.
   Refresh metadata and immediately check the replacement pipeline once before
   scheduling another pass. A local fix does not end monitoring.
4. On green, fetch the target and invoke `sync-pr` if the source is behind. If
   it pushes a new revision, follow its pipeline. Otherwise verify current
   pipeline success, local review coverage, draft state, approval, and merge
   options. Obtain missing `review` coverage before declaring readiness. Assign
   the authenticated user as reviewer, as the forge CLI skill's `Reviewers`
   describes, only when synchronized, green, and reviewed. Preserve draft state
   and enabled merge options; report an intentional draft as such. Delete the
   CI-only monitor and report readiness. When called by `babysit-pr`, return
   green without deleting the parent's monitor.
5. If progress requires user input, pause the CI monitor and report the blocker,
   or return blocked to the parent so it pauses its monitor. Missing, canceled,
   skipped, or manually blocked required pipelines/jobs are not green: inspect
   the cause and ask when progress needs a decision rather than polling forever.

## Pipeline Failure Relevance

Before changing repository content in response to a failed pipeline, establish
whether the failure is caused by the PR's net diff or its integration with the
target branch. Inspect the failing job and relevant diff, then use comparable
target-branch pipelines as a control: inspect the latest applicable target job
and search recent target pipeline logs or history for the same failure signature
when the latest result is not conclusive. A green target pipeline alone does not
prove causation; account for flaky tests and environment differences.

Fix a failure only when evidence connects it to the PR, or when fixing that
failure is already part of the PR's stated scope. If the same failure is
confirmed on the target branch without the PR, treat it as pre-existing or
unrelated: do not fix it or expand the PR, and report the confirming evidence to
the owner. Ask the owner how to proceed when an unrelated failure blocks the PR.
If relevance remains uncertain after reasonable investigation, do not guess or
edit; summarize the evidence and ask the owner. Ask the owner about
infrastructure failures such as unavailable runners, outages, permissions, disk,
or cache failures instead of making speculative repository changes.
