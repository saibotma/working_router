---
name: github-issue-writing
description:
  Use when drafting or refining GitHub issues with verified claims, minimal
  examples, and natural wording.
---

- First decide what kind of issue this is: bug report, feature request, API
  design request, documentation request, or a mixed case. Keep the issue
  centered on one primary ask.
- Verify behavior claims before writing them into the issue. If the issue
  contains code examples or reproduction steps, run them or test equivalent
  cases locally and only claim what was actually reproduced.
- Keep the core claim narrow and the issue to the point. Separate the exact
  verified problem from broader related context, do not overstate what the issue
  proves, and remove repeated framing, taxonomies, meta-commentary, and optional
  sections that do not help the maintainer understand the problem or request.
- Minimize examples aggressively. Use the smallest generic example that still
  demonstrates the point. Prefer generic names over app-specific names unless
  the issue is intentionally app-specific.
- Do not include internal reduction history in the issue body. Omit phrases like
  "extra application-specific logic", "we reduced this from...", or similar
  process notes unless that history is essential for maintainers.
- If there is a low-level workaround and a missing first-class API, distinguish
  them clearly. Do not write "the only way" when a manual workaround exists.
  Instead say "the only built-in high-level API" or equivalent.
- When proposing solutions, separate the preferred direction from alternative
  ideas. If both are plausible, say so explicitly instead of forcing false
  certainty.
- If the topic is subtle or the causal chain is not fully certain, say that
  briefly and directly. A short disclaimer is better than sounding
  overconfident.
- Keep markdown natural. Do not hard-wrap paragraphs or add manual line breaks
  just to control width. Let Markdown and the renderer wrap prose naturally, and
  use extra newlines only for real paragraph, section, list, or code-block
  structure.
- Avoid LLM-sounding structure and phrasing. Prefer simple section titles.
- By default, write issue bodies and issue comments in first-person singular
  (`I`), not `we`, unless the user explicitly wants a team voice.
- Avoid decorative emphasis just for contrast.
- In related-context lists, prefer plain URLs only. Do not add mini issue
  summaries unless they are actually needed.
- In prose, use links naturally when helpful, but keep them sparse. One natural
  inline link is usually better than multiple sentence-level link explanations.
- Before finalizing, do one cleanup pass focused only on issue quality:
  - remove claims that were not actually verified
  - remove unrelated related-context links
  - remove wording that sounds like a changelog, postmortem, or internal
    discussion
  - make sure the requested change is obvious after one read
