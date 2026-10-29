---
name: address-pr-comments
description:
  Use when asked to address PR/MR review comments or feedback in a single pass,
  or when babysit-pr delegates comment handling.
---

# Address PR Comments

Handle the current feedback on one PR once. Use the forge CLI skill of the PR's
host, `gitlab-cli` or `github-cli`. A request to address comments includes
implementing eligible fixes, publishing them, and replying in their discussions
under the rules below. Honor any narrower user scope, such as analysis only or
local changes only.

Do not wait for new feedback, merge the PR, or perform post-merge cleanup. When
called by `babysit-pr`, return to that workflow; it owns ongoing monitoring and
CI follow-up.

## Pass

1. Inspect live PR status, owner, current reviewers, source branch, and target.
   Return if the PR is closed or merged. Read all discussions under the feedback
   rules below. Use existing replies, reactions, and the current code to avoid
   repeating completed fixes or confirmations on later invocations.
2. Evaluate current feedback under those rules. Complete eligible work even if
   other comments await a decision; report those remaining discussions. For
   content changes, read
   [Publishing changes](../prepare-pr/references/publishing-changes.md),
   implement, validate, run `review`, and commit coherent fixes with discussion
   links. Preserve material review advisories for the caller and PR follow-up.
3. Invoke `sync-pr` to publish committed fixes and refresh metadata. Confirm
   addressed feedback only after the fix is pushed and validated. For an
   already-applied fix, verify that evidence before confirming it. Questions or
   disagreements that need no code change can be answered directly.
4. Report addressed discussions, fixing commits, validation, and any feedback
   still awaiting a decision. Distinguish local validation from CI status; do
   not claim pending CI is green. Return the source revision and whether it was
   synchronized to `babysit-pr` when called by it. A standalone pass ends here.

## Feedback Rules

Load all feedback with full pagination, as the forge CLI skill's `Feedback`
describes, and inspect every new human comment, not only unresolved threads,
before treating feedback as complete. A discussion is a comment together with
its replies.

Validate human feedback against repository guidance before acting. Reply when
feedback is incorrect, conflicts with product intent, or needs clarification;
answer questions directly in the discussion.

The workflow may fix feedback without further owner input when exactly one
obvious local implementation exists and no human judgment is needed. This
includes spelling, formatting, an unambiguous rename, or a deterministic lint
correction.

For non-mechanical feedback, first compare the feedback author with the PR
owner. Treat a comment authored by the PR owner as the owner's decision and
handle it without requiring an additional reply. Also handle feedback without
owner acknowledgment when a current PR reviewer adds a thumbs-up reaction to
their own concrete, actionable comment; treat that self-reaction as an explicit
direction to implement the comment. Otherwise, for feedback from anyone else, do
not change content until the PR owner either adds an unambiguous approval
reaction, such as the forge's approval reaction, to the comment, or replies
personally in the same discussion with the intended solution, a disagreement or
question, or a note that the change is already done. A reaction does not make a
question, ambiguous request, or choice between alternatives actionable. Verify
the reviewer's current assignment, the comment author, and the reaction author;
a non-owner's reaction authorizes direct implementation only when they are a PR
reviewer and also authored that comment.

Treat feedback as non-mechanical when it can affect behavior, test meaning,
control or data flow, error handling, nullability, architecture, security,
concurrency, compatibility, persistence, contracts, or scope, and treat every
uncertain case the same way. Owner-authored feedback, an unambiguous owner
approval reaction, a reviewer's thumbs-up on their own comment, or an owner's
reply makes actionable feedback eligible for further workflow handling but does
not override the request or repository guidance. Ask or push back when the
direction remains unclear or wrong.

For addressed feedback, reply in the same discussion and add a done reaction to
the original comment only after any fix is pushed and validated. Never resolve a
human discussion. Link the discussion in the fix commit body. In fix
confirmations, include the fixing commit SHA and link when available.

Prefix every comment or reply with the current assistant's name exactly once
using `[Assistant Name] `.
