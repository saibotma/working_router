---
name: links
description:
  Use when mentioning an issue, PR/MR, commit, CI pipeline or job, agent thread,
  document, or other item that has a URL, in a reply to the user, a PR/MR, a
  comment, a commit message, an issue, or another document.
---

# Links

Link every item you mention that has a URL, such as an issue, a PR/MR, a commit,
a CI pipeline or job, an agent thread, or a document, so that readers can open
it directly instead of searching for it.

- Write a Markdown link with the item's usual short name as its text, such as
  `[APL-123](<issue URL>)`, `[#42](<PR URL>)`, `[!42](<MR URL>)`, or
  `[a1b2c3d](<commit URL>)`. Where Markdown does not render, such as in commit
  messages, write the URL itself.
- Link an item at its first mention in each reply or document.
- Take the URL from the tool that returns the item, such as the issue tracker's
  skill, the forge skill, or T3 Code's tools, instead of guessing it.
- Keep links to private items, such as internal issues, private repositories, or
  agent threads, out of public documents, such as the issues and PRs of a public
  repository.
