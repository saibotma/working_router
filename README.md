# working_router

A Flutter router built around a typed `Location` tree.

It supports:
- nested routing from a declarative location tree
- routing by `id`
- path and query parameter handling
- generated `routeToX(...)` helpers with compile-time checked parameters

## Route Helper Generation

Annotate the canonical `buildLocationTree` entrypoint with
`@WorkingRouterLocationTree()` and run `build_runner`.

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
Location<LocationId> buildLocationTree({
  required bool includeLessons,
}) => SplashLocation(
      id: LocationId.splash,
      children: [
        if (includeLessons) LessonLocation(id: LocationId.lesson),
      ],
    );

final router = WorkingRouter<LocationId>(
  buildLocationTree: () => buildLocationTree(includeLessons: true),
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

The generator is union-based, not exact-runtime-based. In children lists it
includes routes from collection `if` branches without evaluating the condition.
That means generated helpers guarantee parameter completeness, but a helper may
still target a route that is currently pruned from the live runtime tree.

The annotated builder used for code generation may take parameters. At runtime,
pass a closure to `WorkingRouter.buildLocationTree` that binds those values.

## Setup

Add `build_runner` to the consuming app's `dev_dependencies`, then run:

```sh
flutter pub run build_runner build --delete-conflicting-outputs
```

Or during development:

```sh
flutter pub run build_runner watch --delete-conflicting-outputs
```

## Supported Tree Shapes

The generator resolves a canonical tree from source and generates for the union
of routes that can appear. Supported patterns include:
- a top-level annotated field, getter, or function returning the root `Location`
- inline child lists
- top-level or static helper fields and getters
- top-level, static, or local helper functions
- helper function arguments when the tree-relevant expressions stay statically recoverable
- children passed directly to a location constructor
- children passed via `super(children: [...])` inside a location constructor
- collection `if` elements and spreads in children lists
- query parameter keys declared as string literals or const string identifiers

## Unsupported Patterns

These patterns are intentionally not supported:
- annotating instance members or static class members directly
- loops or other arbitrary collection-building constructs
- resolving children from an overridden `children` getter
