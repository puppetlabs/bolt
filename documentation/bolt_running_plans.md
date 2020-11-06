# Running plans

Bolt plans allow you to tie together complex workflows that include multiple
tasks, scripts, commands, and even other plans. Bolt is packaged with a
collection of modules that contain useful plans to support common workflows. For
details, see [Packaged modules](bolt_installing_modules.md#packaged-modules).

To execute a plan, run `bolt plan run` and specify:
-   The full name of the plan, formatted as `<MODULE>::<PLAN>`.
-   Any plan parameters, as `<PARAMETER>=<VALUE>`.
-   (If required) The username and password to access the target. Pass these in
    as `--user` and `--password` command-line options. 

For example, imagine a plan that deploys a load balancer. The plan is located at
`mymodule/plans/myplan.pp` and accepts a `load_balancer` parameter, which is the
target that the plan runs its tasks or functions on. If your load balancer was
`lb.myorg.com`, you would use the following command to run the plan:

- _\*nix shell command_

  ```shell
  bolt plan run mymodule::myplan load_balancer=lb.myorg.com
  ```

- _PowerShell cmdlet_

  ```powershell
  Invoke-BoltPlan -Name mymodule::myplan load_balancer=lb.myorg.com
  ```

> **Remember:** You can find the documentation and required parameters for a
> plan using the `bolt plan show <PLAN NAME>` command, or the `Get-BoltPlan
> -Name <PLAN NAME>` PowerShell cmdlet.

You can pass a comma-separated list of target names, wildcard patterns, or group
names to a plan parameter of type `TargetSpec`. For more information on the
`TargetSpec` type, see [Writing plans in the Puppet
language](./writing_plans.md#targetspec).

## Plan location

In order for Bolt to find a plan, the plan must be in a module on the modulepath
or in a `plans/` directory in your Bolt project. If you are developing a new
plan, you can [create a Bolt project](projects.md#create-a-bolt-project),
develop your task in `<PROJECT DIRECTORY>/plans/`, and run Bolt from the root of
your Bolt project directory to test the task.

## Passing structured data into a plan

If one of your plan parameters accepts structured data like an `array` or
`hash`, you can pass the data into the plan as JSON from the command line. The
parsed value must match the parameter's type specification in the plan
definition.

To pass a single parameter as JSON, use the syntax `<PARAMETER>=<VALUE>`. Make
sure you wrap the JSON value in single quotes to prevent `"` characters from
being swallowed by the shell. For example:

- _\*nix shell command_

  ```shell
  bolt plan run mymodule::myplan load_balancers='["lb1.myorg.com", "lb2.myorg.com"]'
  ```

- _PowerShell cmdlet_

  ```powershell
  Invoke-BoltPlan -Name mymodule::myplan load_balancers='["lb1.myorg.com", "lb2.myorg.com"]'
  ```

If you want to pass multiple structured values or are having trouble with the
magic parsing of single parameters, you can pass a single JSON object for all
parameters with the `params` command-line option. For example:

- _\*nix shell command_

  ```shell
  bolt plan run mymodule::myplan --params '{"load_balancers": ["lb1.myorg.com", "lb2.myorg.com"]}'
  ```

- _PowerShell cmdlet_

  ```powershell
  Invoke-BoltPlan -Name mymodule::myplan -Params '{"load_balancers": ["lb1.myorg.com", "lb2.myorg.com"]}'
  ```

You can also load parameters from a file by putting `@` before the file name.
For example:

- _\*nix shell command_

  ```shell
  bolt plan run mymodule::myplan --params @param_file.json
  ```

- _PowerShell cmdlet_

  ```powershell
  Invoke-BoltPlan -Name mymodule::myplan -Params '@param_file.json'
  ```

📖 **Related information**

- For information on Bolt project directories, see [Bolt project
  directories](projects.md).
- For information on running Bolt tasks, see [Running
  tasks](./bolt_running_tasks.md).
- To find out how to write your own plan, see [Writing plans in
  YAML](./writing_yaml_plans.md) or [Writing plans in the Puppet
  language](./writing_plans.md).
- For more information about the modulepath, see [Modules
  overview](modules.md#modulepath).   
