# Running tasks

Bolt can run Puppet tasks on remote targets without requiring any Puppet
infrastructure. 

To execute a task, run `bolt task run`, specifying:

-   The full name of the task, formatted as `<MODULE::TASK>`, or as `<MODULE>`
    for a module's main task \(the `init` task\).
-   Any task parameters, as `parameter=value`.
-   The targets on which to run the task and the connection protocol, with the
    `--targets` flag.
-   If credentials are required to connect to the target, the username and
    password, with the `--user` and `--password` flags.

For example, to run the `sql` task from the `mysql` module on a target named
neptune:

```
bolt task run mysql::sql database=mydatabase sql="SHOW TABLES" --targets neptune --modulepath ~/modules
```

To run the main module task defined in `init`, refer to the task by the module
name only. For example, the `puppetlabs-package` module contains only one task,
defined as `init`, but this task can execute several actions. To run the
`status` action from this module to check whether the vim package is installed,
you run:

```
bolt task run package action=status name=vim --targets neptune --modulepath ~/modules
```

> 🔩 **Tip:** Bolt ships with a collection of modules that contain useful plans
> to support common workflows. For details, see [Packaged
> modules](bolt_installing_modules.md).


## Passing structured data

If one of your task or plan parameters accept structured data like an `array` or
`hash`, it can be passed as JSON from the command line.

If a single parameter can be parsed as JSON and the parsed value matches the
parameter's type specification in the task metadata or plan definition, it can
be passed with `<PARAM>=<VALUE>` syntax. Make sure to wrap the JSON value in
single quotes to prevent `"` characters from being swallowed by the shell.

```
bolt task run mymodule::mytask --targets app1.myorg.com load_balancers='["lb1.myorg.com", "lb2.myorg.com"]'
```

```
bolt plan run mymodule::myplan load_balancers='["lb1.myorg.com", "lb2.myorg.com"]'
```

If you want to pass multiple structured values or are having trouble with the
magic parsing of single parameters, you can pass a single JSON object for all
parameters with the `--params` flag.

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

To pass JSON values in PowerShell without worrying about escaping, use
`ConvertTo-Json`

```
bolt task run mymodule::mytask --targets app1.myorg.com --params $(@{load_balancers=@("lb1.myorg.com","lb2.myorg.com")} | ConvertTo-Json)
```

```
bolt plan run mymodule::myplan --targets app1.myorg.com --params $(@{load_balancers=@("lb1.myorg.com","lb2.myorg.com")} | ConvertTo-Json)
```

## Specifying the module path

In order for Bolt to find a task, the task must be in a module on the module
path. The default modulepath is `[<project directory>/modules, <project
directory>/site-modules]`.

The current [Bolt project](./experimental_features.md#bolt-projects) is loaded
as a standalone module at the front of the module path.  If you are developing a
new task, you can create an empty `<PROJECT_NAME>/bolt-project.yaml` file,
develop your task in `<PROJECT_NAME>/tasks/`, and run Bolt from the root of your
Bolt project directory to test the task. 

> **Note:** The `bolt-project.yaml` file is part of an experimental feature. For
> more information, see [Bolt
> projects](./experimental_features.md#bolt-projects).

📖 **Related information**

[Bolt project directories](#bolt_project_directories.md)
