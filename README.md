# working_router

A Flutter router built around a typed `Location` tree.

It supports:
- nested routing from a declarative location tree
- routing by `id`
- path and query parameter handling
- generated `routeToX(...)` helpers with compile-time checked parameters

## Route Helper Generation

Annotate the static location tree with `@WorkingRouterLocationTree()` and run
`build_runner`.

```dart
import 'package:working_router/working_router.dart';

part 'main.g.dart';

enum LocationId { splash, lesson, lessonEdit }

class SplashLocation extends Location<LocationId> {
  SplashLocation({super.id, super.children = const []});

  @override
  String get path => '';
}

class LessonLocation extends Location<LocationId> {
  LessonLocation({required super.id})
    : super(
        children: [
          LessonEditLocation(id: LocationId.lessonEdit),
        ],
      );

  @override
  String get path => 'lessons/:lessonId';

  @override
  Set<String> get queryParameters => {
    'coursePeriodId',
    'sourceDateTime',
  };
}

class LessonEditLocation extends Location<LocationId> {
  LessonEditLocation({required super.id});

  @override
  String get path => 'edit';
}

@WorkingRouterLocationTree()
final Location<LocationId> appLocationTree = SplashLocation(
  id: LocationId.splash,
  children: [
    LessonLocation(id: LocationId.lesson),
  ],
);

final router = WorkingRouter<LocationId>(
  locationTree: appLocationTree,
  noContentWidget: const SizedBox(),
  buildRootPages: (_, location, __) => [],
);
```

Generated API:

```dart
router.routeToSplash();
router.routeToLesson(
  lessonId: '42',
  coursePeriodId: 'current',
  sourceDateTime: '2026-04-04T10:00:00Z',
);
router.routeToLessonEdit(
  lessonId: '42',
  coursePeriodId: 'current',
  sourceDateTime: '2026-04-04T10:00:00Z',
);
```

The generated helper name comes from the `id` enum case. Its required
parameters are the full ancestor-chain union of:
- path parameters
- query parameter keys declared through `Location.queryParameters`

## Setup

Add `build_runner` to the consuming app's `dev_dependencies`, then run:

```sh
flutter pub run build_runner build --delete-conflicting-outputs
```

Or during development:

```sh
flutter pub run build_runner watch --delete-conflicting-outputs
```

## Supported Static Tree Shapes

The generator can resolve the route tree without executing your application
code. Supported patterns include:
- a top-level annotated field, getter, or zero-argument function returning the root `Location`
- inline child lists
- top-level or static helper fields, getters, and zero-argument functions
- children passed directly to a location constructor
- children passed via `super(children: [...])` inside a location constructor
- query parameter keys declared as string literals or const string identifiers

## Unsupported Patterns

The route topology must stay static. These patterns are intentionally not
supported:
- annotating instance members or static class members directly
- children that appear or disappear based on runtime values
- route trees that depend on callbacks with runtime-dependent output
- resolving children from an overridden `children` getter

If a route should only be accessible under certain conditions, keep it in the
static tree and enforce access with redirect or transition logic instead of
removing it from the tree.
