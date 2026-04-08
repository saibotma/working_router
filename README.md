# working_router

A Flutter router built around a typed route tree.

## Core Ideas

- `Location<ID>` is a semantic route node with an optional `id`, path
  segments, optional query parameters, and optional `buildWidget` /
  `buildPage` overrides.
- `Shell<ID>` is a structural node that inserts a nested navigator and wraps
  its matched child content.
- `WorkingRouterData<ID>` gives you typed access to the currently matched
  route chain.
- `@RouteNodes()` generates typed navigation helpers, typed
  route targets, and location metadata mixins.

## Recommended Setup

The generator works best when you keep one canonical route-tree file and let
everything else import it.

1. Create a dedicated route-tree file such as
   [`example/lib/app_routes.dart`](example/lib/app_routes.dart).
2. Put `part 'app_routes.g.dart';` in that file.
3. Annotate the canonical `buildRouteNodes` entrypoint with
   `@RouteNodes()`.
4. Return a top-level `List<RouteNode<ID>>` from that entrypoint.
5. Build the router with `buildRouteNodes: buildRouteNodes`.
6. In location files that declare query-parameter fields, mix in the generated
   public `XLocationGenerated` mixin from the route-tree library.

See:
- [`example/lib/app_routes.dart`](example/lib/app_routes.dart)
- [`example/lib/locations/abc_location.dart`](example/lib/locations/abc_location.dart)
- [`example/lib/locations/alphabet_shell.dart`](example/lib/locations/alphabet_shell.dart)
- [`example/lib/main.dart`](example/lib/main.dart)

## Defining Parameters

Path parameters should be declared as fields and then referenced from `path`:

- `final idParameter = pathParam(const StringRouteParamCodec());`

Query parameters can either be declared manually in `queryParameters`, or
preferably as fields:

- `final b = queryParam(const StringRouteParamCodec());`
- `final c = queryParam(const StringRouteParamCodec());`

When you use query-parameter fields, mix in the generated `XLocationGenerated`
mixin so those field names become the runtime query parameter keys.

## Generated API

From the annotated route tree, the generator currently emits:

- `routeToX(...)` helpers on `WorkingRouterSailor`
- `XRouteTarget(...)` classes for typed imperative navigation and redirects
- `XLocationGenerated` mixins for field-based query-parameter metadata

That means you can navigate either with the generated helper:

- `router.routeToAbc(idParameter: 'test', b: 'bee', c: 'see')`

or with the generated target directly:

- `router.routeTo(AbcRouteTarget(idParameter: 'test', b: 'bee', c: 'see'))`

Redirects can use the same typed targets:

- `return RedirectTransition(AbcRouteTarget(...));`

## Building Pages

The current recommended style is location-owned page building:

- override `buildsOwnPage => true`
- implement `buildWidget(...)`
- optionally override `buildPage(...)` for a custom `Page`

See:
- [`example/lib/locations/splash_location.dart`](example/lib/locations/splash_location.dart)
- [`example/lib/locations/ab_location.dart`](example/lib/locations/ab_location.dart)
- [`example/lib/locations/abc_location.dart`](example/lib/locations/abc_location.dart)
- [`example/lib/locations/adc_location.dart`](example/lib/locations/adc_location.dart)

The legacy `buildRootPages` / skeleton flow still exists for incremental
migration, but the main example no longer uses it.

## Running The Generator

Add `build_runner` to your app's `dev_dependencies`, then run:

```sh
flutter pub run build_runner build --delete-conflicting-outputs
```

Or during development:

```sh
flutter pub run build_runner watch --delete-conflicting-outputs
```

## Example

The package example demonstrates:

- the old splash -> a -> ab/abc and ad/adc route flow on the new API
- top-level sibling routes without a dummy root shell
- a shell-wrapped `/a...` subtree
- self-built locations
- field-based path and query params
- generated query-parameter mixins
- generated `routeToX(...)` helpers
- generated `XRouteTarget(...)` classes
- a custom modal page built from `buildPage(...)`

Run it from [`example`](example).
