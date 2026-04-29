# working_router

A Flutter router built around a typed route tree and a DSL-style route
definition API.

## Core Ideas

- `Location<Self>` is the main typed semantic route node API.
- `Location<Self>` is override-based: route-node configuration lives in the
  node class' `build(...)` method.
- `Shell` is a directly constructible structural route node that inserts a nested navigator.
- `MultiShell` is the parallel-shell variant for layouts with multiple sibling nested navigators.
- Routes are defined in `build(...)` with ordered builder calls:
  - `pathLiteral(...)`
  - `pathParam(...)`
  - `queryParam(...)`
- The same `build(...)` method also configures location content, optional page
  wrappers, and child `RouteNode`s.
- `@RouteNodes()` generates typed `routeToX(...)` helpers and `XRouteTarget`
  classes, plus start-anchored `childXTarget(...)` helpers, from one canonical
  route-tree file.

## Recommended Setup

The generator works best when you keep one canonical route-tree file and let
everything else import it.

1. Create a dedicated route-tree file such as
   [`example/lib/route_nodes.dart`](example/lib/route_nodes.dart).
2. Put `part 'route_nodes.g.dart';` in that file.
3. Annotate the canonical `buildRouteNodes(...)` entrypoint with `@RouteNodes()`.
4. Return the root nodes from that function.
5. Build the router with `buildRouteNodes: (rootRouterKey) => buildRouteNodes(rootRouterKey: rootRouterKey, ...)`.

See:
- [`example/lib/route_nodes.dart`](example/lib/route_nodes.dart)
- [`example/lib/main.dart`](example/lib/main.dart)

## Defining Nodes

The route API is centered around lightweight route-node classes. Subclass
`Location<Self>` and put the node's path, params, content, page, and child
configuration inside `build(...)`.

```dart
final detailId = NodeId<DetailNode>();

class ExampleNode extends Location<ExampleNode> {
  ExampleNode({
    super.id,
  });

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('items');
    final itemId = builder.stringPathParam();
    final filter = builder.defaultStringQueryParam(
      'filter',
      defaultValue: 'all',
    );

    builder.content = Content.builder((context, data) {
      return Text(
        '${data.param(itemId)}:${data.param(filter)}',
      );
    });

    builder.children = [
      DetailNode(id: detailId),
    ];
  }
}

class DetailNode extends Location<DetailNode> {
  DetailNode({super.id});

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('detail');
    builder.content = Content.widget(const DetailScreen());
  }
}

final exampleId = NodeId<ExampleNode>();

final example = ExampleNode(
  id: exampleId,
);
```

Important details:

- Path order is defined by call order inside `build(...)`.
- Query parameter names are explicit strings on `queryParam(...)`.
- Each location should declare the path and query parameters it reads. Do not
  hide parameter declarations behind fallback expressions like
  `existingParam ?? builder.stringQueryParam('filter')`; generated helpers
  require builder route declarations to be direct statements or local
  initializers in `build(...)`.
- The builder also exposes typed shortcuts like `stringPathParam()`,
  `intQueryParam('page')`, `defaultIntQueryParam('page',
  defaultValue: 1)`,
  `uriPathParam()`, `uriQueryParam('next')`,
  `enumPathParam(MyEnum.values)`, and
  `defaultEnumQueryParam('filter', MyEnum.values,
  defaultValue: MyEnum.all)`.
- Required query parameters are represented as `RequiredQueryParam<T>`.
  Default-bearing query parameters are represented as `DefaultQueryParam<T>`;
  use `defaultQueryParam(...)` or a typed `default...QueryParam(...)` shortcut
  when a query param has a default.
  Reusable defaults can be declared with `DefaultUnboundQueryParam<T>` and
  bound with `builder.bindDefaultQueryParam(...)`.
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
- Route node classes often fit well next to the screen or feature they render.
- Put node ids next to the composition site that assigns them. If `ParentNode`
  creates `ChildNode(id: childId)`, keep `childId` in the parent/composition
  file. Root ids usually live in the canonical route-tree file that returns the
  root node.
- When descendants need handles declared by the parent, such as params, shell
  router keys, or multi-shell slots, accept
  `ChildrenBuilder<Self> buildChildren` and call it after those handles have
  been assigned.
