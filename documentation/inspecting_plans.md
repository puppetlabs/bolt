# Inspecting plans

Before you run a plan in your environment, inspect the plan to determine what effect it has on your targets.

🔩 **Tip:** Bolt is packaged with a collection of modules that contain useful plans to support common workflows. For details, see [Packaged modules](bolt_installing_modules.md).

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

## Specify the modulepath

In order for Bolt to find a task or plan, the task or plan must be in a module on the `modulepath`. By default, the `modulepath` includes `modules/` and `site-modules/` directories inside the Bolt project directory.

If you are developing a new plan, you can specify `--modulepath <PARENT_DIR_OF/MODULE>` to tell Bolt where to load the module. For example, if your module is in `~/src/modules/my_module/`, run Bolt with `--modulepath ~/src/module`. If you often use the same `modulepath`, you can set `modulepath` in `bolt.yaml`.

For more information on project directories, see [Project directories](./bolt_project_directories.md).