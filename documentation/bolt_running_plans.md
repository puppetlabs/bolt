# Running Plans

Bolt plans allow you to tie together complex workflows that include multiple tasks, scripts, commands, and even other plans. 

To execute a plan, run `bolt plan run` and specify:
-   The full name of the plan, formatted as `<MODULE>::<PLAN>`.
-   Any plan parameters, as `parameter=value`.
-   The username and password to access the target. Pass these in as `--user` and `--password` flags. 

For example, imagine a plan that deploys a load balancer. The plan is located at `mymodule/plans/myplan.pp` and accepts a `load_balancer` parameter, which is the target that the plan runs its tasks or functions on. If your load balancer was `lb.myorg.com`, you would use the following command to run the plan:

```
bolt plan run mymodule::myplan load_balancer=lb.myorg.com
```

> **Remember:** You can find the documentation and required parameters for a plan using `bolt plan show <PLAN NAME>`.

You can pass a comma-separated list of target names, wildcard patterns, or group names to a plan parameter of type `TargetSpec`. For more information on the `TargetSpec` type, see [Writing plans in the Puppet language](./writing_plans.md#targetspec).

## Passing structured data into a plan

If one of your plan parameters accepts structured data like an `array` or `hash`, you can pass the data into the plan as JSON from the command line. The parsed value must match the parameter's type specification in the plan definition.

To pass a single parameter as JSON, use the syntax `<PARAM>=<VALUE>`. Make sure you wrap the JSON value in single quotes to prevent `"` characters from being swallowed by the shell. For example:

```
bolt plan run mymodule::myplan load_balancers='["lb1.myorg.com", "lb2.myorg.com"]'
```

If you want to pass multiple structured values or are having trouble with the magic parsing of single parameters, you can pass a single JSON object for all parameters with the `--params` flag. For example:

```
bolt plan run mymodule::myplan --params '{"load_balancers": ["lb1.myorg.com", "lb2.myorg.com"]}'
```

You can also load parameters from a file by putting `@` before the file name. For example:

```
bolt plan run mymodule::myplan --params @param_file.json
```

To pass JSON values in PowerShell without worrying about escaping, use `ConvertTo-Json`. For example:

```
bolt plan run mymodule::myplan --targets app1.myorg.com --params $(@{load_balancers=@("lb1.myorg.com","lb2.myorg.com")} | ConvertTo-Json)
```