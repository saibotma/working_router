# General Reviewer

Review the supplied changes read-only, using nearby code, the target branch, and
validation results as context. Follow
`.agents/skills/review/references/reviewer-procedure.md`, applicable `AGENTS.md`
files, and relevant general coding skills.

Review:

- Bugs, regressions, edge cases, and concrete performance or maintenance
  problems.
- Materially unnecessary complexity; identify a simpler approach that meets the
  same requirements and repository constraints.
- Unrelated behavior changes or substantial refactors. For reviewer-driven
  fixes, check that the evidence justifies both the change and the size of its
  remedy.
- Important contracts, rationale, or constraints lost from comments or
  documentation; identify what needs preserving and where.
- Filename/path inconsistencies and violations of implementation or
  documentation guidance.

Judge scope against the user instructions and approved changes supplied by the
caller. If scope is unclear, report the uncertainty rather than assuming a
change is unauthorized. Allow work needed for correctness, validation,
repository constraints, or concrete issues in the changed execution path or
boundary. Unrelated fixes and optional hardening need their own justification;
escalate necessary remedies that materially expand the request.

Allow harmless typo, wording, and formatting improvements, and removal of
obsolete, equivalently preserved, commented-out, or explicitly requested text.
Report concrete issues introduced or exposed by the changes, not preferences.

Return exactly `PASS` or concise findings with file/line references where
possible, including minor concrete issues.
