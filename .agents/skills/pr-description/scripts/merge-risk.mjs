#!/usr/bin/env node
// Reports the changed files that always need a human code review.
//
// The PR author runs this as a deterministic floor: when the script reports a
// file, the change is 🔴 Red, and no agent can argue it lower. The project
// states which files count in a top-level `.merge-risk` file in gitignore
// syntax, with a `[category]` line starting each section; the script reads it
// from the working directory, so run it from the repository root. A changed
// `.merge-risk` always counts, so no PR can weaken the rules without a human.
//
// Matching uses the `ignore` package, which the project pins as a dev
// dependency, and needs no git, so projects can test their rules with
// `readRules` and `classifyChangedFiles`. Only finding the changed files calls
// git.

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { join } from "node:path";
import process from "node:process";

const rulesFile = ".merge-risk";

/** The category of the rules file, which always needs a human. */
const policyCategory = "merge risk policy";

// The project's dev dependency that matches the rules. It has to be the
// project's own pinned one: `pnpm exec` also finds the packages that pnpm
// hoists for other packages, such as an older `ignore` of `remark-cli`. A
// project without `.merge-risk` needs no `ignore` to learn that it has no
// rules, so a missing one only fails once rules need matching.
const ignore = existsSync(join("node_modules", "ignore"))
  ? createRequire(join(process.cwd(), "package.json"))("ignore")
  : undefined;

function createMatcher() {
  if (!ignore) {
    throw new Error(
      [
        "Cannot check the merge risk; missing dev dependency:",
        "- ignore",
        "Add it to package.json as a pinned dev dependency and install it.",
      ].join("\n"),
    );
  }
  // Git matches case-sensitively by default, and so do the rules, on every
  // platform.
  return ignore({ ignorecase: false });
}

/**
 * Parses the rules of a `.merge-risk` file into one `{ category, patterns }`
 * per section, in file order. A line in brackets starts a section; the other
 * lines are gitignore lines, including comments and `!` negations, which apply
 * within their section. Throws for lines that belong to no section, and for
 * empty or repeated sections.
 */
export function parseRules(text, source = rulesFile) {
  const sections = [];
  const fail = (index, problem) => {
    throw new Error(`${source}:${index + 1}: ${problem}`);
  };
  text.split(/\r?\n/).forEach((line, index) => {
    const header = /^\[(.*)\]$/.exec(line.trimEnd());
    if (header) {
      const category = header[1].trim();
      if (!category) fail(index, "empty category");
      if (sections.some((section) => section.category === category)) {
        fail(index, `category "${category}" appears twice`);
      }
      sections.push({ category, patterns: [], index });
    } else if (line.trim() && !line.startsWith("#")) {
      if (sections.length === 0) {
        fail(index, "pattern before the first [category]");
      }
      sections.at(-1).patterns.push(line);
    }
  });
  return sections.map(({ category, patterns, index }) => {
    if (patterns.length === 0) {
      fail(index, `category "${category}" has no patterns`);
    }
    return { category, patterns };
  });
}

/** Reads and parses a project's rules file. */
export function readRules(file = rulesFile) {
  return parseRules(readFileSync(file, "utf8"), file);
}

/**
 * Classifies a set of changed repository-relative paths by the given rules and
 * the rule that `.merge-risk` itself always needs a human.
 */
export function classifyChangedFiles(paths, rules) {
  const matchers = [
    { category: policyCategory, matches: (path) => path === rulesFile },
    ...rules.map(({ category, patterns }) => {
      const matcher = createMatcher().add(patterns);
      return { category, matches: (path) => matcher.ignores(path) };
    }),
  ];
  const groups = new Map();
  for (const path of paths) {
    const categories = new Set(
      matchers
        .filter(({ matches }) => matches(path))
        .map(({ category }) => category),
    );
    for (const category of categories) {
      groups.set(category, [...(groups.get(category) ?? []), path]);
    }
  }
  const critical = [...groups].map(([category, files]) => ({
    category,
    files,
  }));
  return { floor: critical.length > 0 ? "red" : "green", critical };
}

export function formatResult(result) {
  if (result.floor === "green") {
    return "Merge risk floor: 🟢 Green (no critical files)";
  }
  const lines = ["Merge risk floor: 🔴 Red", "", "Needs human code review:"];
  for (const { category, files } of result.critical) {
    lines.push(`- ${category}:`, ...files.map((file) => `  - ${file}`));
  }
  return lines.join("\n");
}

function changedFiles(base, head) {
  // Without rename detection, a moved file reports both its old and its new
  // path, so moving a file out of a critical directory is still caught.
  // NUL-separated output keeps paths verbatim; otherwise Git quotes unusual
  // characters and the quoted path no longer matches the rules.
  const output = execFileSync(
    "git",
    ["diff", "--name-only", "--no-renames", "-z", `${base}...${head}`],
    { encoding: "utf8" },
  );
  return output.split("\0").filter(Boolean);
}

function parseArguments(argv) {
  const options = { base: "origin/main", head: "HEAD", json: false };
  for (let index = 0; index < argv.length; index++) {
    const argument = argv[index];
    if (argument === "--json") options.json = true;
    else if (argument === "--base") options.base = argv[++index];
    else if (argument === "--head") options.head = argv[++index];
    else throw new Error(`Unknown argument: ${argument}`);
  }
  return options;
}

if (import.meta.main) {
  const options = parseArguments(process.argv.slice(2));
  // Without rules, only `.merge-risk` itself counts, so a green floor would
  // look like a check that never ran.
  let rules = [];
  if (!existsSync(rulesFile)) {
    console.error(
      `No ${rulesFile} file in the working directory, so no project rules apply and only changes to ${rulesFile} itself count.`,
    );
  } else {
    try {
      rules = readRules();
      createMatcher();
    } catch (error) {
      console.error(error.message);
      process.exit(1);
    }
  }
  const result = classifyChangedFiles(
    changedFiles(options.base, options.head),
    rules,
  );
  console.log(
    options.json ? JSON.stringify(result, null, 2) : formatResult(result),
  );
}
