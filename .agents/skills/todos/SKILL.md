---
name: todos
description: Use this skill when adding, updating, or deleting todos.
---

- Always create an issue for new todos in the repository's issue tracker,
  following `issues`, and link the issue in the todo.

## Upstream Workarounds

A workaround is code that avoids a bug or gap in a dependency, or that builds
functionality a dependency already provides or arguably should provide. A
dependency is anything the code builds on: a language, framework, library,
package, platform, tool, or external service, whether the repository already
uses it or it is an established option. Every dependency override is a
workaround too, and so are git dependencies, version pins, and patched or
vendored copies of a dependency that serve such a purpose.

Workarounds tend to stay long after upstream fixed the cause, so route them to
an upstream fix. Before committing a workaround:

1. Check whether an existing capability of a dependency makes the custom code
   unnecessary, and whether fixing it upstream, or in a fork the repository
   already maintains, would be better than the workaround.
2. Search the dependency's issue tracker and pull requests for an issue, pull
   request, or feature request that covers the problem.
3. When none exists, draft one following the `github-issue-writing` skill and
   attach the draft as a Markdown file to the workaround's issue. When the
   tracker cannot hold Markdown files, put the draft in a collapsed section at
   the end of the issue's description instead. Do not post it; a human posts it,
   because public issues are outward-facing. Posting it is not a merge
   condition; the PR description lists it under **To-dos**, as the
   `pr-description` skill describes.
4. Mark the workaround with a todo in the comment syntax of its file, including
   dependency manifests:

   ```text
   TODO(<person who requested the change>): Remove once <upstream issue or PR URL> is fixed or released. <issue URL>
   ```

   The issue follows the rule above. When no upstream issue exists yet, write
   "upstream issue pending" instead of the upstream URL; the issue then holds
   the draft. When the file's format has no comments, such as JSON, put the todo
   in the closest file that can hold one, such as a README next to it, and name
   the workaround's file and entry in it.

The `review` skill's `upstream_reviewer` checks this work.
