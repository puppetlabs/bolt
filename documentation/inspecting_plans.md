# Inspecting plans

Before you run a plan in your environment, inspect the plan to determine what effect it has on your targets.

> 🔩 **Tip:** Bolt is packaged with a collection of modules that contain useful plans to support common workflows. For details, see [Packaged modules](bolt_installing_modules.md).

## Discover plans

View a list of what plans are installed on the current module path:

```
bolt plan show
```

## Show documentation for a plan

View parameters and other details for a plan, including whether a plan supports `--noop`:

```
bolt plan show <PLAN NAME>
```