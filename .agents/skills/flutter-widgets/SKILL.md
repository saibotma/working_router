---
name: flutter-widgets
description: Use when working on Flutter widgets.
---

Rules that name a shared helper, such as a widget, Riverpod extension, or
annotation that Flutter and its packages do not provide, refer to the shared
Flutter foundation. It currently lives in Appella's `app/lib` and is being
extracted into `appella/appella-toolkit`. When a project lacks such a helper,
copy it from there instead of building a different replacement.

## General

- We differentiate between dumb widgets (not connected to state management) and
  views (connected to state management)
- Give each view `X` an appropriate suffix (e.g. `XScreen`, `XModal`, `XDialog`,
  etc.)
- Use `ResourceScaffold` or `AsyncValueScaffold` instead of manually combining
  `ResourceNotFound`, the app scaffold, `ContentLoadingSwitcher`, and
  `ErrorContentPlaceholder`
- Do not use `SizedBox.shrink()` as placeholder content for loading, error, or
  resource-missing states. Prefer a real loading/error/empty UI.
- Never use `_` for widget builder `BuildContext` parameters; always name it
  `context` to avoid accidentally capturing and using an outer context
- For inherited values, prefer the narrowest specific accessor/dependency
  instead of reading the whole inherited object when only one field is needed
  (e.g. `MediaQuery.paddingOf(context)` over `MediaQuery.of(context)` when only
  padding is required)
- Treat `double.infinity` as a likely workaround in widget code; prefer fixing
  the root constraint/layout cause so sizing works without forcing infinity
- Use `PaddingAwareListView` instead of `ListView` unless required
- Use `PaddingAwareCustomScrollView` instead of `CustomScrollView` unless
  required
- Use `PaddingAwareSingleChildScrollView` instead of `SingleChildScrollView`
  unless required
- Use `SectionHeader` widget as the preferred way to set the title of a section
- Prefer `SizedBox` for spacing between children (e.g. above/below in `Column`
  and left/right in `Row`) and in list-like widgets (`ListView`,
  `PaddingAwareListView`, etc.) instead of `Padding` for gaps; use `Padding` for
  insets around content, not for inter-item spacing
- Always use Phosphor icons from the `phosphor_flutter` package; Use regular
  weight by default; Use filled weight for special states like "selected" state
- Wrap screens with `PageStorage` to preserve scroll state and other UI state
  when navigating
- Name widget properties similar to how it is done in native Flutter widgets and
  else prefer consistency with other widgets in this project
- When changing widget trees always re-evaluate if it is now possible to
  simplify the tree or merge multiple widgets into one widget that can do both,
  e.g. `DecoratedBox` + `Padding` into `Container`
- Prefer multi-purpose widgets like `Container` over combining single-purpose
  ones like `DecoratedBox`, `SizedBox`, and `Padding`.
- Prefer lazy construction for optional/default widgets in conditional branches
  so unused fallback UI is not built unnecessarily; use `late final` when the
  fallback is reused, and prefer inlining when the fallback is simple and
  single-use
- Use `callWithErrorDialog` for user actions where runtime failures are expected
  (e.g. network/server errors), not for programming errors

## Loading & Skeleton

- Prefer `ContentLoadingSwitcher` for simple loading/content transitions where
  showing a single loading indicator avoids layout shifts from mixed skeleton
  and hidden-content states
- Create the factory constructors `.skeleton` and `.hydrated` with a private
  constructor for widgets which have both a skeleton and a hydrated state;
  Orient yourself at existing widgets that follow this pattern
- Prefer determining skeleton display per sub-part based on null/available data
  instead of keeping a widget-level `isSkeleton` field; Use
  `Skeleton.whenNullThenLength`/`whenNullThenFallback` to decide per element
