---
name: dart-testing
description:
  Use when handling Dart or Flutter tests, including writing tests, updating
  tests, deciding test scope, and choosing test helpers.
---

- For small web-only branches like `isWeb`/`kIsWeb`, prefer injecting the
  platform decision into the code under test instead of trying to run the test
  on Chrome; a good pattern is `@visibleForTesting bool isWeb = isWeb`, then
  cover both branches in normal VM tests
- When a symbol only needs to stay visible so focused tests can call or inspect
  it, prefer marking it with `@visibleForTesting` instead of widening the normal
  public API just for tests

## What not to test

- Do not write tests for temporary demo-only or purely exploratory UI changes
  whose purpose is just to preview a look or animation and that are likely to be
  removed or changed immediately after feedback
