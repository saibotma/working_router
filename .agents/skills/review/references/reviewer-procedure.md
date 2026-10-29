# Reviewer Procedure

Every reviewer role in `reviewers/` follows this procedure, regardless of which
agent harness runs it.

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
- Before returning, reconcile coverage with the candidate list and finish any
  unreviewed sections. Return `PASS` only when the review is complete and there
  are no findings. If a blocker prevents completion, report it and the remaining
  scope instead. Keep coverage tracking internal; no coverage report is needed.
