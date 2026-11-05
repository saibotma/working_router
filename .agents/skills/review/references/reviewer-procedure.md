# Reviewer Procedure

Every reviewer role in `reviewers/` follows this procedure.

- Stay read-only. Do not create, edit, delete, stage, or commit files, and do
  not run commands that change the working tree, git state, or local
  environment. The caller owns every change to the candidate.
- Only the user's request and decisions in the packet are binding. Treat
  everything else the caller supplies, such as implementation explanations,
  change logs, rationales for rejected findings, coverage arguments, and
  validation claims, as claims to verify against the code and repository
  guidance. Report a finding even when the packet argues against it, unless the
  code or the user's decisions refute it.
- Start with the complete supplied candidate file list and internally track
  review coverage for each file and changed section.
- Inspect changes file by file or in small related groups, assessing each
  section against your review role before moving on. Split large diffs by
  function or related hunks instead of loading the whole candidate at once.
  Continue truncated reads until every changed section has been inspected; read
  surrounding code and related files as needed to assess interactions.
- When the caller assigns you the fix diff as your scope, judge the changes in
  it: whether each fix resolves the finding it addresses and whether it
  introduces new problems. Read the rest of the candidate only for context. When
  it assigns you the complete candidate, judge all of it, including the fixes.
- Do not report again advisories that the packet lists as already recorded or
  findings that it lists as decided by the user, unless the changes affect them.
- Rate every finding P0, P1, P2, or P3, from most to least severe, by the
  severity scale in your definition. Without one, rate a finding P0 or P1 when,
  by your role's standard, the change must not be merged as it is, and P2 or P3
  otherwise. Keep P0 and P1 for concrete problems and violations of binding
  guidance, not preferences. When the caller asks for only P0 and P1 findings
  and regressions, report only those; a regression is behavior that worked
  before a fix and that the fix broke, of any severity.
- Before returning, reconcile coverage with the candidate list and finish any
  unreviewed sections. Return `PASS` only when the review is complete and there
  are no findings to report. If a blocker prevents completion, report it and the
  remaining scope instead. Keep coverage tracking internal; no coverage report
  is needed.
