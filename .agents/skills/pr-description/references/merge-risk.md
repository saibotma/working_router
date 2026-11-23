# Merge Risk Rules

The merge risk script, [`scripts/merge-risk.mjs`](../scripts/merge-risk.mjs),
reports the changed files that a project lists in an optional top-level
`.merge-risk` file, and `pr-description` lists them under 🔴 Code owner review,
for the `change-risk` area they back up, `Contracts` or `Dependencies`.
`pr-description` finds the changes in these areas by their content; the file
backs that up for paths where a missed judgement must not drop a change, such as
migrations.

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

List only paths whose every change belongs to the `Contracts` or `Dependencies`
area of `change-risk`, typically database schemas and migrations. Leave out
paths where only some changes need a human, because each listed path turns every
change, even a comment, into a 🔴 code owner entry:

- dependency manifests, which also change for comments, formatting, and
  reordering; `pr-description` judges dependency changes by content;
- CI, deployment, and application configuration, authentication code, shared
  libraries, and agent files, which `pr-description` judges by content;
- API contracts and billing code, which `pr-description` already lists for code
  owner review by content.

Do not add patterns that guess a file's purpose from words in its name, such as
`config/`; they match ordinary code and tests and only blur what the script
guarantees.

## Example

```gitignore
# Every change to these files changes stored data, so it always needs a human
# code review. The merge risk script of the pr-description skill reports them.

[database schema or migration]
/db/schema.sql
/db/migrations/
/app/lib/database/migrations/
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