- Page keys can be configured with `builder.pageKey = ...`, using
  `PageKey.templatePath()`, `PageKey.path()`, or `PageKey.custom(...)`.
- `builder.content = Content.widget(...)` is the constant-widget variant.
- `builder.content = Content.builder(...)` is the data-aware variant.
- `builder.content = const Content.none()` creates a semantic non-rendering
  location that can still be terminal.
- Leaving `content` unset is equivalent to `Content.none()`.
- `builder.page = ...` only overrides the default page wrapper around rendered
  content.
- For rare cross-cutting cases, define reusable unbound params with
  `UnboundPathParam` / `UnboundQueryParam`, bind them with
  `builder.bindParam(...)`, read the bound `Param` with `data.param(...)`, and
  read the reusable unbound definition with `data.paramOrNull(...)`.
- Query values should be read through `data.param(...)` or
  `data.paramOrNull(...)`, not by indexing the raw query parameter map. The
  typed helpers enforce active-route membership and apply codecs/defaults.
- `WorkingRouterData` exposes the full matched chain as `data.routeNodes`.
  Use `data.lastMatched<T>()` when you need the most specific matched node of a
  type, use `data.lastMatchedWithId(someNodeId)` when you want that lookup to
  also return the node as a concrete type from a typed id token, and use
  `data.leaf` / `data.leafWithId(someNodeId)` when you specifically need the
  terminal semantic location.
- `content` and `defaultContent` may depend on `context` and `data`, but they
  should not switch semantic page role based on other external mutable state.

Reusable unbound params are mainly useful when outer code needs nullable access
to a route param without owning the location that declares it:

```dart
final accountId = UnboundPathParam<AccountId>(const AccountIdCodec());

class AccountNode extends Location<AccountNode> {
  final ChildrenBuilder<AccountNode>? buildChildren;
  late final Param<AccountId> boundAccountId;

  AccountNode({this.buildChildren});

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('accounts');
    boundAccountId = builder.bindParam(accountId);
    builder.children = buildChildren?.call(this) ?? const [];
  }
}

final account = AccountNode(
  buildChildren: (account) => [
    DashboardNode(accountId: account.boundAccountId),
  ],
);

// Somewhere outer in the widget tree:
final activeAccountId = data.paramOrNull(accountId);
```

If a route node itself should keep access to a bound param after `build(...)`,
store the returned `Param<T>` on the node instance:

```dart
class AccountNode extends Location<AccountNode> {
  late final Param<AccountId> accountId;

  @override
  void build(ShellBuilder builder) {
    accountId = builder.pathParam(const AccountIdCodec());
    builder.children = [
      DashboardNode(id: RouteId.dashboard, accountId: accountId),
    ];
  }
}
```

This is useful when matched node instances should expose their bound params for
safe reads later.

The generator supports this assignment pattern when producing typed route
helpers.

See:
- [`example/lib/route_nodes.dart`](example/lib/route_nodes.dart)
- [`example/lib/splash_screen.dart`](example/lib/splash_screen.dart)
- [`example/lib/alphabet_sidebar_screen.dart`](example/lib/alphabet_sidebar_screen.dart)

## Scope Vs Shell Vs ShellLocation

Use a `Scope<Self>` when you want a shared route scope without rendering
anything inline. A scope:
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

## Composing Children

Prefer self-contained feature nodes. Put the route node next to the screen it
draws and let that node declare its own route configuration and children in
`build(...)`.

```dart
class AccountNode extends Location<AccountNode> {
  AccountNode({super.id});

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('account');
    builder.content = Content.widget(const AccountScreen());
    builder.children = [
      AccountOverviewNode(),
      AccountSettingsNode(),
    ];
  }
}
```

Use the container node style only when the node intentionally represents a
reusable container whose contents are supplied by its caller. In that case the
node owns an explicit constructor field and assigns it inside `build(...)`:

```dart
class LegalNode extends Scope<LegalNode> {
  final List<RouteNode> children;

  LegalNode({this.children = const []});

  @override
  void build(ScopeBuilder builder) {
    builder.children = children;
  }
}

final legal = LegalNode(
  children: [
    PrivacyNode(id: RouteId.privacy),
    TermsNode(id: RouteId.terms),
  ],
);
```

