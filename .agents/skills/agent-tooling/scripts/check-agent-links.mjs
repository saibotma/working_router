#!/usr/bin/env node
// Verifies that the links in a project's agent files, its `AGENTS.md` files
// and everything in `.agents/`, point to existing files and headings.
//
// Agent files link to skills, references, and extensions that move or
// disappear, and agents silently skip a link that leads nowhere. Run this from
// the repository root, for example in CI, so such links fail instead. It runs
// the project's `remark` with `remark-validate-links`, which the project pins
// as dev dependencies.
//
// The plugin calls git to find the repository URL and root unless it gets a
// repository, so it fails in CI images without git, such as
// `ghcr.io/pnpm/pnpm`. It needs the URL to check full URLs into the repository
// and, on GitHub, links starting with `/`, and on GitHub and GitLab it accepts
// line anchors such as `#L12` and `#readme`. Agent files use none of these, so
// this passes `repository: false` and the working directory is the root; such
// anchors then fail as missing headings.

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import process from "node:process";

// The project's dev dependencies that the check runs.
const remarkCli = join("node_modules", "remark-cli", "cli.js");
const validateLinks = join("node_modules", "remark-validate-links");

const missing = [
  [remarkCli, "remark-cli"],
  [validateLinks, "remark-validate-links"],
]
  .filter(([path]) => !existsSync(path))
  .map(([, name]) => name);
if (missing.length > 0) {
  console.error(
    [
      "Cannot check the links in agent files; missing dev dependencies:",
      ...missing.map((name) => `- ${name}`),
      "Add them to package.json as pinned dev dependencies and install them.",
    ].join("\n"),
  );
  process.exit(1);
}

// An argument array instead of a shell command needs no quoting, so the check
// runs the same on Windows. `remark` expands the glob itself and treats the
// files it finds as given, so it would check the `AGENTS.md` files that
// packages ship in `node_modules` unless they are silently ignored.
const result = spawnSync(
  process.execPath,
  [
    remarkCli,
    "--use",
    "remark-validate-links=repository:false",
    "--ignore-pattern",
    "node_modules",
    "--silently-ignore",
    "--frail",
    "--quiet",
    "--no-stdout",
    "**/AGENTS.md",
    ".agents",
  ],
  { stdio: "inherit" },
);
if (result.error) throw result.error;
if (result.status !== 0) process.exit(1);
console.log("Links in agent files are valid.");
