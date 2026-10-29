#!/usr/bin/env node
// Verifies that the skills installed with `npx skills` still match the hashes
// recorded in `skills-lock.json`.
//
// Installed skills are managed copies of a shared source repository. `npx
// skills update` keeps local edits until the next upstream change and then
// overwrites them silently, so local edits must fail early instead. Run this
// from the repository root, for example in CI.
//
// TODO(saibotma): Remove once https://github.com/vercel-labs/skills/issues/500 is fixed or released. https://linear.app/appella/issue/APL-338

import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import { join, relative, sep } from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

/**
 * Mirrors `computeSkillFolderHash` of the skills CLI: SHA-256 over every file's
 * slash-separated relative path followed by its content, sorted by path,
 * skipping `.git` and `node_modules` directories.
 *
 * The CLI hashes the source skill, but its installer drops `metadata.json`
 * files and `__pycache__`/`__pypackages__` directories, so a skill containing
 * them can never match; the tests in agent-stack reject such files.
 */
export async function computeSkillFolderHash(skillDir) {
  const files = [];
  async function collectFiles(currentDir) {
    const entries = await readdir(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = join(currentDir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === ".git" || entry.name === "node_modules") continue;
        await collectFiles(fullPath);
      } else if (entry.isFile()) {
        files.push({
          relativePath: relative(skillDir, fullPath).split(sep).join("/"),
          content: await readFile(fullPath),
        });
      }
    }
  }
  await collectFiles(skillDir);

  files.sort((a, b) => a.relativePath.localeCompare(b.relativePath));
  const hash = createHash("sha256");
  for (const file of files) {
    hash.update(file.relativePath);
    hash.update(file.content);
  }
  return hash.digest("hex");
}

/**
 * Returns one message per skill in `lock` whose installed copy in `skillsDir`
 * is missing or differs from its recorded hash.
 */
export async function findInstalledSkillProblems(lock, skillsDir) {
  const problems = [];
  for (const [name, entry] of Object.entries(lock.skills ?? {})) {
    let actual;
    try {
      actual = await computeSkillFolderHash(join(skillsDir, name));
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      problems.push(`${name}: missing from ${skillsDir}`);
      continue;
    }
    if (actual !== entry.computedHash) {
      problems.push(`${name}: changed after installation`);
    }
  }
  return problems;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const lock = JSON.parse(await readFile("skills-lock.json", "utf8"));
  const skillsDir = join(".agents", "skills");
  const problems = await findInstalledSkillProblems(lock, skillsDir);
  if (problems.length > 0) {
    console.error(
      [
        "Installed skills do not match skills-lock.json:",
        ...problems.map((problem) => `- ${problem}`),
        "Change shared skills in their source repository and reinstall them with",
        "`npx skills update`; do not edit installed copies.",
      ].join("\n"),
    );
    process.exit(1);
  }
  console.log(
    `${Object.keys(lock.skills ?? {}).length} installed skills match.`,
  );
}
