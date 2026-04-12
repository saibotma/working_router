# Changelog

## 0.1.4

- Support wrap assists inside route-tree `if (...) ...[ ... ]` branches.
- Make wrap assist selection more reliable when the cursor is on the
  indentation before an entry such as `Shell(`.
- Update generated `Wrap with Shell` snippets to match shells that now default
  to rendering their child without an explicit `widgetBuilder(...)`.

## 0.1.3

- Update assists for the new `Group` and `Shell` builder callback signatures.
- Keep generated wrap snippets aligned with the current page-key and builder
  APIs.

## 0.1.2

- Add `Remove element` assist for location tree entries.
- Make `Remove element` unwrap a selected entry's children when the selected
  entry has one direct `builder.children = [...]` assignment.
- Disable `Remove element` when the selected entry has ambiguous child
  structure, such as conditional child assignments.
- Keep wrap assists scoped to actual location tree entries.

## 0.1.1

- Fix wrap assists so they only trigger on actual location tree entries.
- Add regression coverage for shell widget builder false positives.

## 0.1.0

- Initial public release.
- Add quick assists to wrap location tree entries with `Group`.
- Add quick assists to wrap location tree entries with `Shell`.
