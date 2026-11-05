---
name: pr-monitoring
description:
  Use whenever a workflow starts, reuses, pauses, resumes, or stops automated
  monitoring of a PR/MR, or handles an automated pass from such a monitor.
  Covers T3 Code pull request watches.
---

# PR Monitoring

A monitor triggers automated passes for one PR. It is a T3 Code pull request
watch: link the PR to the current thread and call the `t3-code` MCP
`watch_pull_request` tool. T3 checks the PR every minute and wakes the thread
when a check fails, the required checks pass, someone else comments or reviews,
or the branch starts to conflict with its target. Treat each wake as one
automated pass of the active skill. The watch stays on after a wake, so do not
watch the PR again on a wake. Pause or stop the watch with
`unwatch_pull_request`, also before handing the work back to the user; resume it
by watching again. Never poll a PR in other ways, such as with sleep, loops, or
scheduled tasks.

A watch does not wake when the target branch advances without a conflict, so
integrate target changes on the next wake or an explicit recheck. T3 ends the
watch itself when the PR merges or closes, possibly without a wake, and when it
cannot read the PR for 15 minutes. Handle a merged or closed PR on the next
pass, even if the user has to request it.

Keep only one thread monitoring a PR; do not silently take over a PR that
another thread monitors. Report that conflict for a decision.

For this task, reuse the existing watch. A `babysit-pr` request upgrades CI-only
monitoring to ongoing PR monitoring under the same watch. A pipeline handoff
under an active PR monitor returns to that monitor without creating or replacing
it. A CI-only pass ignores wakes caused only by comments or reviews. Derive
branch, revision, validation, and PR state live on every pass.

Ordinary messages do not stop monitoring. Honor explicit pause or stop requests
with `unwatch_pull_request` and verify the result before further background
actions. If that fails, stop background actions and report the failure. Resume
only on an explicit request. When a pass requires human input, pause and report
it; normal pending CI, human review, or merge is not itself a blocker. Notify
only for meaningful changes, completion, failures, or required user input; stay
quiet when nothing changed.
