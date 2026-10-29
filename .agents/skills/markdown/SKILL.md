---
name: markdown
description: Use when editing Markdown (including SKILL.md) files.
---

Before applying this skill, read its skill extension,
`.agents/skill-extensions/markdown/SKILL.md`, if it exists. It adds this
project's facts and rules to this skill. If it does not exist, continue without
searching for it.

- Format affected files with the repository's Markdown formatter and validate
  them with its check mode. This skill's extension names the formatter. Without
  one, run `npx prettier --write <file.md> ...` from the repository root and
  validate with the same command using `--check`.
- Format the whole repository only for repository-wide formatting work.
- Do not format skills that `skills-lock.json` lists; they are read-only copies
  of their source.