Use `ChildrenBuilder<Self>` when children need handles that the parent
declares during `build(...)`. Assign the handle to a `late final` field before
calling the child factory:

```dart
class ChatSplitNode extends AbstractMultiShell {
  late final MultiShellSlot listSlot;
  late final MultiShellSlot detailSlot;
  final ChildrenBuilder<ChatSplitNode>? buildChildren;

  ChatSplitNode({this.buildChildren});

  @override
  void build(MultiShellBuilder builder) {
    listSlot = builder.slot(
      defaultContent: DefaultContent.widget(const ChannelListScreen()),
    );
    detailSlot = builder.slot();
    builder.content = MultiShellContent.builder(
      (context, data, slots) => Row(
        children: [
          Expanded(child: slots.child(listSlot)),
          Expanded(child: slots.child(detailSlot)),
        ],
      ),
    );
    builder.children = buildChildren?.call(this) ?? const [];
  }
}

final chat = ChatSplitNode(
  buildChildren: (chat) => [
    SearchNode(parentRouterKey: chat.listSlot.routerKey),
    DetailNode(
      id: RouteId.detail,
      parentRouterKey: chat.detailSlot.routerKey,
    ),
  ],
);
```

`Shell` and `MultiShell` are still directly constructible structural nodes for
inline navigator boundaries:

```dart
Shell(
  build: (builder, shell, routerKey) {
    builder.content = ShellContent.builder(
      (context, data, child) => Scaffold(body: child),
    );
    builder.defaultContent = DefaultContent.widget(const Placeholder());
    builder.children = [
      DashboardNode(id: RouteId.dashboard),
    ];
  },
);
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
class LessonLocation extends Location<LessonLocation> {
  LessonLocation({super.id});

  @override
  void build(LocationBuilder builder) {
    final lessonId = builder.stringPathParam();
    builder.content = Content.builder((context, data) {
      return LessonScreen(lessonId: data.param(lessonId));
    });
    builder.pageKey = const PageKey.templatePath();
  }
}
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

Nested shell routing is hosted by a stateful internal widget, so the nested
delegate keeps its own navigator key and stack across
`WorkingRouter.refresh()` as long as that shell widget is reused. That is what
makes dynamic route-tree refreshes practical here, because nested navigator
state can survive tree changes that still keep the same shell alive.

This is shown in the package example in
[`example/lib/route_nodes.dart`](example/lib/route_nodes.dart).

## Defining Shell Locations

`ShellLocation<Self>` is the shorthand for the common
`Shell + one child Location`
shape:

```dart
class SettingsLocation extends ShellLocation<SettingsLocation> {
  final ScreenSize screenSize;
  final List<RouteNode> children;

  SettingsLocation({
    super.id,
    required this.screenSize,
    this.children = const [],
  }) : super(navigatorEnabled: screenSize != ScreenSize.small);

  @override
  void build(ShellLocationBuilder builder) {
    builder.pathLiteral('settings');

    builder.shellContent = ShellContent.builder((context, data, child) {
      return Dialog(child: child);
    });

    builder.defaultContent = DefaultContent.widget(const Placeholder());
    builder.content = Content.widget(const SettingsScreen());
    builder.page = (key, child) {
      return MaterialPage(key: key, child: child);
    };

    builder.children = children;
  }
}

final settings = SettingsLocation(
  id: RouteId.settings,
  screenSize: screenSize,
  children: [
    ThemeModeNode(id: RouteId.themeMode),
  ],
);
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

`MultiShellLocation<Self>` is the parallel-shell variant for layouts with
multiple sibling slot navigators plus one built-in `contentSlot` for the
location's own page, such as a desktop split view with independent left and
right stacks.

