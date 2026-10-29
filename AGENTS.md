# working_router

A declarative Flutter router. This repository holds:

- the `working_router` package in `lib/`, with the route helper generator in
  `lib/src/route_generation/`;
- the `working_router_lint` analyzer plugin in `packages/working_router_lint/`,
  published to pub.dev;
- an example app in `example/`.

## General

- The repository is public on GitHub, and issues are GitHub issues; there is no
  Linear project. Use `github-cli` for pull requests, issues, and checks.
- Run Flutter and Dart through FVM, as `fvm flutter` and `fvm dart`, so they use
  the version in `.fvmrc`.
- Run the tests of a package from its directory: `fvm flutter test` for
  `working_router` and `example/`, and `fvm dart test` for
  `packages/working_router_lint/`.
- CI runs only the agent checks in `.github/workflows/agent-checks.yml`. Run the
  tests of every package a change touches locally before pushing.
- Keep the [customer content](.agents/skill-extensions/shared/customer-content.md)
  up to date with the behavior and API it describes.
