# working_router

A Flutter router built around a typed route tree and a DSL-style route
definition API.

## Core Ideas

- `Location<ID, Self>` is a semantic route node.
- `Shell<ID>` is a directly constructible structural route node that inserts a nested navigator.
- Routes are defined in `build(...)` with ordered builder calls:
  - `pathLiteral(...)`
  - `pathParam(...)`
  - `queryParam(...)`
- The same `build(...)` method also decides whether the location is:
  - legacy when no render is configured, so `buildRootPages` handles it
  - self-built via `builder.widget(...)` or `builder.widgetBuilder(...)`, with an optional page override from `builder.page(...)`
  - and returns the child `LocationTreeElement`s as a list
- `@Locations()` generates typed `routeToX(...)` helpers and `XRouteTarget`
  classes from one canonical route-tree file.

## Recommended Setup

The generator works best when you keep one canonical route-tree file and let
everything else import it.

1. Create a dedicated route-tree file such as
   [`example/lib/app_routes.dart`](example/lib/app_routes.dart).
2. Put `part 'app_routes.g.dart';` in that file.
3. Annotate the canonical `buildLocations(...)` entrypoint with `@Locations()`.
4. Return the root nodes from that function.
5. Build the router with `buildLocations: (rootRouterKey) => buildLocations(rootRouterKey: rootRouterKey, ...)`.

See:
- [`example/lib/app_routes.dart`](example/lib/app_routes.dart)
- [`example/lib/main.dart`](example/lib/main.dart)

## Defining Locations

The route API is centered around lightweight location subclasses that forward a
typed `build:` callback.

```dart
class ExampleLocation extends Location<MyRouteId, ExampleLocation> {
  ExampleLocation({
    super.id,
    super.build,
  });
}

final example = ExampleLocation(
  id: MyRouteId.example,
  build: (builder, location) {
    builder.pathLiteral('items');
    final itemId = builder.stringPathParam();
    final filter = builder.stringQueryParam(
      'filter',
      defaultValue: Default('all'),
    );

    builder.widgetBuilder((context, data) {
      return Text(
        '${data.pathParam(itemId)}:${data.queryParam(filter)}',
      );
    });

    builder.children = [
      DetailLocation(id: MyRouteId.detail),
    ];
  },
);
```

Important details:

- Path order is defined by call order inside `build(...)`.
- Query parameter names are explicit strings on `queryParam(...)`.
- The builder also exposes typed shortcuts like `stringPathParam()`,
  `intQueryParam('page')`, `intQueryParam('page', defaultValue: Default(1))`,
  `uriPathParam()`, `uriQueryParam('next')`,
  `enumPathParam(MyEnum.values)`, and
  `enumQueryParam('filter', MyEnum.values, defaultValue: Default(MyEnum.all))`.
- Child routes are assigned with `builder.children = [...]`.
- Named `Location` subclasses are the route-authoring model.
- `Shell(...)` stays directly constructible and is not meant to be subclassed.
- Page keys can be configured with `builder.pageKey(...)`, using
  `PageKey.templatePath()`, `PageKey.path()`, or `PageKey.custom(...)`.
- `builder.widget(...)` is the shortcut for constant widgets.
- `builder.widgetBuilder(...)` is the data-aware variant.
- `builder.page(...)` only overrides the default page wrapper around that widget.
- If neither is called, the location is treated as legacy and resolved through
  `buildRootPages`.

See:
- [`example/lib/app_routes.dart`](example/lib/app_routes.dart)
- [`example/lib/locations.dart`](example/lib/locations.dart)

## Page Keys

By default, pages use `PageKey.templatePath()`.

```dart
builder.pageKey(const PageKey.templatePath());
```

This keys a page by its route template, not by hydrated path values. That
means `/lesson/1` and `/lesson/2` reuse the same page identity, while
`/lesson/1/edit` becomes a different page. This is usually the right default
when changing a path parameter should update the existing page instead of
replacing it.

In practice, that means:
- a detail screen can switch from item `1` to item `2` without replacing the
  page
- page-level state tied to that page key stays alive
- nested widgets can still react to the new path parameter and rebuild
- navigating to `/lesson/1/edit` still creates a different page

If the hydrated path value should produce a different page identity, use
`PageKey.path()` instead:

```dart
builder.pageKey(const PageKey.path());
```

This keys by the matched path, so `/lesson/1` and `/lesson/2` become different
pages. Use it when route parameter changes should reset page-level state or
animate like a page replacement.

In practice, that means:
- going from `/lesson/1` to `/lesson/2` behaves like a new page
- page-level state is reset because the page key changes
- page transitions can animate like a replacement instead of an in-place update

Example:

```dart
LessonLocation(
  id: RouteId.lesson,
  build: (builder, location) {
    final lessonId = builder.stringPathParam();
    builder.widgetBuilder((context, data) {
      return LessonScreen(lessonId: data.pathParam(lessonId));
    });
    builder.pageKey(const PageKey.templatePath());
  },
);
```

Use `PageKey.templatePath()` if changing `lessonId` should keep the same page.
Use `PageKey.path()` if changing `lessonId` should replace that page.

For everything else, use `PageKey.custom(...)`.

## Defining Shells

`Shell` stays directly constructible:

```dart
Shell(
  build: (builder, shell, routerKey) {
    builder.widgetBuilder((context, data, child) {
      return Scaffold(body: child);
    });

    builder.children = [
      SomeLocation(id: MyRouteId.some),
    ];
  },
)
```

Shells create their own nested navigator keys internally. If a child should be
rendered on the root navigator instead, thread the `rootRouterKey` from the
top-level `buildLocations(...)` entrypoint into the location that needs it and
pass that value as `parentRouterKey:`.

Nested shell routing is hosted by a stateful `NestedRouting` widget, so the
nested delegate keeps its own navigator key and stack across
`WorkingRouter.refresh()` as long as that shell widget is reused. That is what
makes dynamic route-tree refreshes practical here, because nested navigator
state can survive tree changes that still keep the same shell alive.

This is shown in the package example in
[`example/lib/app_routes.dart`](example/lib/app_routes.dart).

## Generated API

From `@Locations()`, the generator emits:

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

For that case, a location simply does not call `builder.widget(...)` or
`builder.widgetBuilder(...)`. The route stays in the tree while page
construction still happens in `buildRootPages`.

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
- a responsive route tree where small screens stack on top of `/a` while
  medium/large screens keep the alphabet sidebar visible in a shell
- lightweight `Location` subclasses with forwarded `build:` callbacks
- direct `Shell(...)` usage
- typed path and query params
- generated `routeToX(...)` helpers
- generated `XRouteTarget(...)` classes
- a custom modal page from `builder.page(...)`

Run it from [`example`](example).
