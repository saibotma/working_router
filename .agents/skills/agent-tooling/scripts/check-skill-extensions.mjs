#!/usr/bin/env node
// Verifies that agents read a project's skill extensions in
// `.agents/skill-extensions/`.
//
// Agents only read an extension because the shared skill file at the same
// path in `.agents/skills/` tells them to, and only read a shared file because
// an extension they read mentions it. An extension whose skill file was
// renamed, removed, or never installed, or a shared file nothing mentions, is
// therefore silently ignored. Run this from the repository root, for example
// in CI, so both fail instead. Whether links point to existing files is left
// to a Markdown link checker, because finding links needs a Markdown parser.

import { readdir, readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

/** Facts that several extensions link to instead of repeating them. */
const sharedDirectory = "shared";

async function listFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(
    entries.map((entry) => {
      const path = join(directory, entry.name);
      return entry.isDirectory() ? listFiles(path) : [path];
    }),
  );
  return files.flat();
}

const toPosix = (path) => path.split(sep).join("/");

export async function findSkillExtensionProblems(extensionsDir, skillsDir) {
  if (!existsSync(extensionsDir)) return [];

  const problems = [];
  const contents = new Map();
  for (const file of (await listFiles(extensionsDir)).map((f) => resolve(f))) {
    contents.set(file, await readFile(file, "utf8"));
  }
  const extensionPath = (file) => toPosix(relative(extensionsDir, file));
  const isShared = (file) =>
    extensionPath(file).startsWith(`${sharedDirectory}/`);

  for (const file of contents.keys()) {
    if (isShared(file)) continue;
    const path = extensionPath(file);
    const skillFile = join(skillsDir, path);
    if (!existsSync(skillFile)) {
      problems.push(`${path}: no installed skill file at ${skillFile}`);
    } else if (
      !(await readFile(skillFile, "utf8")).includes(
        `.agents/skill-extensions/${path}`,
      )
    ) {
      problems.push(`${path}: ${skillFile} does not read this extension`);
    }
  }

  // A shared file counts as read when an extension, or a shared file that is
  // read, mentions its path relative to that file, as a link does.
  const shared = [...contents.keys()].filter(isShared);
  const reached = new Set();
  const pending = [...contents.keys()].filter((file) => !isShared(file));
  while (pending.length > 0) {
    const file = pending.pop();
    for (const target of shared) {
      const mention = toPosix(relative(dirname(file), target));
      if (!reached.has(target) && contents.get(file).includes(mention)) {
        reached.add(target);
        pending.push(target);
      }
    }
  }
  for (const file of shared) {
    if (!reached.has(file)) {
      problems.push(`${extensionPath(file)}: no extension mentions it`);
    }
  }
  return problems;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const problems = await findSkillExtensionProblems(
    join(".agents", "skill-extensions"),
    join(".agents", "skills"),
  );
  if (problems.length > 0) {
    console.error(
      [
        "Skill extensions are broken:",
        ...problems.map((problem) => `- ${problem}`),
      ].join("\n"),
    );
    process.exit(1);
  }
  console.log("Skill extensions are valid.");
}
