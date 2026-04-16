# working_router

A Flutter router built around a typed route tree and a DSL-style route
definition API.

## Core Ideas

- `Location<ID, Self>` is a semantic route node.
- `Shell<ID>` is a directly constructible structural route node that inserts a nested navigator.
- `MultiShell<ID>` is the parallel-shell variant for layouts with multiple sibling nested navigators.
- Routes are defined in `build(...)` with ordered builder calls:
  - `pathLiteral(...)`
  - `pathParam(...)`
  - `queryParam(...)`
- The same `build(...)` method also decides whether the location is:
  - legacy when no render is configured, so `buildRootPages` handles it
  - self-built via `builder.content = ...`, with an optional page override from `builder.page = ...`
  - and returns the child `RouteNode`s as a list
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

## Defining Nodes

The route API is centered around lightweight route-node subclasses that forward a
typed `build:` callback.

```dart
class ExampleNode extends Location<MyRouteId, ExampleNode> {
  ExampleNode({
    super.id,
    super.build,
  });
}

final example = ExampleNode(
  id: MyRouteId.example,
  build: (builder, location) {
    builder.pathLiteral('items');
    final itemId = builder.stringPathParam();
    final filter = builder.stringQueryParam(
      'filter',
      defaultValue: Default('all'),
    );

    builder.content = Content.builder((context, data) {
      return Text(
        '${data.param(itemId)}:${data.param(filter)}',
      );
    });

    builder.children = [
      DetailNode(id: MyRouteId.detail),
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
- For nullable query params with a default `null`, use the nullable shortcuts
  like `nullableStringQueryParam('filter')`,
  `nullableBoolQueryParam('enabled')`, or
  `nullableDateTimeQueryParam('endDateTime')`.
  Those nullable shortcuts always default to `null` and do not accept a custom
  default value.
- Path parameters are intentionally non-nullable. They represent matched URI
  segments, so a missing value means the route does not match rather than
  producing `null`. Use query parameters for optional values.
- Child routes are assigned with `builder.children = [...]`.
- Use `Location(...)`, `Scope(...)`, `Shell(...)`, `ShellLocation(...)`,
  `MultiShell(...)`, and `MultiShellLocation(...)` for callback-based route
  definitions, or subclass `AbstractLocation`, `AbstractScope`,
  `AbstractShell`, `AbstractShellLocation`, `AbstractMultiShell`, and
  `AbstractMultiShellLocation` to override `build(...)` directly.
- Page keys can be configured with `builder.pageKey = ...`, using
  `PageKey.templatePath()`, `PageKey.path()`, or `PageKey.custom(...)`.
- `builder.content = Content.widget(...)` is the constant-widget variant.
- `builder.content = Content.builder(...)` is the data-aware variant.
- `builder.content = const Content.none()` creates a semantic non-rendering
  location that can still be terminal.
- `builder.page = ...` only overrides the default page wrapper around rendered
  content.
- For rare cross-cutting cases, define reusable unbound params with
  `UnboundPathParam` / `UnboundQueryParam`, bind them with
  `builder.bindParam(...)`, read the bound `Param` with `data.param(...)`, and
  read the reusable unbound definition with `data.paramOrNull(...)`.
- `WorkingRouterData` exposes the full matched chain as `data.routeNodes`.
  Use `data.leaf` when you specifically need the active semantic
  location.
- `content` and `defaultContent` may depend on `context` and `data`, but they
  should not switch semantic page role based on other external mutable state.
- If `content` is left entirely unset, the location is treated as legacy and
  resolved through `buildRootPages`.

Reusable unbound params are mainly useful when outer code needs nullable access
to a route param without owning the location that declares it:

```dart
final accountId = UnboundPathParam<AccountId>(const AccountIdCodec());

Location<RouteId, AccountsNode>(
  build: (builder, location) {
    builder.pathLiteral('accounts');
    final boundAccountId = builder.bindParam(accountId);
    builder.children = [
      DashboardNode(
        build: (builder, location) {
          builder.content = Content.builder((context, data) {
            return Text(data.param(boundAccountId).toString());
          });
        },
      ),
    ];
  },
);