```dart
class ChatLocation extends MultiShellLocation<ChatLocation> {
  late final MultiShellSlot listSlot;
  final ScreenSize screenSize;
  final ChildrenBuilder<ChatLocation>? buildChildren;

  ChatLocation({
    super.id,
    required this.screenSize,
    this.buildChildren,
  }) : super(navigatorEnabled: screenSize != ScreenSize.small);

  @override
  void build(MultiShellLocationBuilder builder) {
    builder.pathLiteral('chat');

    listSlot = builder.slot(
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

    builder.children = buildChildren?.call(this) ?? const [];
  }
}

final chat = ChatLocation(
  id: RouteId.chat,
  screenSize: screenSize,
  buildChildren: (chat) => [
    ChannelListNode(
      id: RouteId.channelList,
      parentRouterKey: chat.listSlot.routerKey,
    ),
    ChannelDetailNode(
      id: RouteId.channelDetail,
      parentRouterKey: chat.contentSlot.routerKey,
    ),
  ],
);
```

Use:
- the `contentSlot` property for the location's own page navigator
- `defaultContent = ...` and `defaultPage = ...` for the implicit `contentSlot`
  root page
- `builder.slot()` for extra sibling navigators
- `slot.routerKey` to target any slot from child locations via `parentRouterKey`
- `slots.child(slot)` inside `shellContent` to place each active slot navigator
- `slots.childOrNull(slot)` when a disabled slot should simply be omitted from
  the layout
- `navigatorEnabled: false` to collapse the whole multi-shell back onto the
  parent navigator on smaller layouts while keeping the same route tree

## Hidden Paths

`builder.pathVisibility = RoutePathVisibility.hidden` hides a matched node's
path segments when the router generates its canonical URI. Descendants inherit
hidden visibility; the default value is `RoutePathVisibility.inherit`, and
there is no explicit visible override. Hidden paths are still accepted when they
are present in an incoming URL; after matching, the router omits them again from
`WorkingRouterData.uri`.

This keeps the current model simple and avoids storing hidden path state in
browser history or native route-information state. It does mean path visibility
is not a security boundary. Do not use hidden paths to protect routes or data;
use normal permission checks and route guards. If this behavior creates a
security or product issue later, the router can move to a typed route-state
model that distinguishes visible URL segments from hidden state during
matching.

## Browser History

`builder.browserHistory = RouteBrowserHistory.replace` keeps the browser URL in
sync without creating a new forward-routable history entry. When the active
route transition enters or leaves a `replace` node, working_router reports the
URI update as `RouteInformationReportingType.neglect`, so the browser replaces
the current history entry instead of pushing a new one.

The default is `RouteBrowserHistory.remember`, which uses normal browser
history behavior. Use `replace` for transient routed UI such as dialog-like
locations or panes that should be reflected in the URL but skipped by browser
back/forward history.

## Query Filters

`builder.queryFilters = [...]` makes a normal route node match only when all
typed default query parameters have their configured values. Create each filter
from the typed query parameter with `someDefaultQueryParam.matches(value)` so
Dart checks that the filter value has the exact query parameter type. This is
useful for pane state such as a chat search view that should appear beside the
currently selected channel.

```dart
class ChatLocation extends MultiShellLocation<ChatLocation> {
  late final DefaultQueryParam<ChatDisplay> chatDisplay;
  late final MultiShellSlot listSlot;
  final ScreenSize screenSize;
  final ChildrenBuilder<ChatLocation>? buildChildren;

  ChatLocation({
    super.id,
    required this.screenSize,
    this.buildChildren,
  }) : super(navigatorEnabled: screenSize != ScreenSize.small);

  @override
  void build(MultiShellLocationBuilder builder) {
    builder.pathLiteral('chat');
    chatDisplay = builder.defaultEnumQueryParam(
      'chatDisplay',
      ChatDisplay.values,
      defaultValue: ChatDisplay.list,
    );

    listSlot = builder.slot(
      defaultContent: DefaultContent.widget(const ChannelListScreen()),
    );

    builder.shellContent = MultiShellContent.builder(
      (context, data, slots) => ChatScreen(
        leftChild: slots.child(listSlot),
        child: slots.child(contentSlot),
      ),
    );

    builder.children = buildChildren?.call(this) ?? const [];
  }
}

final chat = ChatLocation(
  id: RouteId.chat,
  screenSize: screenSize,
  buildChildren: (chat) => [
    SearchNode(
      id: RouteId.search,
      chatDisplay: chat.chatDisplay,
      parentRouterKey: chat.listSlot.routerKey,
    ),
    ChannelDetailNode(
      id: RouteId.channelDetail,
      parentRouterKey: chat.contentSlot.routerKey,
    ),
  ],
);
```

