# Running tasks

Bolt can run Puppet tasks on remote nodes without requiring any Puppet infrastructure. 

To execute a task, run `bolt task run`, specifying:

-   The full name of the task, formatted as `<MODULE::TASK>`, or as `<MODULE>` for a module's main task \(the `init` task\).

-   Any task parameters, as `parameter=value`.

-   The nodes on which to run the task and the connection protocol, with the `--nodes` flag.

-   If credentials are required to connect to the target node, the username and password, with the `--user` and `--password` flags.


For example, to run the `sql` task from the `mysql` module on node named neptune:

```
bolt task run mysql::sql database=mydatabase sql="SHOW TABLES" --nodes neptune --modulepath ~/modules
```

To run the main module task defined in `init`, refer to the task by the module name only. For example, the `puppetlabs-package` module contains only one task, defined as `init`, but this task can execute several actions. To run the `status` action from this module to check whether the vim package is installed, you run:

```
bolt task run package action=status name=vim --nodes neptune --modulepath ~/modules
```

## Passing structured data to tasks

If one of your task parameters accepts structured data like an `Array` or
`Hash`, it can be passed as JSON from the command line.

If a single parameter can be parsed as JSON and the parsed value matches the
parameter's type specification in the task metadata it can be passed with
`<param>=value` syntax. Make sure to wrap the JSON value in single quotes to
prevent `"` characters from being swallowed by the shell.

```
bolt task run mymodule::mytask --nodes app1.myorg.com load_balancers='["lb1.myorg.com", "lb2.myorg.com"]'
```

If you want to pass multiple structured values or are having trouble with the
magic parsing of single parameters, you can pass a single JSON object for all
parameters with the `--params` flag.

```
bolt task run mymodule::mytask --nodes app1.myorg.com --params '{"load_balancers": ["lb1.myorg.com", "lb2.myorg.com"]}'
```

You can also load parameters from a file by putting `@` before the file name.

```
bolt task run mymodule::mytask --nodes app1.myorg.com --params @param_file.json
```

To pass JSON values in PowerShell without worrying about escaping use `ConvertTo-Json`

```
bolt task run mymodule::mytask --nodes app1.myorg.com --params $(@{load_balancers=@("lb1.myorg.com","lb2.myorg.com")} | ConvertTo-Json)
```

## Specify the module path

In order for Bolt to find a task, the task must be in a module on the `modulepath`. By
default, the `modulepath` includes `modules/` and `site/` directories inside the
`Boltdir`. If you are developing a new task you can specify `--modulepath
<PARENT_DIR_OF/MODULE>` to tell Bolt where to load the module. For example if
your module is in `~/src/modules/my_module/` run Bolt with `--modulepath
~/src/module`. If you often use the same `modulepath` you can set `modulepath` in
`bolt.yaml`.
