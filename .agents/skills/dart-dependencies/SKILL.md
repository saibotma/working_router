---
name: dart-dependencies
description:
  Use when adding or updating dependencies in a Dart or Flutter pubspec, or when
  inspecting package source or behavior, especially packages from pub.dev or git
  dependencies in .pub-cache.
---

- Before using a caret constraint (`^`) in `pubspec.yaml`, inspect the package's
  changelog history for consistent SemVer compliance
- Use a caret constraint only when that history shows that breaking changes
  consistently occur at the SemVer-appropriate version boundary
- If the history is missing or unclear, or a release has violated SemVer, do not
  trust the publisher's versioning; Pin the exact version instead
- Before opening dependency source, resolve the exact package version or git ref
  from `pubspec.lock`; Use `pubspec.yaml` only to understand the declared
  dependency, not as proof of the resolved one
- Prefer `.dart_tool/package_config.json` to get the exact local package root
  path that the app currently resolves to
- Open the exact resolved checkout in `.pub-cache`; Never inspect another cached
  revision or latest upstream code just because it looks similar
- If multiple cached revisions exist, do not guess from directory names; derive
  the exact path from `package_config.json` or the resolved lockfile entry
- When the answer depends on package behavior, mention the resolved version or
  git ref you inspected
