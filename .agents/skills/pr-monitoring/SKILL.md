---
name: pr-monitoring
description:
  Use whenever a workflow starts, reuses, pauses, resumes, or stops automated
  monitoring of a PR/MR, or handles an automated pass from such a monitor.
  Covers T3 Code pull request watches and scheduled heartbeats.
---

# PR Monitoring

A monitor triggers automated passes for one PR. Its kind depends on the harness:

- **T3 Code:** a pull request watch. Link the PR to the current thread and call
  the `t3-code` MCP `watch_pull_request` tool. T3 checks the PR every minute and
  wakes the thread when a check fails, the required checks pass, someone else
  comments or reviews, or the branch starts to conflict with its target. Treat
  each wake as one automated pass of the active skill. Pause or stop the watch
  with `unwatch_pull_request`; resume it by watching again. A watch does not
  wake when the target branch advances without a conflict, so integrate target
  changes on the next wake or an explicit recheck. T3 ends the watch itself when
  the PR merges or closes, possibly without a wake, and when it cannot read the
  PR for 15 minutes. Handle a merged or closed PR on the next pass, even if the
  user has to request it; after any pass that continues monitoring, call
  `watch_pull_request` again to confirm or restore the watch. Do not add a
  scheduled heartbeat for a PR that is watched.
- **Other harnesses:** a heartbeat from the scheduling tool (the automation
  tool) attached to this task: the Codex app's automation tool or the cron
  scheduling tool in a standalone Claude Code session.

Before creating a monitor, inspect matching PR/pipeline monitors for the same
PR, including legacy monitors. Keep only one active monitor driving the PR; do
not silently change a monitor belonging to another task. Report that conflict
for a decision.

For this task, reuse the existing monitor. A `babysit-pr` request can upgrade
CI-only monitoring to ongoing PR monitoring; give a heartbeat a fresh run ID and
prompt. A pipeline handoff under an active PR monitor returns to that monitor
without creating or replacing it. A CI-only pass ignores wakes caused only by
comments or reviews.

Include the PR URL and a fresh run identifier in the heartbeat prompt:
`Automated heartbeat: run one pass of the <skill> skill for <PR URL>, run <ID>. Stay quiet unless there is a meaningful change, completion, failure, or required user action.`
Use `babysit-pipeline` or `babysit-pr` for `<skill>`. Derive branch, revision,
validation, and PR state live; do not persist mutable workflow state in prompts.
Verify each automated trigger matches an active run. Ignore queued triggers from
paused, deleted, or superseded runs; coalesce duplicates and serialize passes.

Ordinary messages do not stop monitoring. Honor explicit pause/stop requests via
the monitor's tool and verify the result before further background actions. If
that fails, stop background actions and report the failure. Resume only on an
explicit request, with a fresh run ID for a heartbeat. When a pass requires
human input, pause and report it; normal pending CI, human review, or merge is
not itself a blocker.

Schedule heartbeat passes only from 07:00 inclusive to 22:00 exclusive in the
user's local timezone. Encode this window in the automation tool when it
supports one; otherwise, such as with interval-only schedules, state it in the
heartbeat prompt. A trigger outside these hours does no PR work. Explicit manual
requests may run anytime. Create or update a heartbeat schedule as the pass's
final side effect, then yield. Notify only for meaningful changes, completion,
failures, or required user input; stay quiet when nothing changed.
