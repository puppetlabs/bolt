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

## Specifying the modulepath

In order for Bolt to find a plan, the plan must be in a module
on the modulepath. By default, Bolt looks for plans in the
`<PROJECT_NAME>/modules/plans` and `<PROJECT_NAME>/site-modules/plans` directories.

If you're developing a new project, and you want to use a simplified
directory structure, create a file called `project.yaml` in the root of your
project directory. 



If `project.yaml` exists at the root of the project directory then the project itself is also loaded
as a module, namespaced to either `name` in project.yaml if it's set or the name of the directory if
not. 

If you are developing a new task or plan you can create a `<PROJECT_NAME>/tasks/` or `<PROJECT_NAME>/plans/`
directory alongside `<PROJECT_NAME/project.yaml` to develop your content in, then run Bolt from the
root of your Bolt project directory to test the task or plan.

**Related Information**

[Bolt project directories](#bolt_project_directories.md)

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
