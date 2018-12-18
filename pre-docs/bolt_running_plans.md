# Running plans

 Bolt can run plans, allowing multiple tasks to be tied together. 

To execute a task plan, run `bolt plan run`, specifying:

-   The full name of the plan, formatted as `<MODULE>::<PLAN>`.

-   Any plan parameters, as `parameter=value`.

-   If credentials are required to connect to the target node, pass the username and password with the `--user` and `--password` flags.


For example, if a plan defined in `mymodule/plans/myplan.pp` accepts a `load_balancer` parameter to specify a load balancer node on which to run the tasks or functions in the plan, run:

```
bolt plan run mymodule::myplan load_balancer=lb.myorg.com

```

Note that, like `--nodes`, you can pass a comma-separated list of node names, wildcard patterns, or group names to a plan parameter that will be passed to a run function or that the plan resolves using `get_targets`.

## Passing structured data to plans

If one of your plan parameters accepts structured data like an `Array` or
`Hash`, it can be passed as JSON from the command line.

If a single parameter can be parsed as JSON and the parsed value matches the
parameter's type specification in the plan definition it can be passed with
`<param>=value` syntax. Make sure to wrap the JSON value in single quotes to
prevent `"` characters from being swallowed by the shell.

```
bolt plan run mymodule::myplan load_balancers='["lb1.myorg.com", "lb2.myorg.com"]'
```

If you want to pass multiple structured values or are having trouble with the magic parsing of single parameters, you can pass a single JSON object for all parameters with the `--params` flag.

```
bolt plan run mymodule::myplan --params '{"load_balancers": ["lb1.myorg.com", "lb2.myorg.com"]}'
```

You can also load parameters from a file by putting `@` before the file name.

```
bolt plan run mymodule::myplan --params @param_file.json
```

To pass JSON values in PowerShell without worrying about escaping use `ConvertTo-Json`

```
bolt plan run mymodule::myplan --nodes app1.myorg.com --params $(@{load_balancers=@("lb1.myorg.com","lb2.myorg.com")} | ConvertTo-Json)
```

## Specify the module path

In order for Bolt to find a plan, the plan must be in a module on the `modulepath`. By
default the `modulepath` includes `modules/` and `site/` directories inside the
`Boltdir`. If you are developing a new plan you can specify `--modulepath
<PARENT_DIR_OF/MODULE>` to tell Bolt where to load the module. For example if
your module is in `~/src/modules/my_module/` run Bolt with `--modulepath
~/src/module`. If you often use the same `modulepath` you can set `modulepath` in
`bolt.yaml`.
