---
name: prepare-pr
description:
  Use when asked to implement a change through PR/MR readiness or publish
  existing changes as a PR/MR.
---

# Prepare PR

Prepare a PR and follow its CI to completion through `babysit-pipeline`. Agents
never merge PRs; a human merges every PR.

1. Use `git` and the forge CLI skill of the PR's host, `gitlab-cli` or
   `github-cli`. Inspect the request, working tree, branch, and any existing PR;
   establish the target branch.
2. Before implementation or commits, check out a dedicated source branch for the
   requested change, distinct from the target. Reuse an open PR's actual source
   branch. Otherwise create or reuse a meaningful feature/fix branch; do not
   publish from main, the target, detached HEAD, or a temporary branch serving
   as a main/target checkout. Determine purpose from the task and branch
   history, not its name alone. Preserve requested existing changes and
   unrelated work; ask when the intended target or safe transfer of changes is
   ambiguous.
3. If the change implements an issue, first make sure the issue reflects the
   agreed plan, following `issues`. Plan the change as one or more PRs following
   [Sizing changes](references/sizing-changes.md). Implement the requested
   change and validate it, including tests for reasonably testable behavior.
   Record deviations from the issue and implementation-time decisions as
   `review` describes. Run `review` for the candidate; reuse current validation
   and review coverage when available.
4. Read [Publishing changes](references/publishing-changes.md). Commit coherent
   reviewed packets, then invoke `sync-pr` to integrate the target and push.
   Create or adopt the PR using `pr-description`; enable squash and
   source-branch deletion as the forge CLI skill's `Merge Options` describes,
   and preserve an existing PR's draft status.
5. Invoke `babysit-pipeline` with the PR URL and review/validation evidence. It
   reports readiness when the current revision is green, or keeps a CI-only
   monitor while pending. Return the PR URL and actual status; pending is not
   ready.
