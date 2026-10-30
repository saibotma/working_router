---
name: testing
description:
  Use when handling tests, including writing tests, updating tests, deciding
  test scope, and choosing test helpers.
---

## General

- If you cannot make a required test pass and have no clear path forward, ask
  the user how to proceed.
- To avoid flaky tests, do not make test outcomes depend on execution speed or
  short wall-clock windows. Inject controllable clocks and schedulers and
  advance them explicitly; use deterministic synchronization instead of sleeps
  or assuming operations finish before a timeout.
- Keep test fixtures aligned with production invariants. Do not add production
  fallbacks for impossible test-only states; fix the test setup instead.
- When adding a new test file or standalone test entry point, make sure it is
  executed by the repository's automated validation path, including the relevant
  CI or pipeline stage. If it is intentionally local-only, call that out and
  explain why.
- Test every new or changed non-private function, method, getter, setter, and
  command directly when reasonably possible, including module-internal and
  top-level functions. Coverage through a caller, such as an endpoint, does not
  replace a direct test; keep caller tests for the caller's own contract.
- For changed behavior, identify which test setup and assertion would fail if
  that behavior were missing. A test’s name or execution of the changed method
  is not sufficient evidence.
- Test only current product and correctness contracts, independently of branch
  history. Do not add or retain a test solely because branch-local, obsolete, or
  discarded behavior was removed; removal alone is not a contract that the
  behavior must remain absent. Assert absence only when it is itself a current
  requirement, such as a security or privacy boundary, an explicit payload or
  schema allowlist, a supported compatibility guarantee, or regression coverage
  for a confirmed defect in the target branch or released product.
- When deleting or substantially changing an existing test, compare its previous
  assertions and preserve behavior that remains a current product or correctness
  contract, either in the evolved test or elsewhere.

## Test Organization

- Name test files and classes after the corresponding production file or type,
  following the language's conventions. Use a function-specific name only when
  neither provides a meaningful test subject.
- Group tests by the production method or function under test. Create one named
  group per method or function, even when it contains only one test, and name
  the group after that method or function using the language's naming
  conventions. Omit this group when the test file or class already identifies
  the sole method or function, or covers only a conventional entry point such as
  `invoke`, `call`, `run`, or `execute`.

## Test Names

- Write test names as readable descriptions of the main expected behavior and
  the conditions that explain it. Keep useful detail even when the name becomes
  longer. Name the subject unless the file or enclosing group makes it clear.
- Start with the outcome the caller observes, followed by the conditions that
  explain it: `<outcome> when <conditions>`. Typical outcomes are
  `returns <status or value>`, `throws <error>` or `does not throw`, an effect
  such as `deletes <object>` or `keeps <object>`, and UI states such as `shows`,
  `hides`, or `disables <element>`. Do not start with the actor; describe it in
  the conditions. A name that would stay the same if the expected result were
  reversed is missing its outcome.
- Keep secondary fixtures and checks out of the name. If a test verifies
  independent behaviors, split them into separate tests; multiple assertions
  supporting one behavior can stay together.
- Keep test names at the abstraction level of the behavior under test. Do not
  narrow a general test name merely because a field or assertion was added.
- Describe observable post-merge behavior. Do not refer to branch-local
  intermediate states or discarded approaches. Include historical context only
  when it identifies a confirmed regression in the target branch or released
  product.

| Bad test name                                                                                                         | Good test name                                                                                                                                                              | Reason                                                                                                                                                                                                                                                   |
| --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `the original attached room resolves historical room differences but preserves cancellation differences`              | `allows different base rooms when both room exceptions match the attached base room, but still rejects other incompatible content`                                          | The bad name makes cancellation sound like a special rule, although it is only an example. The good name distinguishes differing base rooms from matching room exceptions and makes clear that other content checks still apply.                         |
| `merges different duration corrections into the original attached base duration across both matching passes`          | `merges lessons with different original durations when both are corrected to the attached lesson's duration`                                                                | The bad name leaves unclear whether the original or corrected durations differ and emphasizes matching passes. The good name says exactly what differs and what must agree: for example, 45→60 and 90→60 minutes can merge into a 60-minute lesson.      |
| `reconnects at base time before a conflicting exception and leaves lessons bound to another existing period detached` | `reconnects the lesson whose original start time matches the occurrence when another lesson has different content and matches only through its teacher-adjusted start time` | The bad name compresses the matching conditions into labels and adds a secondary check about another period. The good name explains why one lesson wins: both fit the same occurrence, their content differs, and only one matches by its original time. |
| `admin who is also office deletes account member with protected role`                                                 | `returns 204 when admin who is also office deletes account member with protected role`                                                                                      | The bad name describes only the scenario, so it reads the same for a test that expects the deletion to be rejected. The good name starts with the observed result.                                                                                       |
