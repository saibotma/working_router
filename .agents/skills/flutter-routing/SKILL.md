---
name: flutter-routing
description:
  Use when working with Flutter app routing, including route definitions,
  navigation behavior, and router conventions.
metadata:
  tags: working-router
---

Rules that name a shared helper, such as a widget, Riverpod extension, or
annotation that Flutter and its packages do not provide, refer to the shared
Flutter foundation. It currently lives in Appella's `app/lib` and is being
extracted into `appella/appella-toolkit`. When a project lacks such a helper,
copy it from there instead of building a different replacement.

- When extracting multiple values from the router, always use a single
  `routerDataSlice` call instead of multiple separate calls; Use Dart records
  `(value1, value2)` to extract multiple parameters cleanly, or perform
  transformations directly within the callback
- We are the maintainers of `working_router`. When routing behavior exposes a
  missing feature, bug, or bad API in `working_router`, propose fixing it there
  directly instead of defaulting to an app-level workaround.
- In nested modal routing flows (`PlatformModalPage`), set
  `fullscreenDialog: true` on the first inner `MaterialPage` leaf screen when it
  should get dialog-style close button behavior from the app bar
- In route node constructors, keep `RouteNodeContext context` as the first
  required project-specific parameter, before route params, mode flags, and
  other route-node dependencies
- Name route node classes with the `RouteNode` suffix, including classes that
  extend `AbstractOverlay`; use `Overlay` only for fields/collections such as
  `builder.overlays`, not for route node class names
