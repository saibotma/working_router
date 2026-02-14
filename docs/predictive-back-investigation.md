# Predictive Back Investigation Snapshot

## Branch
- `predictive-back-snapshot`

## Scope
This snapshot captures the current router refactor state around Android predictive back support and the related example reproductions.

## Current Baseline
- Router delegate uses `onDidRemovePage` and synchronizes router state in a microtask.
- Nested routing is currently the naive/back-to-baseline implementation:
  - Child back button dispatcher always takes priority.
  - No route-awareness gating.
  - No nested predictive transition override workaround.
- Example app includes two comparison routes under `/a/d`:
  - `/a/d/c`: popup-style route (`PlatformModalPage`)
  - `/a/d/p`: material-page control route

## Main Issues Observed
1. Predictive back ownership conflicts with nested navigators.
2. Gesture behavior can be inconsistent (multiple no-op attempts, then unexpected multi-pop).
3. Popup route and material route both showed problematic gesture behavior in some setups.
4. `PopScope(canPop: false)` works as expected with `maybePop`, but gesture paths can still report `didPop=true` depending on setup.
5. `Navigator.pop()` is imperative and can bypass the intended `canPop` gating semantics.

## Findings/Notes
- `onPopInvokedWithResult` is post-attempt; check `didPop` to distinguish blocked vs completed pops.
- `maybePop()` is the safer API for user-triggered back actions when `PopScope` should be respected.
- For Android predictive back, nested navigators require careful back-dispatch and route-visibility coordination.
- A previous mitigation (now removed in this baseline) disabled predictive transitions for hidden nested navigators to reduce gesture stealing.

## External References (GitHub)
- Flutter predictive back umbrella issue: https://github.com/flutter/flutter/issues/132504
- Predictive back + `PopScope` route behavior thread: https://github.com/flutter/flutter/issues/138614
- Framework team guidance (comment on #138614): https://github.com/flutter/flutter/issues/138614#issuecomment-1883705722
- Additional details / follow-up (comment on #138614): https://github.com/flutter/flutter/issues/138614#issuecomment-1909155402
- Nested navigator back dispatch mismatch on Android: https://github.com/flutter/flutter/issues/145159
- Multiple `PopScope` handlers in one route can conflict: https://github.com/flutter/flutter/issues/144074
- `PopScope` iOS gesture caveat when `canPop: false`: https://github.com/flutter/flutter/issues/138624
- `PopScope` callback semantics differ from `WillPopScope` in imperative pop flows: https://github.com/flutter/flutter/issues/163052
- go_router root-screen back handling (`PopScope`/`WillPopScope`) issue: https://github.com/flutter/flutter/issues/140869
- Black/blank screen reports around `PopScope` + `Navigator.pop`: https://github.com/flutter/flutter/issues/147919

## Follow-up Tasks
1. Decide whether to keep a pure naive baseline or reintroduce a minimal, explicit mitigation.
2. Add deterministic instrumentation around back gesture dispatch path (top route, nested route, and delegate sync events).
3. Validate behavior matrix for:
   - system back button
   - predictive back gesture
   - `maybePop()`
   - `pop()`
   on popup vs material routes and nested vs root navigators.
4. Re-evaluate API guidance for consumers (`PopScope`, sync-only decisions, and route-level back handling expectations).

## Related Files (high impact)
- `lib/src/working_router_delegate.dart`
- `lib/src/widgets/nested_routing.dart`
- `lib/src/working_router.dart`
- `example/lib/main.dart`
- `example/lib/nested_screen.dart`
- `example/lib/location_id.dart`
- `example/lib/locations/adp_location.dart`
