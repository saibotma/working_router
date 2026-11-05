---
name: agent-tooling
description:
  Use when creating or changing agent configuration, including AGENTS.md files,
  skills, reviewer roles, MCP servers, and Codex or Claude Code settings.
---

# Agent Tooling

Agents run in T3 Code, with Codex or Claude Code as the provider. Keep agent
configuration usable from both providers: provider-specific files under
`.codex/` and `.claude/` only configure or point to the shared sources below.

- Put instructions in `AGENTS.md` files. Claude Code loads root and nested
  `AGENTS.md` files natively, so do not add `CLAUDE.md` files.
- Put skills in `.agents/skills/`. `.claude/skills` is a symlink to that
  directory.
- Keep the MCP servers in `.mcp.json` and `.codex/config.toml` in sync, and list
  every `.mcp.json` server in `enabledMcpjsonServers` in
  `.claude/settings.json`.
- Deny Claude Code's own worktree tools, `EnterWorktree` and `ExitWorktree`,
  under `permissions.deny` in `.claude/settings.json`, so agents manage
  worktrees only through T3 Code, as the `git` skill describes.

## Shared Skills

Skills shared across projects live in the `appella/agent-stack` repository.
Projects install them into `.agents/skills/` with `@appella/skills-cli`, a
pinned dev dependency, and commit the installed copies together with
`.agents/skills.lock`, which records the source commits and every installed
skill's hash.

- Select the shared skills in `.agents/skills.yaml`, which you edit by hand.
  Every project gets agent-stack's untagged skills; `tags` adds each skill whose
  tags it lists all of, `include` adds single skills, and `exclude` removes
  them:

  ```yaml
  sources:
    agent-stack:
      url: git@gitlab.com:appella/agent-stack.git
      tags: [gitlab, linear, dart, flutter]
      include: [graphql]
  ```

  agent-stack's README lists its tags. Run `pnpm exec skills get` after every
  edit of the manifest and commit the result. `pnpm exec skills list` shows the
  skills that the manifest does not select, with their tags.

- Never edit a skill that `.agents/skills.lock` records in a project. Change it
  in `agent-stack`, then update the project with `pnpm exec skills upgrade` and
  commit the result. `get` and `upgrade` fail instead of overwriting local
  edits; do not pass `--force` to discard them unless the user asks.
- In `agent-stack`, give a new skill a tag unless every project should get it.
- Put project-only skills directly into `.agents/skills/`; the lock does not
  record them, and `skills` never touches them. The same holds for skills that
  other tools install, such as Convex's from `npx convex ai-files`; update them
  with that tool.
- Keep shared skills free of project paths, commands, and names. When a shared
  skill needs such facts, state them in its
  [skill extension](#skill-extensions).
- Run `pnpm exec skills check` and
  `pnpm exec node .agents/skills/agent-tooling/scripts/check-agent-links.mjs` in
  CI, with `remark-cli` and `remark-validate-links` as pinned dev dependencies,
  so edits to installed copies fail instead of being lost, extensions that no
  skill file reads fail instead of being silently ignored, and links in agent
  files to moved or removed files fail. `pnpm exec` runs them on the project's
  pinned Node.js, also in CI images without Node.js on `PATH`, such as
  `ghcr.io/pnpm/pnpm`.
- Run `pnpm exec skills check --source` before merging changes to
  `.agents/skills.lock`. It fetches the sources at their locked commits and
  catches an edited skill whose hash in the lock was edited as well, which plain
  `check` cannot tell.

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
  file, first add the same instruction to it in `agent-stack`; `skills check`
  fails for an extension that its skill file does not read.
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
