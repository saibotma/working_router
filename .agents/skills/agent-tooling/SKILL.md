---
name: agent-tooling
description:
  Use when creating or changing agent configuration, including AGENTS.md files,
  skills, reviewer roles, MCP servers, and Codex or Claude Code settings.
---

# Agent Tooling

Keep agent configuration usable from every supported agent harness: Codex,
Claude Code, and T3 Code. Harness-specific files under `.codex/` and `.claude/`
only configure or point to the shared sources below.

- Put instructions in `AGENTS.md` files. Claude Code loads root and nested
  `AGENTS.md` files natively, so do not add `CLAUDE.md` files.
- Put skills in `.agents/skills/`. `.claude/skills` is a symlink to that
  directory.
- Keep the MCP servers in `.mcp.json` and `.codex/config.toml` in sync, and list
  every `.mcp.json` server in `enabledMcpjsonServers` in
  `.claude/settings.json`.

## Shared Skills

Skills shared across projects live in the `appella/agent-stack` repository.
Projects install them into `.agents/skills/` with `npx skills` and commit the
installed copies together with `skills-lock.json`, which records every installed
skill and its content hash.

- Never edit a skill listed in `skills-lock.json` in a project. Change it in
  `agent-stack`, then update the project with `npx skills update -p -y`, copy
  new or changed reviewer wrappers from `agent-stack`'s `.codex/agents/`, and
  commit the result. `update` silently overwrites local edits once the skill
  changes upstream, and it does not touch `.codex/agents/`.
- Install a new shared skill with
  `npx skills add git@gitlab.com:appella/agent-stack.git --skill <name> --agent codex -y`.
  Restricting the install to Codex writes only to `.agents/skills/` and keeps
  the `.claude/skills` symlink intact.
- Put project-only skills directly into `.agents/skills/`; they stay out of
  `skills-lock.json`.
- Keep shared skills free of project paths, commands, and names. When a shared
  skill needs such facts, state them in its
  [skill extension](#skill-extensions).
- Run `node .agents/skills/agent-tooling/scripts/check-installed-skills.mjs` and
  `node .agents/skills/agent-tooling/scripts/check-skill-extensions.mjs` in CI,
  so edits to installed copies fail instead of being lost and extensions that no
  skill file reads fail instead of being silently ignored.
- Check the links in agent files in CI with
  `npx remark --use remark-validate-links --frail --quiet --no-stdout '**/AGENTS.md' .agents`,
  with `remark-cli` and `remark-validate-links` as pinned dev dependencies, so
  links to moved or removed files fail.

## Skill Extensions

A skill extension adds a project's facts and rules to one shared skill file, so
agents read them only together with that file instead of in every session.

- Put the extension of `.agents/skills/<path>` at
  `.agents/skill-extensions/<path>`, such as
  `.agents/skill-extensions/review/SKILL.md` for the `review` skill and
  `.agents/skill-extensions/review/references/reviewers/security.md` for the
  security reviewer.
- Only shared files that a project extends tell agents to read their extension,
  so agents don't look for extensions that no project has. To extend another
  file, first add the same instruction to it in `agent-stack`; the extension
  check fails for an extension that its skill file does not read.
- Use the section headings that the shared file names, such as
  `Persistent contracts` in the `review` extension, so its rules link to an
  exact section.
- Put facts that several extensions need into `.agents/skill-extensions/shared/`
  and link them with relative Markdown links, such as
  `[contracts](../shared/contracts.md)`, instead of repeating them. Link whole
  files, not sections, so agents read only the facts they need; split a shared
  file when an extension needs only part of it.
- Add facts and rules only. When a project needs a shared rule to change, change
  it in `agent-stack`.
- Keep rules that apply in every session, regardless of the skill, in
  `AGENTS.md`.

## Reviewers

- Put shared reviewer roles in the `review` skill's `references/reviewers/` and
  list them in its reviewer table.
- Put project reviewer roles in `.agents/reviewers/`, and list each one with its
  name, definition file, and trigger in a table under `Project reviewers` in the
  `review` skill's extension, `.agents/skill-extensions/review/SKILL.md`:

  ```markdown
  ## Project reviewers

  | Reviewer           | Definition                     | Run when                 |
  | ------------------ | ------------------------------ | ------------------------ |
  | `example_reviewer` | `.agents/reviewers/example.md` | The candidate changes X. |
  ```

- Give every reviewer that a project uses a thin Codex wrapper in
  `.codex/agents/<name>.toml`, where `<name>` is the reviewer name with hyphens,
  such as `general-reviewer.toml` for `general_reviewer`:

  ```toml
  name = "general_reviewer"
  description = "Read-only reviewer for correctness and proportionality."
  # Pin the model and effort that the `review` skill requires, independent of
  # the parent session.
  model = "gpt-6.1-sol"
  model_reasoning_effort = "xhigh"
  sandbox_mode = "read-only"
  developer_instructions = """
  Read and follow `.agents/skills/review/references/reviewers/general.md` (relative to the repository root).
  """
  ```
