---
name: issues
description:
  Use when planning, creating, or changing issues in the repository's issue
  tracker, including planning an issue with the user before implementing it.
---

# Issues

The repository's `AGENTS.md` names its issue tracker and the skill that works
with it, such as `linear` for Linear or `github-cli` for GitHub issues. Use that
skill for every issue operation. When `AGENTS.md` names no tracker, do not
create or change issues; ask the user where the work is tracked.

Issues in a public tracker, such as the GitHub issues of a public repository,
are public. Keep everything that is not public out of them: links to private
repositories, internal trackers, or agent threads, customer data, internal
details, and secrets.

## Planning an Issue for Implementation

The issue description is the approved intent of the work. After implementation,
the `review` skill's intent reviewer checks the changes against the issue alone,
without the planning conversation. Anything agreed only in the conversation is
therefore treated as unplanned.

- While planning with the user, edit the existing issue's description directly
  as the plan changes. Preserve the original request or problem statement.
  Create an issue only when none exists and the user wants one.
- Before implementing, update the description to reflect everything agreed in
  the conversation. If that adds anything the user has not explicitly agreed to,
  ask first.
- Describe:
  - **Context:** the problem and why it matters.
  - **Scope** and **non-goals**.
  - **Decisions:** the settled approach, especially architecture, components,
    interfaces between systems, and data handling, as precisely as the
    discussion established it.
  - **Acceptance criteria:** observable behavior that can be checked against the
    changes.
  - **Open decisions:** points the implementing agent must not decide alone.
- Scale the detail to the risk and uncertainty of the change; a small, clear
  change needs only a few lines. Leave out what the discussion did not settle
  instead of inventing precision.

## Splitting Work Across PRs

When an issue needs several PRs, create one sub-issue per PR that is an
independently understandable implementation step, and link each PR only to its
sub-issue. Never link a PR to the parent issue, so that the parent does not
close early; close it once all needed sub-issues are done and its acceptance
criteria hold. A small mechanical follow-up PR may reuse the sub-issue of the
step it belongs to.
