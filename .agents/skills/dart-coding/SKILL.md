---
name: dart-coding
description:
  Use when writing, changing, or reviewing Dart or Flutter code or
  configuration.
---

# Dart Coding

Before applying this skill, read its skill extension,
`.agents/skill-extensions/dart-coding/SKILL.md`, if it exists. It adds this
project's facts and rules to this skill. If it does not exist, continue without
searching for it.

Rules that name a shared helper, such as a widget, Riverpod extension, or
annotation that Flutter and its packages do not provide, refer to the shared
Flutter foundation. It currently lives in Appella's `app/lib` and is being
extracted into `appella/appella-toolkit`. When a project lacks such a helper,
copy it from there instead of building a different replacement.

Before writing, changing, or reviewing Dart code, read and apply the
[`coding`](../coding/SKILL.md) skill.

## Tooling

- Use `fvm` for Dart and Flutter commands.

## Coding conventions

- Treat a class as a data class when its identity is defined by its properties
  rather than object identity
- Prefer using the pre-made mappable annotations in `lib/shared/mappable` over
  using `@MappableClass()` directly
- When a class is a data class, use `dart_mappable` instead of handwritten `==`,
  `hashCode`, or `toString`; Prefer `@MappableDataClass()` for these classes
- A nullable named parameter without `required` implicitly defaults to `null`.
  The `coding` skill's default-value rule treats it like an explicit `= null`,
  so mark the parameter `required` wherever that rule calls for an explicit
  argument
- Prefer extensions to standalone or private helper functions when the behavior
  conceptually belongs to an existing type and improves call-site readability
- Omit explicit local and callback parameter types when inference makes them
  unnecessary when they only matter in a lower local scope, and only lift them
  when they are genuinely shared across the file
- Prefer Dart dot shorthand when the target type is clear, especially for enum
  values and sealed-class static members/constructors.
- Use block syntax with curly braces `{}` and explicit `return` statement for
  `map`, `where`, and similar collection operations when the callback contains
  object instantiation, multiple statements, or complex expressions; Use arrow
  syntax for single-line operations
- Never catch `Error` types as explained in
  (https://api.flutter.dev/flutter/dart-core/Error-class.html), and always
  specify the exception type when using catch
- Always declare class variables (fields) above the constructor
- Prefer `.waitFirstError` extensions or `.wait` from standard library over
  `Future.wait(Iterable)`; Prefer `.waitFirstError` over `.wait`, because
  `.wait` wraps errors in `ParallelWaitError`, unless this behavior is
  specifically desired
- Avoid force-unwrapping nullable values with the `!` operator. Prefer a direct
  null check first. Use `?.let((it) => ...)` (see `shared/util/let.dart`) or
  save the nullable value to a local variable only when Dart cannot promote the
  original value cleanly, for example because it is a mutable field or promotion
  is lost across control flow

### Comments

- Always respect the Dart max line length (80 characters) when writing comments
