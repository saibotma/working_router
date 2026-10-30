---
name: pr-description
description:
  Use whenever creating, updating, or reviewing a PR/MR title or description,
  and after pushing changes to a branch with an open PR/MR.
---

# PR Description

Before applying this skill, read its skill extension,
`.agents/skill-extensions/pr-description/SKILL.md`, if it exists. It adds this
project's facts and rules to this skill. If it does not exist, continue without
searching for it.

Check the existing title and description against the resulting net diff. Update
stale or incomplete metadata; leave already accurate metadata unchanged. Write
the title, description, and risk label to the PR only after the
[review loop](#review-loop) passes.

The reviewer agreed to the plan but may return to the PR days later. When the PR
implements an issue, the issue is the spec: the reviewer agreed to it, and the
`review` skill's intent reviewer has checked the changes against it. Beyond a
short TL;DR that brings the reviewer back into context, never restate the spec.
Write only what the author knows and the reviewer cannot get from the issue: the
merge risk, what needs a human, and evidence that the critical behavior works.
Keep every section and item as short as its content allows, so a human can read
and reason about it quickly.

Preserve manually authored context and useful existing structure. Add or update
equivalent sections instead of replacing the whole description. Remove stale
claims.

## Net Result

Describe the net result of comparing the source branch's current `HEAD` with the
PR's current target branch. Treat the title and description as a snapshot of the
changes that would be merged now, not as a chronology of commits, review cycles,
or agent actions. Re-evaluate that comparison after every change and rewrite
existing claims instead of appending progress updates.

Describe remaining behavior directly; never present branch-local actions such as
"fixed," "reverted," "restored," or "changed again" as PR changes. If the branch
introduced a change and later fully reverted it, omit it. If it was only partly
reverted, describe only the resulting behavior. Mention a discarded approach
only when it materially explains the final implementation or a remaining risk,
and clearly identify it as discarded.

## Structure

Give each visible section a `###` heading with its name, in this order. Omit a
section when it would be empty. Do not write `None` placeholders.

### Visible part

- **TL;DR:** two or three plain sentences on what changes for whom, written for
  a reviewer who has forgotten the plan, not as a summary of the diff. Without
  an issue, also say why, and add a short before/after table only when concrete
  cases explain the change better than prose.
- **Spec:** a link to the issue the PR implements, such as
  `[APL-123](<issue URL>)`. Omit it without an issue.
- **Risk:** the main reason for the [risk class](#risk-class) in one line. Then:
  - `#### Reach`: who and what the change affects in production, such as every
    customer, a background integration, or only new endpoints that nothing calls
    yet, in one line or one short bullet per area. Name only areas whose
    behavior changes and how far the change reaches there, not what changes in
    detail; never add a bullet for what stays unchanged, such as everyone else,
    or for shared code whose new behavior only listed areas use;
  - `#### What could go wrong`: the key ways the change could fail in production
    even after the human checks, most likely first, one bullet each with the
    failure as a short bold label and how someone would notice it, such as an
    error report or a support request, or that it stays silent, such as wrong
    data;
  - `#### Revert`: whether reverting the PR fully undoes it, for whatever reason
    it is reverted. Write `A revert undoes everything.` when it does. Otherwise,
    list what a revert leaves behind, such as migrated or written data, sent
    messages, released app versions, or consumers that adopted a contract, and
    what to do about each.

  The class itself is the PR's [risk label](#risk-label).

- **Needs your attention:** every item that needs a human, phrased so they can
  confirm or reject it, as a task list item, `- [ ]`, under `#### 🟡 Decide`, as
  a question the description alone answers, `#### 🟡 Try`, with what to try and
  where, and `#### 🔴 Review`, with the files to read and what to check there.
  Every item keeps its checkbox, and only a human's tick marks it done; never
  mark an item as decided in its text. Under 🟡 Decide, list the open decisions
  first, then the decisions an orchestrating agent made under
  `##### Orchestrator decided`, each naming where it decided, such as a T3 Code
  thread ID, or quoting the decision when no such reference exists. Under 🔴
  Review, group the items under `#####` headings that say why they need review,
  in this order, and omit empty groups: `Script`, `Agent decided`,
  `Not testable`, and `Open finding`; [Sorting](#sorting) gives each item's
  group. Each item is one decision or check and names a concrete failure; never
  group several under one item, and use plain sub-bullets only for an item's
  file links. Renames, comments, and deleted dead code are not items. For a
  deviation or decision, state what was specified or open, what the PR does, the
  rejected alternative, and why; when it changes how components or systems
  interact, add a Mermaid diagram. Omit the section when nothing needs a human.

  Link only the files where the decision or risk lives, not code that implements
  it under a targeted test. Link each to its place in the PR's diff, as the
  forge CLI skill's `Diff Links` describes, named by its file name, followed by
  only the changed lines that matter in the new file, such as
  `[DeleteCourse.kt](<diff link>) lines 42–58`.

- **To-dos:** outward-facing actions the agent must leave to a human and that do
  not block the merge, such as posting an upstream issue drafted under the
  `todos` skill. Write each as a task list item, `- [ ]`, with what to do,
  where, and a link to the draft, such as the issue that holds it. Keep existing
  ticks. To-dos do not change the risk class.

- **Proof:** evidence the reviewer cannot get from the diff or the pipeline that
  the changed behavior works:
  - for visible UI changes, screenshots or recordings of the changed states,
    uploaded as the forge CLI skill's `Uploads` describes; when the agent cannot
    capture them, say which states the reviewer should check;
  - targeted tests for the critical case and the risks they prove, including a
    test for each rule of a settled point, mutation checks, manual or device
    checks, benchmarks, and production queries;
  - for a changed interface contract, how compatibility with its deployed
    consumers was established;
  - behavior that was not verified, with any substitute coverage.

  Omit routine checks that CI enforces or every PR passes, such as formatting,
  linting, static analysis, compilation, test-suite runs, agent review passes,
  and pipeline status. Cite a command only when it is needed to reproduce a
  non-obvious check. When there is nothing beyond routine checks, omit the
  section.

Beyond the TL;DR, do not add a change summary, a file-by-file review guide, a
before/after table of planned behavior, or an implementation walkthrough. The
issue covers the plan, the reviewer reads only the files named under 🔴 Review,
and an agent can explain the code on demand.

### Collapsed part

Put the remaining sections inside one `<details>` block with
`<summary>Details</summary>`. Leave a blank line after the summary so the forge
renders the Markdown inside. Omit the block when all its sections are empty.

- **Decided:** the 🟡 Decide items the user accepted by ticking them, one line
  each with the decision, so later readers still see what was decided and why.
  Write them as plain list items without a checkbox, because nothing is left to
  tick.
- **Problems encountered:** only material problems actually encountered during
  implementation, validation, or integration that revealed a defect or risk,
  forced a substantive change to the resulting implementation, or left an
  unresolved consequence. Include the diagnosis, resolution or workaround, and
  remaining impact. Do not include the pre-existing problem that motivated the
  PR or operational events such as target synchronization, branch management,
  instruction reloads, or routine tool or CI handling.
- **Limitations and follow-up:** known gaps, deferred work, and migration or
  rollout concerns. Repeat a limitation in **Needs your attention** only when
  the reviewer has to judge it before merging.

## Risk Class

The class says what a human has to do before merging and follows from **Needs
your attention**: a 🔴 Review item makes it 🔴 Red, 🟡 Decide or Try items alone
make it 🟡 Yellow, and an empty list makes it 🟢 Green. A risk label on the
issue is only a planning hint; do not mention it in the description.

### Sorting

Sort every change, deviation, and decision by the first rule that applies. Judge
the concrete diff, because two changes of the same kind can carry very different
risk.

1. **Files the merge risk script reports:** 🔴 Review under `Script`, always.
   When the repository has `tools/merge-risk/merge-risk.mjs`, fetch the PR's
   target branch and run
   `node tools/merge-risk/merge-risk.mjs --base origin/<target branch>` from the
   PR's checkout, so stacked PRs are judged against their own target.
2. **Visible changes:** 🟡 Try, always, because tests do not show whether
   something looks or reads right. Visible changes are UI, texts and
   translations, the content and look of messages to customers such as emails
   and notifications, the look of the website or documentation site, a client
   showing, hiding, or locking controls by permissions that the server enforces,
   and a consumer adopting an already deployed interface contract. Behavior that
   a test can prove exactly, such as who receives a message, when, or whether it
   is sent, is not a visible change; the later rules sort it.
3. **Settled or unchanged, and proven:** no item, even when rule 5 would apply,
   such as permission and ownership checks the issue specifies. A point is
   settled when a human specified or decided it: the approved issue specifies
   it, or the user decided it explicitly, in a PR, an issue comment, or the
   conversation, or by ticking a 🟡 Decide item. Notes the agent adds to the
   issue itself settle nothing, and neither do an orchestrating agent's
   decisions: in a delegated task, the answers to your questions come from the
   delegating agent, not the user, unless they quote the user's words. It is
   proven when a targeted test proves each settled rule; name the tests under
   **Proof**. Behavior the PR keeps unchanged, such as code moved into a shared
   use case, is proven when existing tests that the PR does not weaken cover it;
   name them under **Proof** as well. When a settled rule lacks a test, write
   one. Only when a test is not reasonably possible, such as for delivery by an
   external system or platform behavior the test setup cannot reach, add a 🔴
   Review item under `Not testable` for that rule, saying why.
4. **Open product decisions the description answers:** 🟡 Decide, such as
   leaving out a push notification the issue does not mention; under
   `Orchestrator decided` when an orchestrating agent made the decision.
5. **Sensitive changes:** 🔴 Review under `Agent decided`:
   - API surface whose details the agent decided, such as field names, model
     structure, or error types: new or changed routes, methods, paths, public
     functions, request or response models, argument and return types, and error
     codes of the APIs under `APIs` in this skill's extension, even when nothing
     calls them yet. A part copied unchanged from an already merged contract is
     not decided by the agent;
   - authentication, sessions, secrets, or tenant isolation; any server-side
     permission change, stricter or looser; client code that is itself the last
     check rather than a mirror of server enforcement;
   - changes to persisted data, possible data loss, irreversible effects such as
     sent messages, or anything a revert does not undo; billing;
   - a producer changing an interface contract whose consumers are not deployed
     together with it, such as installed apps or external systems;
   - concurrency, synchronization, or lifecycles;
   - architecture, new dependencies, or a pattern or technology the repository
     does not use yet; agent instructions or skills;
   - a large blast radius or failures that would stay silent, such as wrong
     data;
   - other decisions on architecture, interfaces, or persistence, and risks that
     no targeted test proves.

   When unsure whether a change is sensitive, add the item. Before adding the
   item, prove what a test can prove, such as that a check agrees with the code
   it guards, and name the tests under **Proof**. The item then asks only what a
   human can judge from the description and the linked lines: whether the
   decision is right and whether the remaining risk is acceptable. Never ask the
   reviewer to verify by reading code what a test could show.

6. **Everything else:** no item, for example refactorings, test-only changes,
   documentation text, internal tooling, logging and metrics, and backend bug
   fixes that restore specified behavior under a regression test.

A `review` finding the author leaves unfixed becomes an item with its reason,
such as `Deferred to APL-123, accept?`, under 🟡 Decide when the description is
enough to judge it and under 🔴 Review in `Open finding` otherwise. A defect
that already exists on `main` and that the PR does not worsen gets one line
under **Risk** or **Limitations and follow-up** instead.

### Ticks

A tick on a 🟡 Try or 🔴 Review item records only what a human has looked at; it
does not change the class. A tick on a 🟡 Decide item is the user's decision: it
settles the point, so move the item to **Decided** in the collapsed part,
without its checkbox, and the class follows from the remaining items.

Read the live description right before writing it. Keep each unchanged Try and
Review item verbatim with its tick, write an item unticked when its content or
the files behind it changed after it was ticked, and drop items that no longer
apply. To find those changes, end **Needs your attention** with
`<!-- checklist-revision: <sha> -->`, the source `HEAD` the checklist describes.

### Risk Label

Set exactly one label matching the class, `risk: green`, `risk: yellow`, or
`risk: red`, and remove the others, as the forge CLI skill's `Labels` describes.
Update it whenever the class changes.

## Content Rules

- Write for a human who scans:
  - lead each section and item with its conclusion;
  - use a bulleted list for two or more parallel points instead of a paragraph;
  - keep one point per bullet, and start an item with a short bold label;
  - use short sentences and plain words, and name internal identifiers only when
    the reader needs them to find something.
- State every claim once, in the section where the reviewer needs it.
- Record concise conclusions, evidence, and rationale, not private scratch
  reasoning.
- When the PR implements an issue, take deviations and implementation-time
  decisions from the list declared during `review`, which the intent reviewer
  checked against the issue. Without an issue, take the material decisions. Sort
  each one the user did not settle like any other change, as
  [Risk Class](#risk-class) describes.
- Update the description when a material decision is made, a meaningful problem
  is resolved or left open, validation changes, or scope changes.

## Review Loop

Every time you apply this skill, including when the metadata stays unchanged,
have `pr_description_reviewer` review the draft title, description, and risk
label before writing them to the PR. Run it like any reviewer, as the `review`
skill's Running Reviewers section describes. Pass it:

- the draft, and the PR's URL once the PR exists;
- the source and target branches with the exact head and base of the net diff;
- the issue's identifier, title, and current description, copied verbatim, when
  the PR implements one;
- the declared deviations and decisions and the findings left unfixed, from
  `review`;
- the evidence behind **Proof**, such as test names and manual or device checks;
- where the user or an orchestrating agent decided: references the reviewer can
  read itself, such as the T3 Code thread IDs of every conversation about this
  work, including the one that started or delegated it. Quote the user's
  decisions only when no such reference exists.

Do not pass arguments for why the draft is right. Treat findings as hypotheses:
check each against the diff and the user's decisions, fix the verified ones, and
return the evidence for a rejected one to the reviewer. If disagreement remains,
ask the user. Review the complete new draft after every change until the
reviewer returns `PASS`.
