---
name: review
description:
  Use after completing requested repository changes, before reporting
  completion, and for explicit local reviews or workflow handoffs. Reuse current
  review coverage; exclude investigation or planning without changes.
---

# Review

Before applying this skill, read its skill extension,
`.agents/skill-extensions/review/SKILL.md`, if it exists. It adds this project's
facts and rules to this skill. If it does not exist, continue without searching
for it.

Run a local review loop. Do not push, create branches, create PRs, poll CI, or
contact reviewers.

Review the completed candidate and return validation results and any advisories
to the caller. When another operation called this skill, return control after
review so it can continue; do not treat its remaining PR or CI work as complete.
Local review alone does not authorize commits, pushes, or external actions.
Review must pass before the candidate is committed, published, or reported done.
A completed review can be reused when its candidate is unchanged; committing,
restaging, pushing, or restarting the task does not itself require another pass.

## Review Gate

Before every review pass, identify the exact candidate file paths that the
reviewers must judge and the source from which they should inspect those
changes. Prefer the staged diff when the candidate is staged. Otherwise use the
path-scoped unstaged changes and identify new untracked files explicitly. For an
existing commit or commit range, identify the exact base and head. Do not
include unrelated file paths.

For the initial pass, retain the original candidate file paths, diff, and base
or an equivalent stable description. This defines the review loop's scope. Every
subsequent pass reviews that complete original candidate as updated by all
changes made during the loop, including fixes in additional files. Do not narrow
a later pass to the latest fixes or reset the baseline after a commit or
restaging. This is a review of the candidate diff, not the entire repository.

Maintain a reviewer-driven change log throughout the review loop. For every
implemented review finding, record:

- the reporting reviewer and finding
- the evidence that verified it
- why it was classified as blocking
- the files changed by the remedy
- why the remedy was considered necessary and proportionate
- any materially simpler remedy considered and why it was insufficient

Pass the candidate file paths and diff source to every selected reviewer. The
supplied file list is the authoritative review boundary. Keep the candidate
files unchanged while reviewers are running. Reviewers must inspect the changes
for those files themselves. They may inspect nearby code for context, but they
must not widen the review to changes in files absent from the supplied list. The
file list limits what a pass reviews; it does not authorize unrelated work. Any
file changed to address a finding becomes part of the complete candidate and
must appear in every subsequent applicable review packet.

