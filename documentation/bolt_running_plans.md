# Running plans

Bolt can run plans, allowing multiple tasks to be tied together. 

To execute a task plan, run `bolt plan run`, specifying:

-   The full name of the plan, formatted as `<MODULE>::<PLAN>`.
-   Any plan parameters, as `parameter=value`.
-   If credentials are required to connect to the target, pass the username and password with the `--user` and `--password` flags.

For example, if a plan defined in `mymodule/plans/myplan.pp` accepts a `load_balancer` parameter to specify a load balancer target on which to run the tasks or functions in the plan, run:

```
bolt plan run mymodule::myplan load_balancer=lb.myorg.com
```

Note that, like `--targets`, you can pass a comma-separated list of target names, wildcard patterns, or group names to a plan parameter that is passed to a run function or that the plan resolves using `get_targets`.

When a plan has the parameter `$nodes` and the plan is invoked with either the `--nodes` or `--targets` CLI arguments the argument value will be passed as a plan parameter (for example `nodes=[value]`). Similarly, when a plan accepts a `TargetSpec $targets` parameter the value of `--nodes` or `--targets` is passed as the `targets=[value]` parameter. When a plan contains both a `$nodes` parameter and a `TargetSpec $targets` parameter, the value of the `--nodes` or `--targets` arguments will not be passed.

> 🔩 **Tip:** Bolt is packaged with a collection of modules that contain useful plans to support common workflows. For details, see [Packaged modules](bolt_installing_modules.md).

📖 **Related information**  

[Example plans](writing_plans.md#)

## Passing structured data

If one of your task or plan parameters accept structured data like an `array` or `hash`, it can be passed as JSON from the command line.

If a single parameter can be parsed as JSON and the parsed value matches the parameter's type specification in the task metadata or plan definition, it can be passed with `<PARAM>=<VALUE>` syntax. Make sure to wrap the JSON value in single quotes to prevent `"` characters from being swallowed by the shell.

```
bolt task run mymodule::mytask --targets app1.myorg.com load_balancers='["lb1.myorg.com", "lb2.myorg.com"]'
```

```
bolt plan run mymodule::myplan load_balancers='["lb1.myorg.com", "lb2.myorg.com"]'
```

If you want to pass multiple structured values or are having trouble with the magic parsing of single parameters, you can pass a single JSON object for all parameters with the `--params` flag.

```
bolt task run mymodule::mytask --targets app1.myorg.com --params '{"load_balancers": ["lb1.myorg.com", "lb2.myorg.com"]}'
```

```
bolt plan run mymodule::myplan --params '{"load_balancers": ["lb1.myorg.com", "lb2.myorg.com"]}'
```

You can also load parameters from a file by putting `@` before the file name.

```
bolt task run mymodule::mytask --targets app1.myorg.com --params @param_file.json
```

```
bolt plan run mymodule::myplan --params @param_file.json
```

To pass JSON values in PowerShell without worrying about escaping, use `ConvertTo-Json`

```
bolt task run mymodule::mytask --targets app1.myorg.com --params $(@{load_balancers=@("lb1.myorg.com","lb2.myorg.com")} | ConvertTo-Json)
```

```
bolt plan run mymodule::myplan --targets app1.myorg.com --params $(@{load_balancers=@("lb1.myorg.com","lb2.myorg.com")} | ConvertTo-Json)
```

## Specifying the modulepath

In order for Bolt to find a plan, the plan must be in a module on the modulepath. By default, Bolt looks for plan content in `<PROJECT_NAME>/modules/plans/` and `<PROJECT_NAME>/site-modules/plans/`.

If you are developing a new plan, you can create an empty
`<PROJECT_NAME/bolt-project.yaml` file, develop your plan in `<PROJECT_NAME>/plans/`,
and run Bolt from the root of your Bolt project directory to test the plan. 

> **Note:** The `bolt-project.yaml` file is part of an experimental feature. For
> more information, see [Bolt projects](./experimental_features.md#bolt-projects).

📖 **Related information**

[Bolt project directories](#bolt_project_directories.md)
