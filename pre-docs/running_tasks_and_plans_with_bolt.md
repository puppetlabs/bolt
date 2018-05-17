
# Running tasks and plans with Bolt

Bolt can run Puppet tasks and plans on remote nodes without requiring any
pre-existing Puppet infrastructure.

Tasks are single, ad hoc actions that you can run on a target machines. Task
plans let you bundle tasks together, pass computed values to tasks, and run
tasks based on the results of previous tasks.

> Important: Only Ruby, Puppet, and PowerShell tasks are supported on Windows. To
> run Ruby (`.rb`) and Puppet (`.pp`) tasks on Windows, the Puppet agent package must
> be installed on the target nodes. The agent itself does not have to be set up
> or running, but the task runner depends on the Ruby environment in the agent
> package. This does not apply to tasks written in PowerShell. To run python
> tasks requires having a python interpreter installed and available in path on
> your machine.

## Installing tasks and plans

Tasks and plans are packaged in Puppet modules, so you can install them as you
would any module from the Forge. Install from the command line with the puppet
module install command, or install and manage them with a Puppetfile and Code
Manager. For more details, see the installing modules documentation.


## Inspecting tasks and plans

Before running tasks or plans in your environment, you can inspect them to
determine their effect using noop mode, or using the Bolt show commands.

### Run in no-operation mode

You can run some tasks in no-operation mode (`--noop`) to view changes  without taking any action on your target node. This way, you ensure the tasks perform as designed. Add the `--noop` flag to your `bolt task run` command. If a task doesn't support no-operation mode, you'll get an  error. `bolt task run package name=vim
action=install --noop -n example.com`

### Show a task list

Bolt displays a list of what tasks are installed in the current module path
with the show command.

```
bolt task show
```

### Show documentation for a task

To see parameters and other details for a task, including whether a task
supports no-operation mode`--noop`, use the `show <TASK NAME>` command.

```
bolt task show <TASK NAME>
```


### Discover plans
Bolt can display a list of what plans are installed on the current module path
with the show command.
```
bolt plan show
```

### Show documentation for a plan

To see parameters and other details for a plan, including whether a plan
supports the no-operation mode `--noop`, use the `show <PLAN NAME>` command.

```
bolt plan show <TASK NAME>
```

## Running tasks

Bolt can run Puppet tasks on remote nodes without requiring any Puppet infrastructure.

To execute a task, run `bolt task run`, specifying:

- The full name of the task, formatted as `<MODULE::TASK>`, or as `<MODULE>` for
  a module's main task (the init task).
- Any task parameters, as `parameter=value`.
- The nodes on which to run the task and the connection protocol, with the `--nodes` flag.
- The module path that contains the task, with the `--modulepath` flag.
- If credentials are required to connect to the target node, the username and password, with the --username and --password flags.

For example, to run the sql task from the mysql module on node named neptune:

```
bolt task run mysql::sql database=mydatabase sql="SHOW TABLES" --nodes neptune --modulepath ~/modules
```

To run the main module task defined in `init`, refer to the task by the module
name only. For example, the `puppetlabs-package` module contains only one task,
defined as `init`, but this task can execute several actions. To run the `status`
action from this module to check whether the vim package is installed, you
would run:

```
bolt task run package action=status name=vim --nodes neptune --modulepath ~/modules
```

## Running plans

Bolt can run plans, allowing multiple tasks to be tied together.

To execute a task plan, run bolt plan run, specifying:
- The full name of the plan, formatted as <MODULE>::<PLAN>.
- Any plan parameters, as parameter=value.
- The module path that contains the plan's module, with the --modulepath flag.
- If credentials are required to connect to the target node, pass the username and password with the --username and --password flags.

For example, if a plan defined in `mymodule/plans/myplan.pp` accepts a
`load_balancer` parameter to specify a load balancer node on which to run the
tasks or functions in the plan, run:

```
bolt plan run mymodule::myplan --modulepath ./PATH/TO/MODULES  load_balancer=lb.myorg.com
```
Note that, like `--nodes`, you can pass a comma-separated list of node names,
wildcard patterns, or group names to a plan parameter that will be passed to a
run function or that the plan resolves using `get_targets`.

## Specifying parameters

Parameters for tasks can be passed to the `bolt` command as CLI arguments or as a
single JSON hash.

To pass parameters individually to your task or plan, specify the parameter value on the
command line in the format `parameter=value`. Pass multiple parameters as a
space-separated list. Bolt will attempt to parse each parameter value as JSON
and compare that to the parameter type specified by the task or plan. If the
parsed value matches the type it will be used otherwise the original string
will be.

For example, to run the `mysql::sql` task to show tables from a database called mydatabase:

```
bolt task run mysql::sql database=mydatabase sql="SHOW TABLES" --nodes neptune --modules ~/modules
```

To pass a string value that is valid JSON to a parameter that would accept both
quote the string. For example to pass the string `true` to a parameter of type
`Variant[String, Boolean]` use `'foo="true"'`. To pass a String value wrapped
in `"` quote and escape it `'string="\"val\"'`.

Alternatively, you can specify parameters as a single JSON object with the `--params` flag,
passing either a JSON object or a path to a parameter file.

To specify parameters as simple JSON, use the parameters flag followed by the
JSON: `--params '{"name": "openssl"}'`

To set parameters in a file, specify parameters in JSON format in a file, such
as `params.json`. For example, create a `params.json` file that contains the
following JSON:


```json
{
  "name":"openssl"
}
```

Then specify the path to that file (starting with an at symbol, `@`) on the
command line with the parameters flag: `--params @params.json`
