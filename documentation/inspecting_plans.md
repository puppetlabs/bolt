# Inspecting plans

Before you run a plan in your environment, inspect the plan to determine what effect it has on your targets.

🔩 **Tip:** Bolt is packaged with a collection of modules that contain useful plans to support common workflows. For details, see [Packaged modules](bolt_installing_modules.md#packaged-modules).

## Discover plans

View a list of plans available on the current [modulepath](#specify-the-modulepath):

```
bolt plan show
``` 

## Inspect a plan

View parameters and other details for a plan, including whether a plan supports `--noop`:

```
bolt plan show <PLAN NAME>
```

For example, to see the parameters and documentation for the `facts::info` plan, run:

```
bolt plan show facts::info
```