```dart
class SearchNode extends Location<SearchNode> {
  final DefaultQueryParam<ChatDisplay> chatDisplay;

  SearchNode({
    required this.chatDisplay,
    super.parentRouterKey,
  });

  @override
  void build(LocationBuilder builder) {
    builder.queryFilters = [
      chatDisplay.matches(ChatDisplay.search),
    ];
    builder.content = Content.widget(const SearchScreen());
  }
}
```

With that tree, opening search while `/chat/channel/42` is selected routes to
`/chat/channel/42?chatDisplay=search`. Calling
`WorkingRouter.of(context).routeBack()` from inside the left nested navigator
resets `chatDisplay` to its default value without popping the channel detail.
This works because `WorkingRouter.of(context)` is navigator-aware inside
nested routing widgets: a `routeBack()` call removes the last active location
owned by that nested navigator. If that navigator has no active location left,
the router falls back to the parent/global back behavior.

## Generated API

From `@RouteNodes()`, the generator emits:

- `routeToX(...)` helpers on `WorkingRouterSailor`
- `XRouteTarget(...)` classes for typed imperative navigation and redirects
- `childXTarget(...)` extension helpers on concrete location types for
  start-anchored child routing
- `routeToChildX(BuildContext context, ...)` extension helpers on concrete
  location types as sugar over `childXTarget(...)`
- `routeToFirstChildX(BuildContext context, ...)` only for ambiguous
  first-match child routing when no safe `childXTarget(...)` can be generated

For start-anchored child targets:

- global route ids are usually top-level `final NodeId<T>()` values
- child routing can use top-level `final LocalNodeId<T>()` values via
  `localId`, which are preferred over route type names for generated
  `childXTarget(...)` names and matching
- both token types are intentionally non-const: ids are modeled as identity
  tokens, and repeated occurrences of the same route-node type may need
  distinct ids
- generated helper names derive from the referenced id variable name and strip
  common trailing suffixes like `Id`, `NodeId`, and `LocalId`
- if the same start node could reach multiple descendants that would generate the
  same `childXTarget(...)` helper, the generator suppresses that safe ancestor
  helper and generates `routeToFirstChildX(...)` instead

Runtime target types:

- `ChildRouteTarget(...)` is the safe form. It is anchored at a concrete
  `start` location instance and uses `resolveChildPathNodes` to resolve the
  exact live descendant route-node chain below that start node at navigation
  time.
- `resolveChildPathNodes` is not just a predicate. It returns the concrete
  route-node path to append below `start`, which avoids ambiguous first-match
  routing when multiple descendants could satisfy the same leaf match.
- `FirstChildRouteTarget(...)` is the explicit first-match fallback. It starts
  from the current active leaf and walks descendants depth-first until its
  predicate matches.

Preferred pattern:

```dart
node.routeToChildAbc(context, c: 'see');
```

Use the lower-level target form when you need to compose or store the target:

```dart
router.routeTo(node.childAbcTarget(c: 'see'));
```

If the route is ambiguous on purpose and you explicitly want first-match
relative routing, use the generated fallback:

```dart
node.routeToFirstChildAbc(context, c: 'see');
```

Important: `routeToFirstChildX(...)` is only generated when all ambiguous
matching descendants still collapse to the same generated helper signature.
So the only remaining ambiguity is which matching descendant will be chosen
first at runtime. The helper is not generated when one branch would require
extra path/query parameters or incompatible parameter metadata.

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
- an `ShellLocation` that removes one nesting level from a
  `Shell + Location`
  pattern
- override-based `Location<Self>` and `ShellLocation<Self>` nodes with
  constructor-provided children
- direct `Shell(...)` usage for structural navigator boundaries
- typed path and query params
- generated `routeToX(...)` helpers
- generated `XRouteTarget(...)` classes
- generated start-anchored `childXTarget(...)` helpers
- a custom modal page from `builder.page = ...`

Run it from [`example`](example).