// Somewhere outer in the widget tree:
final activeAccountId = data.paramOrNull(accountId);
```

See:
- [`example/lib/app_routes.dart`](example/lib/app_routes.dart)
- [`example/lib/locations.dart`](example/lib/locations.dart)

## Scope Vs Shell Vs ShellLocation

Use a `Scope` when you want a shared route scope without rendering anything.
A scope:
- can define shared path and query parameters
- can hold child locations
- does not build a page
- does not create a nested navigator

Typical use case:
- multiple legal pages share the same `languageCode` query parameter
- a subtree shares a path prefix but has no shared UI wrapper

Use a `Shell` when the subtree needs its own visible wrapper and nested
navigator boundary. A shell:
- can define shared path and query parameters
- can hold child locations
- does build a wrapper widget/page
- does create a nested navigator for its child subtree
- may define `defaultContent` / `defaultPage` for that implicit nested slot

If no later matched descendant is actually assigned to the shell's
`routerKey`, the shell does not contribute a page for that match and behaves
like a `Scope` instead. This lets you keep a shell in the tree for shared
path/query scope while routing descendants to an ancestor navigator on smaller
layouts. When `defaultContent` is configured, that default page becomes the
root page of the shell navigator and keeps the shell renderable even if the
matched descendants are all routed elsewhere.

You can also disable the shell navigator explicitly with
`navigatorEnabled: false`. In that mode the shell stays in the tree for
path/query structure, but descendants inherit the shell parent navigator
automatically. Explicit `parentRouterKey: routerKey` references are also
aliased back to that parent navigator, so responsive shells do not require
rewriting every child.

Typical use case:
- a sidebar or tab layout that stays visible while child routes change
- an account area like `/accounts/:id/...` where children render inside a
  common scaffold

Use a `ShellLocation` when that nested navigator boundary belongs to exactly
one semantic location instead of a shell plus one child location. A shell
location:
- has an `id` like a normal location
- defines its own path, query params, widget, and page
- also defines an outer shell wrapper/page on the parent navigator
- creates a nested navigator for its child subtree
- may define `defaultContent` / `defaultPage` for that implicit nested slot
- can disable that nested navigator with `navigatorEnabled: false`

Typical use case:
- a `/settings` route that opens in a modal shell and then renders nested
  `/settings/theme-mode` pages inside that modal
- a flow root that needs both a semantic location id and an outer container
  page without introducing an extra `Shell -> Location` nesting level

Use a `MultiShell` when one wrapper needs multiple sibling nested navigators,
such as a split view with independent left and right stacks. Use a
`MultiShellLocation` when that split shell is also a semantic location with an
`id` and an inner location page. Extra multi-shell slots may define default
content and page wrappers. If an enabled slot has neither routed content nor
default content, the router throws instead of silently leaving that pane
empty. A slot's default page stays in the same navigator and acts as that
slot's root page beneath deeper routed pages.

## Callback Vs Abstract Types

Use the callback-based types when defining a tree inline:

```dart
Scope(
  build: (builder, scope) {
    builder.children = [
      PrivacyNode(id: RouteId.privacy, build: ...),
    ];
  },
);

Shell(
  build: (builder, shell, routerKey) {
    builder.content = ShellContent.builder(
      (context, data, child) => Scaffold(body: child),
    );
    builder.defaultContent = DefaultContent.widget(const Placeholder());
    builder.children = [
      DashboardNode(id: RouteId.dashboard, build: ...),
    ];
  },
);

MultiShell(
  build: (builder, shell) {
    final listSlot = builder.slot(
      defaultContent: DefaultContent.widget(const ChannelListScreen()),
    );
    final detailSlot = builder.slot();
    builder.content = MultiShellContent.builder(
      (context, data, slots) => Row(
        children: [
          Expanded(child: slots.child(listSlot)),
          Expanded(child: slots.child(detailSlot)),
        ],
      ),
    );
    builder.children = [
      SearchNode(parentRouterKey: listSlot.routerKey, build: ...),
      DetailNode(
        id: RouteId.detail,
        parentRouterKey: detailSlot.routerKey,
        build: ...,
      ),
    ];
  },
);

ShellLocation<RouteId, SettingsNode>(
  id: RouteId.settings,
  build: (builder, location, routerKey) {
    builder.shellPage = (key, child) =>
        MaterialPage(key: key, child: child);
    builder.content = Content.widget(const SettingsScreen());
    builder.children = [
      ThemeModeNode(id: RouteId.themeMode, build: ...),
    ];
  },
);
```

Use the abstract base classes when you want a reusable named subtree by
overriding `build(...)`:

```dart
class LegalNode extends AbstractScope<RouteId> {
  @override
  void build(ScopeBuilder<RouteId> builder) {
    builder.children = [
      PrivacyNode(id: RouteId.privacy, build: ...),
      TermsNode(id: RouteId.terms, build: ...),
    ];
  }
}

class AccountNode extends AbstractShell<RouteId> {
  @override
  void build(ShellBuilder<RouteId> builder) {
    builder.content = ShellContent.builder(
      (context, data, child) => Scaffold(body: child),
    );
    builder.children = [
      DashboardNode(id: RouteId.dashboard, build: ...),
    ];
  }
}

class ChatSplitNode extends AbstractMultiShell<RouteId> {
  @override
  void build(MultiShellBuilder<RouteId> builder) {
    final listSlot = builder.slot();
    final detailSlot = builder.slot();
    builder.content = MultiShellContent.builder(
      (context, data, slots) => Row(
        children: [
          Expanded(child: slots.child(listSlot)),
          Expanded(child: slots.child(detailSlot)),
        ],
      ),
    );
    builder.children = [
      SearchNode(parentRouterKey: listSlot.routerKey, build: ...),
      DetailNode(
        id: RouteId.detail,
        parentRouterKey: detailSlot.routerKey,
        build: ...,
      ),
    ];
  }
}

class SettingsNode extends AbstractShellLocation<RouteId, SettingsNode> {
  SettingsNode({required super.id});

