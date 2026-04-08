# working_router

A Flutter router built around a typed route tree and a DSL-style route
definition API.

## Core Ideas

- `Location<ID>` is a semantic route node.
- `Shell<ID>` is a structural route node that inserts a nested navigator.
- Routes are defined in `build(...)` with ordered builder calls:
  - `pathLiteral(...)`
  - `pathParam(...)`
  - `queryParam(...)`
  - `location((builder) { ... })` / `shell((builder) { ... })`
  - `child(...)` for custom route-node subclasses
- The same `build(...)` method also decides whether the location is:
  - legacy via `builder.legacy()` for `buildRootPages`
  - self-built via `builder.buildWidget(...)` or `builder.buildPage(...)`
- `@RouteNodes()` generates typed `routeToX(...)` helpers and `XRouteTarget`
  classes from one canonical route-tree file.

## Recommended Setup

The generator works best when you keep one canonical route-tree file and let
everything else import it.

1. Create a dedicated route-tree file such as
   [`example/lib/app_routes.dart`](example/lib/app_routes.dart).
2. Put `part 'app_routes.g.dart';` in that file.
3. Annotate the canonical `buildRouteNodes(...)` entrypoint with `@RouteNodes()`.
4. Register the root nodes into a `RouteNodesBuilder<ID>`.
5. Build the router with `buildRouteNodes: (builder) { buildRouteNodes(builder, ...); }`.

See:
- [`example/lib/app_routes.dart`](example/lib/app_routes.dart)
- [`example/lib/main.dart`](example/lib/main.dart)

## Defining Locations

The v2 API defines route structure inside `build(...)`.

```dart
class ExampleLocation extends Location<MyRouteId> {
  ExampleLocation({required super.id});

  @override
  void build(LocationBuilder<MyRouteId> builder) {
    builder.pathLiteral('items');
    final itemId = builder.pathParam(const StringRouteParamCodec());
    final filter = builder.queryParam('filter', const StringRouteParamCodec());

    builder.buildPage(
      buildWidget: (context, data) {
        return Text(
          '${data.pathParameter(itemId)}:${data.queryParameterOrNull(filter)}',
        );
      },
    );

    builder.location((builder) {
      builder.id(MyRouteId.detail);
      builder.pathLiteral('detail');
      builder.legacy();
    });
  }
}
```

Important details:

- Path order is defined by call order inside `build(...)`.
- Query parameter names are explicit strings on `queryParam(...)`.
- Inline child routes are usually registered with repeated
  `location((builder) { ... })` or `shell((builder) { ... })` calls, which
  read best at the end of the definition.
- Inline node metadata such as `id(...)`, `tag(...)`, or `navigatorKey(...)`
  is configured inside those nested builders.
- `child(...)` remains the escape hatch for reusable custom `Location` /
  `Shell` subclasses.
- Custom page-key behavior can be registered with `builder.pageKey(...)`.
- `builder.legacy()`, `builder.buildWidget(...)`, and `builder.buildPage(...)`
  decide whether the location is legacy or self-built.

See:
- [`example/lib/app_routes.dart`](example/lib/app_routes.dart)
- [`example/lib/locations/abc_location.dart`](example/lib/locations/abc_location.dart)

## Defining Shells

`Shell` uses the same style:

```dart
Shell<MyRouteId>(
  navigatorKey: shellNavigatorKey,
  build: (builder) {
    builder.buildWidget((context, data, child) {
      return Scaffold(body: child);
    });
    builder.location((builder) {
      builder.id(MyRouteId.some);
      builder.pathLiteral('some');
      builder.legacy();
    });
  },
)
```

This is shown in the package example in
[`example/lib/app_routes.dart`](example/lib/app_routes.dart).

## Generated API

From `@RouteNodes()`, the generator emits:

- `routeToX(...)` helpers on `WorkingRouterSailor`
- `XRouteTarget(...)` classes for typed imperative navigation and redirects

That means you can navigate either with:

```dart
router.routeToAbc(id: 'test', b: 'bee', c: 'see');
```

or:

```dart
router.routeTo(AbcRouteTarget(id: 'test', b: 'bee', c: 'see'));
```

Redirects can use the same targets:

```dart
return RedirectTransition(AbcRouteTarget(id: 'test', b: 'bee', c: 'see'));
```

## Legacy `buildRootPages`

The old `buildRootPages` / skeleton flow still exists for migration.

For that case, a location can return:

```dart
builder.legacy();
```

That keeps the route in the tree while page construction still happens in
`buildRootPages`.

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

- the splash -> a -> ab/abc and ad/adc flow
- mostly direct `Location(...)` / `Shell(...)` usage
- one subclassed `Location` in
  [`example/lib/locations/abc_location.dart`](example/lib/locations/abc_location.dart)
  to show that both styles work
- typed path and query params
- generated `routeToX(...)` helpers
- generated `XRouteTarget(...)` classes
- a custom modal page from `builder.buildPage(...)`

Run it from [`example`](example).
