# Inspecting plans

Before you run a plan in your environment, inspect the plan to determine what effect it has on your targets.

> 🔩 **Tip:** Bolt is packaged with a collection of modules that contain useful plans to support common workflows. For details, see [Packaged modules](bolt_installing_modules.md#packaged-modules).

## Discover plans

View a list of available plans:

```
bolt plan show
``` 

If you don't see a plan you were expecting to find, make sure the plan is
located in the correct directory. For more information, see [How Bolt locates plans](./bolt_running_plans.md#how-bolt-locates-plans)

## Show documentation for a plan

Use the following command to view parameters and other details for a plan, including whether a plan supports `--noop`:

```
bolt plan show <PLAN_NAME>
```

For example, to see the parameters and documentation for the `facts::info` plan, run:

```
bolt plan show facts::info
```