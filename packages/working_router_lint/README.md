# working_router_lint

Analysis server plugin for `working_router` location trees.

Current assists:
- Wrap a `builder.children = [...]` entry with `Group`
- Wrap a `builder.children = [...]` entry with `Shell`

To use it in an app:
- add this package as a dev dependency
- enable it in `analysis_options.yaml` with:

```yaml
analyzer:
  plugins:
    - working_router_lint
```
