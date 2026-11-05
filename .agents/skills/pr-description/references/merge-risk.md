# Merge Risk Rules

The merge risk script, [`scripts/merge-risk.mjs`](../scripts/merge-risk.mjs),
reports the changed files that always need a human code review, and
`pr-description` sorts them under 🔴 Review in `Script`. Each project lists
those files in a top-level `.merge-risk` file.

## Running the Script

Run it from the repository root:

```sh
pnpm exec node .agents/skills/pr-description/scripts/merge-risk.mjs --base origin/<target branch>
```

- It compares `--head`, `HEAD` by default, with its merge base with `--base`,
  `origin/main` by default, and reports both paths of a moved file. `--json`
  prints the result as JSON.
- It reads `.merge-risk` from the working directory, so a checkout of another
  revision than `--head` applies that checkout's rules.
- It always reports a changed `.merge-risk` under `merge risk policy`, so no PR
  weakens the rules without a human.
- Without `.merge-risk`, it says so and reports only a changed `.merge-risk`.
- With `.merge-risk`, it needs the
  [`ignore`](https://www.npmjs.com/package/ignore) package as a pinned dev
  dependency of the project, and names it when it is missing. It does not use an
  `ignore` that pnpm only installs for another package, such as `remark-cli`.

## Format

`.merge-risk` uses gitignore syntax and adds categories:

- A line in brackets, such as `[billing]`, starts the section of a category.
  Every pattern belongs to a section. Write a pattern that is only a bracket
  expression, such as `[ab]`, as `**/[ab]`.
- Patterns match repository-relative paths, case-sensitively. A pattern that
  starts with `/` or contains a `/` before its end matches from the repository
  root; any other pattern matches a name at any depth. A trailing `/` matches a
  directory and everything in it, and `**` matches any number of directories.
- A pattern starting with `!` exempts files from its own category only. As in
  gitignore, it cannot exempt a file inside a directory that the category
  matches.
- `#` starts a comment. Use comments to explain what a category covers and why
  some files are left out.
- A file that matches several categories is listed under each.

The script fails for a pattern before the first category, for an empty or
repeated category, and for a category without patterns.

## Choosing Rules

List only clearly delimited areas: dedicated directories and file types whose
purpose is unambiguous, such as migrations, the authentication core, CI and
deployment configuration, and dependency manifests. Whether ordinary code checks
permissions, separates tenants, changes the API surface, or needs a human to try
it is a property of its content, not its path, so the author judges it from the
diff. Do not add patterns that guess a file's purpose from words in its name;
they never become complete and only blur what the script guarantees. Leave out
files that change with every feature, such as a route registry, and generated
lockfiles.

## Example

```gitignore
# Changes to these files always need a human code review. The merge risk
# script of the pr-description skill reports them by category.

[database schema or migration]
/db/schema.sql
/db/migrations/

[authentication core]
# The sign-in setup and the client adapter that stores and refreshes its
# tokens. Code that only checks the signed-in user lives elsewhere.
/server/auth/
/app/lib/auth/

[agent instructions or skills]
/.agents/
/.claude/
/.codex/
/.mcp.json
AGENTS.md

[CI, deployment, or configuration]
.gitlab-ci.yml
.env*
Dockerfile*
*.sh
# Resources also hold email templates and fonts, so only the configuration
# file types count.
/server/resources/**/*.json
/server/resources/**/*.properties
# Test data is not configuration.
!/server/resources/**/fixtures/**

[dependencies or shared libraries]
package.json
pubspec.yaml
/packages/
```

## Testing the Rules

Test that the rules report what they should with the project's other tests.
Matching needs no git, so these tests run in any test step. Like the script,
`readRules` reads `.merge-risk`, and the module loads `ignore`, from the working
directory, so run them from the repository root:

```js
import assert from "node:assert/strict";
import { test } from "node:test";
import {
  classifyChangedFiles,
  readRules,
} from "../.agents/skills/pr-description/scripts/merge-risk.mjs";

const rules = readRules();

test("migrations need a human code review", () => {
  assert.deepEqual(
    classifyChangedFiles(["db/migrations/0042_orders.sql"], rules).critical,
    [
      {
        category: "database schema or migration",
        files: ["db/migrations/0042_orders.sql"],
      },
    ],
  );
});

test("returns a green floor when only feature code changes", () => {
  assert.equal(
    classifyChangedFiles(["app/lib/orders/order_view.dart"], rules).floor,
    "green",
  );
});
```
