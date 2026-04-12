# working_router_lint

`working_router_lint` is an analyzer plugin for
[`working_router`](https://github.com/saibotma/working_router) location trees.

It currently provides IDE assists for restructuring location trees without
manually rewriting `builder.children = [...]` lists.

Current assists:
- Wrap a `builder.children = [...]` entry with `Scope`
- Wrap a `builder.children = [...]` entry with `Shell`
- Remove an element while keeping its children when the structure is
  unambiguous

## Requirements

- Dart 3.10 or newer
- Flutter 3.38 or newer

## Setup

Enable the plugin in your app's `analysis_options.yaml`.

### Published package

```yaml
plugins:
  working_router_lint: ^0.1.6
```

### Local checkout

```yaml
plugins:
  working_router_lint:
    path: ../working_router/packages/working_router_lint
```

After changing the `plugins:` section, restart the Dart analysis server in your
IDE once.
