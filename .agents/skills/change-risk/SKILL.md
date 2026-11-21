---
name: change-risk
description:
  Use when judging which changes need a human decision or review, such as
  planning an issue's decisions or sorting a PR's review items.
---

# Change Risk

Before applying this skill, read its skill extension,
`.agents/skill-extensions/change-risk/SKILL.md`, if it exists. It adds this
project's facts and rules to this skill. If it does not exist, continue without
searching for it.

These areas hold the changes that need a human. The skills that use them say
what to do with a change in each area. Judge each change by its content, not by
its file.

## Contracts

- **Database schemas:** changes to a database schema and schema or data
  migrations, because they change stored data directly.
- **API contracts:** new or changed routes, methods, paths, public functions,
  request or response models, argument and return types, and error codes of the
  APIs under `APIs` in this skill's extension, even when nothing calls them yet.
  A part copied unchanged from an already merged contract is not a change.
- **Billing:** prices, plans, subscriptions, entitlements, payments, and the
  integration with payment providers.

## Dependencies

A direct dependency added or removed, or its version or version constraint
changed; an added, removed, or changed override or resolution that pins another
dependency, such as `dependency_overrides` or `pnpm.overrides`; a changed pinned
SDK or framework version, such as the Flutter version; and changes to vendored
or forked third-party code. Comments, formatting, and reordering in a manifest,
changes only to a lockfile, and build tool versions, such as the Gradle wrapper
or the package manager, are not dependency changes.

## Sensitive changes

Decisions where a wrong choice is hard to undo or stays silent and judging it
needs what only a human knows, such as product intent, team conventions, or
costs outside the repository. These are decisions in the following areas:

- authentication, sessions, secrets, or tenant isolation; any server-side
  permission change, stricter or looser; client code that is itself the last
  check rather than a mirror of server enforcement;
- changes to persisted data, possible data loss, irreversible effects such as
  sent messages, or anything a revert does not undo;
- a producer changing an interface contract whose consumers are not deployed
  together with it, such as installed apps or external systems;
- concurrency, synchronization, or lifecycles;
- an architecture, pattern, library, or technology the repository does not use
  yet;
- what changed agent instructions tell agents to do, but not the scripts or
  other tooling that skills ship with;
- likely failures that would stay silent in production, such as wrong data, or
  that would reach many users at once.