  @override
  void build(ShellLocationBuilder<RouteId> builder) {
    builder.content = Content.widget(const SettingsScreen());
    builder.children = [
      ThemeModeNode(id: RouteId.themeMode, build: ...),
    ];
  }
}
```

## Page Keys

By default, pages use `PageKey.templatePath()`.

```dart
builder.pageKey = const PageKey.templatePath();
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
builder.pageKey = const PageKey.path();
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
    builder.content = Content.builder((context, data) {
      return LessonScreen(lessonId: data.param(lessonId));
    });
    builder.pageKey = const PageKey.templatePath();
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
  navigatorEnabled: screenSize != ScreenSize.small,
  build: (builder, shell, routerKey) {
    builder.content = ShellContent.builder((context, data, child) {
      return Scaffold(body: child);
    });

    builder.children = [SomeLocation(id: MyRouteId.some)];
  },
)
```

Shells create their own nested navigator keys internally. When
`navigatorEnabled` is false, the builder still receives that stable shell key,
but routing ownership aliases it back to the shell parent navigator. That
means children can either inherit implicitly or keep using
`parentRouterKey: routerKey` without forcing a second responsive tree.

Nested shell routing is hosted by a stateful `NestedRouting` widget, so the
nested delegate keeps its own navigator key and stack across
`WorkingRouter.refresh()` as long as that shell widget is reused. That is what
makes dynamic route-tree refreshes practical here, because nested navigator
state can survive tree changes that still keep the same shell alive.

This is shown in the package example in
[`example/lib/app_routes.dart`](example/lib/app_routes.dart).

## Defining Shell Locations

`ShellLocation` is the shorthand for the common `Shell + one child Location`
shape:

```dart
ShellLocation<RouteId, SettingsNode>(
  id: RouteId.settings,
  navigatorEnabled: screenSize != ScreenSize.small,
  build: (builder, location, routerKey) {
    builder.pathLiteral('settings');

    builder.shellContent = ShellContent.builder((context, data, child) {
      return Dialog(child: child);
    });

    builder.defaultContent = DefaultContent.widget(const Placeholder());
    builder.content = Content.widget(const SettingsScreen());
    builder.page = (key, child) {
      return MaterialPage(key: key, child: child);
    };

    builder.children = [
      ThemeModeNode(id: RouteId.themeMode, build: ...),
    ];
  },
)
```

Use:
- `content = ...` and `page = ...` for the inner location page rendered inside
  the nested navigator
- `defaultContent = ...` and `defaultPage = ...` for the implicit nested slot
  root page, especially when `content = const Content.none()`
- `shellContent = ...` and `shellPage = ...` for the outer shell wrapper
  rendered on the parent navigator
- `navigatorEnabled: false` when the shell location should collapse down to a
  normal location on smaller layouts while keeping the same tree shape

## Defining Multi Shell Locations

`MultiShellLocation` is the parallel-shell variant for layouts with multiple
sibling slot navigators plus one built-in `contentSlot` for the location's own
page, such as a desktop split view with independent left and right stacks.

```dart
MultiShellLocation<RouteId, ChatLocation>(
  id: RouteId.chat,
  navigatorEnabled: screenSize != ScreenSize.small,
  build: (builder, location, contentSlot) {
    builder.pathLiteral('chat');

    final listSlot = builder.slot(
      defaultContent: DefaultContent.widget(const ChannelListScreen()),
    );

    builder.shellContent = MultiShellContent.builder((
      context,
      data,
      slots,
    ) {
      return ChatScreen(
        leftChild: slots.child(listSlot),
        child: slots.child(contentSlot),
      );
    });

    builder.defaultContent = DefaultContent.widget(
      const EmptyDetailPlaceholder(),
    );
    builder.content = const Content.none();

    builder.children = [
      ChannelListNode(
        id: RouteId.channelList,
        parentRouterKey: listSlot.routerKey,
        build: ...,
      ),
      ChannelDetailNode(
        id: RouteId.channelDetail,
        parentRouterKey: contentSlot.routerKey,
        build: ...,
      ),
    ];
  },
)
```

Use:
- the `contentSlot` build parameter for the location's own page navigator
- `defaultContent = ...` and `defaultPage = ...` for the implicit `contentSlot`
  root page
- `builder.slot()` for extra sibling navigators
- `slot.routerKey` to target any slot from child locations via `parentRouterKey`
- `slots.child(slot)` inside `shellContent` to place each active slot navigator
- `slots.childOrNull(slot)` when a disabled slot should simply be omitted from
  the layout
- `navigatorEnabled: false` to collapse the whole multi-shell back onto the
  parent navigator on smaller layouts while keeping the same route tree

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

For that case, a location simply leaves `builder.content` unset. The route
stays in the tree while page construction still happens in `buildRootPages`.

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
- a `ShellLocation` that removes one nesting level from a `Shell + Location`
  pattern
- lightweight callback-based `Location` wrappers plus an override-based
  `AbstractLocation` example
- direct `Shell(...)` and `ShellLocation(...)` usage with optional
  `AbstractShell` / `AbstractShellLocation` subclassing support
- typed path and query params
- generated `routeToX(...)` helpers
- generated `XRouteTarget(...)` classes
- a custom modal page from `builder.page = ...`

Run it from [`example`](example).
