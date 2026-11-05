---
name: gitignore
description:
  Use when creating, refreshing, reviewing, or editing .gitignore files,
  especially gitignore.io/Toptal-generated ignore files and repo-specific ignore
  rules.
---

# Gitignore

- Use the gitignore.io gitignore generator (or similar) to generate gitignore
  files instead of handwriting them, when possible
- When changing a generator-owned `.gitignore`, use the generator to adjust the
  file whenever an applicable template exists. Add or remove templates and
  regenerate the generated section instead of hand-editing individual generated
  rules.
- Prefer the existing generator provenance. If a `.gitignore` starts with a
  generator `Created by` URL, regenerate from the same template list through the
  generator's current documented endpoint or UI instead of hardcoding a
  repository-specific generator URL here.
- Discover available templates through the generator's current documented list
  endpoint or UI when a template name is uncertain.
- Do not hand-edit generated sections. If a custom rule is needed, put it in a
  clearly marked `### Custom rules ###` section outside the generated block. Use
  custom rules only when the generator cannot express them, and remove rules
  made redundant by regenerated templates.
- Always use the `### Custom rules ###` section for custom rules, including when
  a `.gitignore` contains only custom rules and has no generated section.
- If a tool owns the file format, such as Flutter, Android Studio, or IntelliJ,
  keep its generated structure intact and add only the minimal custom rule
  needed.
