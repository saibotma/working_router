# Publishing Changes

Use these rules when preparing a PR or publishing fixes from pipeline or PR
monitoring. Use `git` and the forge CLI skill of the PR's host, `gitlab-cli` or
`github-cli`.

- Work on the PR's actual source branch, distinct from its target. Preserve
  unrelated uncommitted work. Never force-push or merge the PR yourself.
- Split commits into coherent packets that can be reviewed and reverted
  independently. Group code, tests, generated files, and documentation for one
  behavior; split unrelated feedback. Explain materially necessary coupling.
- Validate every change. Before each content commit, require `review` coverage
  of the exact candidate diff. Reuse unchanged coverage; do not repeat review
  merely because a pass restarted, validation reran, files were restaged, or the
  base moved through a clean target synchronization.
- After committing, invoke `sync-pr` to integrate the latest target and push all
  committed history, including others' commits. Refresh metadata using
  `pr-description`, including the declared deviations and decisions, review
  advisories, and validation evidence from `review`. Continue the calling
  operation after local review or synchronization; those handoffs do not finish
  pipeline or PR monitoring.
- Keep squash and source-branch deletion enabled unless the user requests
  another merge strategy, as the forge CLI skill's `Merge Options` describes.
  Never disable either after a user or reviewer enabled it. Preserve live draft
  status; mark ready only on an explicit request for that PR and verify the
  transition.
