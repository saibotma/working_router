---
name: coding
description:
  Use when writing, changing, or reviewing code in any language. Language skills
  such as dart-coding and jvm-coding build on it.
---

# Coding

Language-agnostic coding conventions. Language skills add language-specific
conventions on top and do not repeat these.

## Constructor parameters and defaults

- When adding a parameter to the constructor of a data class or model that code
  constructs, make callers supply it explicitly. Do not add a default value,
  including `= null` for nullable parameters. Nullability allows callers to pass
  `null`; it does not justify omitting the argument. Without a default, the
  compiler flags every call site, so each caller decides on the value.
- Add a default only when omitting the argument has a deliberate meaning and
  nearly all callers should use that value. Explain the reason next to the
  default. Keeping existing call sites compiling is not a reason for a default.
- Types that are deserialized, such as request payloads, GraphQL inputs, or
  decoded JSON, are different: their defaults define what an omitted field means
  and are part of the external contract. Decide them as part of that contract,
  and do not remove existing ones merely to apply the rule above, because the
  compiler does not catch the resulting decoding changes.

## Results and errors

- Model expected domain and application outcomes as explicit result values such
  as `null`, `Boolean`, or sealed types. Do not use exceptions to return
  expected business outcomes.
- Reserve exceptions for programming errors and infrastructure or input/output
  failures that should be handled centrally.

## Parameters and naming

- When a function converts a parameter to a concrete collection right away, for
  example with `toList()` or `toSet()`, accept that concrete collection type
  instead. Keep the general type when the conversion is deliberate, such as a
  snapshot, deduplication, or a defensive copy.
- Don't make variable or parameter names longer than the context requires. For
  example, inside `AvatarImage`, a parameter of type `AvatarImageSize` can be
  named `size` instead of `avatarImageSize`, unless the longer name is needed to
  avoid ambiguity.

## Comments

- Keep existing comments when changing, moving, or copying code. Update a
  comment when the change makes it inaccurate, and remove it only when it no
  longer applies.