On every review pass for a candidate packet, run the always-on reviewers:
`validation_reviewer` and `general_reviewer`. The general reviewer covers
correctness and solution proportionality, including reviewer-driven scope
expansion. Run every reviewer as described under
[Running Reviewers](#running-reviewers).

Reassess which conditional specialist reviewers apply to the complete current
candidate on every pass:

- Run `architecture_reviewer` when the candidate changes production source code.
  Do not run it for test-only, documentation-only, generated-only, or
  formatting-only changes.
- Run `security_reviewer` when touched code is security-sensitive, including
  authentication, authorization, permissions, sessions, tokens, passwords,
  crypto, tenant/account isolation, database query construction, file
  upload/download, secrets, environment variables, logging, network calls,
  dependency configuration, CI configuration, deployment configuration, the
  surfaces under `Security-sensitive surfaces` in this skill's extension, or
  similar security-relevant surfaces. Do not run it for test-only changes unless
  they change security-sensitive test infrastructure, handle real secrets or
  credentials, or could expose sensitive data.
- Run `compatibility_reviewer` when touched code affects public or persistent
  contracts, including API routes and request/response models, public function
  arguments and return values, real-time messages, generated clients, database
  schemas and migrations, local persistence, serialized data, deep links,
  release/versioning behavior, app/server interoperability, or the contracts
  under `Persistent contracts` in this skill's extension.
- Run `convex_reviewer` when touched code affects Convex functions, the schema,
  HTTP actions, generated Convex code, Convex configuration, or the Convex AI
  guidelines.
- Run `customer_content_reviewer` when touched code changes customer-visible
  behavior in a way that could make customer content stale, such as customer
  documentation, the website, or store metadata, or when the candidate changes
  that content. The section `Customer content` in this skill's extension says
  where that content lives.
- Run `dart_flutter_reviewer` when touched code affects Dart or Flutter source,
  configuration, dependencies, generated Dart code, or Flutter platform
  integration.
- Run `intent_reviewer` when the candidate implements an issue.
- Run `upstream_reviewer` when the candidate adds or changes dependency
  overrides, git dependencies, version pins, or patched or vendored code; adds
  code that works around behavior of a dependency; or implements functionality
  that a dependency already provides or arguably should provide. A dependency is
  anything the code builds on: a language, framework, library, package,
  platform, tool, or external service, whether the repository already uses it or
  it is an established option.
- Run every project reviewer whose trigger applies. Projects list their own
  conditional reviewers in a table under `Project reviewers` in this skill's
  extension, each with a name, a definition file, and a trigger, for concerns
  that only exist in that project.

If uncertain whether a conditional specialist applies, run it.

Also run every reviewer whose finding was addressed earlier in this loop, even
if its specialist trigger no longer applies. Keep those reviewers in every
remaining pass so removing or changing the triggering code cannot bypass their
review of the remedy.

Pass a compact review packet with:

- the user request, including relevant later instructions and approvals
- the intended review scope
- whether the diff is staged, unstaged, or a commit range, including the exact
  base and head when applicable
- the target or base branch and whether affected compatibility contracts have
  already been released, when relevant
- validation already performed
- relevant changes in intent and discarded intermediate approaches when they
  affect the candidate tests
- the exact candidate file paths
- selected conditional reviewers and the trigger reason, or why no conditional
  reviewer was selected

For every general-reviewer pass after the initial pass, also include:

- the original candidate file paths and diff or stable description
- the complete current candidate file paths and diff source
- the reviewer-driven change log
- every finding that caused the candidate to change, including its evidence and
  classification
- any files added to or removed from the candidate since the initial pass

Pass `intent_reviewer` a different packet, so that the implementing agent's
understanding of the request cannot mask a misunderstanding of the intent:

- the issue's identifier, title, and current description, fetched from the issue
  tracker and copied verbatim, not summarized
- the diff source and exact candidate file paths, as for the other reviewers
- the current
  [declared deviations and decisions](#declared-deviations-and-decisions)
- validation already performed

Do not pass it the user request, the conversation, or explanations of the
implementation.

Ask subagents to inspect the changes for the supplied candidate files themselves
and to judge only those changes. They may inspect nearby code for context, but
do not ask them to look for or report unrelated issues. Preserve the security
reviewer's existing exception for concrete vulnerabilities discovered in
necessary context; handle its advisories and escalations under the rules below.

Include any real reason for an intentional comment removal, cleanup-only change,
or validation exception so the subagents can judge it. Do not coach the
subagents toward approval.

Collect each reviewer's result using the response contract in its definition.

## Running Reviewers

Each reviewer role is defined once, independent of the agent harness, in
`.agents/skills/review/references/reviewers/`, or for project reviewers in the
definition file that the `Project reviewers` table names. Every reviewer runs on
`gpt-6.1-sol` with `xhigh` reasoning effort, regardless of the main agent's
model, in a fresh subagent context; do not fork the main agent's full context.

| Reviewer                    | Definition                                                       |
| --------------------------- | ---------------------------------------------------------------- |
| `general_reviewer`          | `.agents/skills/review/references/reviewers/general.md`          |
| `validation_reviewer`       | `.agents/skills/review/references/reviewers/validation.md`       |
| `architecture_reviewer`     | `.agents/skills/review/references/reviewers/architecture.md`     |
| `security_reviewer`         | `.agents/skills/review/references/reviewers/security.md`         |
| `compatibility_reviewer`    | `.agents/skills/review/references/reviewers/compatibility.md`    |
| `dart_flutter_reviewer`     | `.agents/skills/review/references/reviewers/dart-flutter.md`     |
| `intent_reviewer`           | `.agents/skills/review/references/reviewers/intent.md`           |
| `upstream_reviewer`         | `.agents/skills/review/references/reviewers/upstream.md`         |
| `convex_reviewer`           | `.agents/skills/review/references/reviewers/convex.md`           |
| `customer_content_reviewer` | `.agents/skills/review/references/reviewers/customer-content.md` |
| `pr_description_reviewer`   | `.agents/skills/review/references/reviewers/pr-description.md`   |

The review gate does not run `pr_description_reviewer`; the `pr-description`
skill runs it in its review loop.

Run them with the mechanism of the current harness:

- **Codex:** Spawn the project custom agent by name. Its `.codex/agents/`
  configuration pins the model, reasoning effort, and read-only sandbox; the
  `agent-tooling` skill describes these wrappers.
- **T3 Code:** Use the `t3-code` MCP `delegate_task` tool with one task per
  reviewer: `target.providerInstanceId` `codex`, `target.model` `gpt-6.1-sol`,
  `target.options.reasoningEffort` `xhigh`, `role` `review`, and `mode` `async`.
  Always set the reasoning effort explicitly; delegated tasks do not apply the
  Codex agent configuration, and the model's default effort is lower. Name the
  reviewer in the task title. Begin the task prompt with an instruction to read
  and follow the reviewer's definition file, then add the review packet, inline
  or as a file the reviewer can read. Start all reviewers of a pass before
  collecting their results.
- **Otherwise:** If no mechanism can run the reviewers on `gpt-6.1-sol`, do not
  report the review complete; ask the user whether to proceed with a local-only
  review fallback.

## Finding Verification

Treat reviewer findings as hypotheses rather than proof. For a claimed
observable bug, regression, race, performance problem, or integration failure
that can reasonably be automated:

1. Add a focused reproduction test against the unchanged candidate and confirm
   that it fails for the claimed reason.
2. If the finding is verified, fix the code and retain the test as regression
   coverage when it is stable and proportionate.
3. If the test does not reproduce the finding after reasonable investigation,
   remove the investigative test and reject or escalate the finding instead of
   changing production code.

When an automated test is not practical, reproduce the finding with a focused
command or establish a concrete failing execution path or authoritative
contract. Do not implement a change solely because a reviewer asserted the
problem. Return the evidence and rejection rationale for an unsupported finding
to the reporting reviewer for reconsideration. If disagreement remains, ask the
user rather than silently counting the finding as resolved.

## Finding Classification

Verification establishes whether a finding is real; it does not establish that
fixing it belongs in the candidate. After verification, classify every finding:

- `BLOCKING`: The candidate introduces, worsens, makes reachable, or relies upon
  the issue; knowingly leaves a concrete issue in the same changed execution
  path or boundary; or cannot satisfy the explicit request or an applicable
  repository constraint without resolving it. Fix it using the smallest complete
  and safe remedy.
- `ADVISORY`: The issue is pre-existing and merely adjacent to the candidate,
  and the candidate does not affect it. Preserve its severity, evidence,
  location, non-blocking rationale, and recommended follow-up for the final
  report. Do not modify code or create a follow-up issue without user
  authorization.
- `ESCALATION`: The issue is critical even though it is outside the candidate,
  its relationship to the candidate remains uncertain, or its safe remedy would
  materially expand the requested work. Stop and ask the user how to proceed.

The reporting reviewer may propose a classification, but the main agent must
judge it from the verified evidence and the original request. A finding being
pre-existing does not make it non-blocking when it remains in the same changed
execution path or security boundary and would leave the requested behavior
knowingly unsafe or incorrect. Conversely, severity alone does not authorize an
unrelated implementation change; critical adjacent findings require escalation.

Treat `upstream_reviewer` findings about a missing, incomplete, or unverified
workaround marker as blocking. Treat its other findings as advisory even though
they concern the candidate, and also record them on the workaround's issue.

Only blocking findings enter the automatic fix loop. An advisory-only reviewer
result counts as passed for the candidate, but its advisories must remain in the
final report. Do not report a clean review while a blocking finding or
escalation is unresolved.

## Declared Deviations and Decisions

When the candidate implements an issue, the issue describes the approved intent.
Keep a list of where the candidate knowingly departs from it, which the intent
reviewer checks and `pr-description` presents to the human reviewer:

- **Deviations:** the issue specified an approach, but the candidate does
  something else because the plan did not hold. For each, record what the issue
  specified, what was found, what the candidate does instead, and why.
- **Implementation-time decisions:** material decisions the issue does not
  settle, especially on architecture, interfaces between systems, persistence,
  or data handling. For each, record the decision, the main rejected
  alternative, and why.

Do not change the issue to match the candidate; it remains the approved intent.
A deviation may change the approach, but not an acceptance criterion or
non-goal, and it may not decide a point the issue reserves for the user. Ask the
user before the candidate depends on such a change.

Treat intent reviewer findings as blocking, except `CHANGES_INTENT` and
`AMBIGUOUS_ISSUE`, which are escalations. Resolve them as follows:

- `MISSING`: implement or test the criterion.
- `UNPLANNED`: remove the change unless it is needed to implement the issue; in
  that case, record why as an implementation-time decision.
- `UNDECLARED_DEVIATION`: align the candidate with the issue unless the
  departure is deliberate and justified; in that case, declare it.
- `QUESTIONABLE_DEVIATION`: strengthen the evidence for the deviation or align
  the candidate with the issue.

A change only to the declared list leaves the candidate unchanged for the other
reviewers; rerun only the intent reviewer.

## Repeat and Complete

If the candidate changes after a review pass, update the complete candidate and
change log, perform relevant validation, and restart the review gate with all
required reviewers. This includes test-only changes, formatting, and exact
removals or reversions. Do not retain individual reviewer approvals across
candidate changes.

Complete the loop only when every reviewer required for the current pass has
approved the same unchanged candidate, relevant validation passes, and no
blocking findings or escalations remain. Verified advisory-only results count as
approval; preserve the advisories in the result and caller handoff.

## Workflow

1. Review the current implementation context and pending changes.
2. Run relevant local validation.
3. Run the review gate.
4. Verify and classify reported findings. Return unsupported findings to the
   reporting reviewer, preserve advisories, and escalate unresolved or
   materially scope-expanding findings.
5. Fix blocking issues and repeat validation and the full review gate whenever
   the candidate changes.
6. Return the successful review result, any preserved advisories, and the
   declared deviations and decisions, or report the blocker preventing
   completion. `pr-description` lists every finding left unfixed as a decision
   item.
