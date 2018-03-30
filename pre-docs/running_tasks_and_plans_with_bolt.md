
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

Tasks and plans are located in modules, which means they can be shared and
downloaded on the Forge, and installed just as you would install any module.

Tasks and plans are packaged in Puppet modules, so you can install them as you
would any module from the Forge. Install from the command line with the puppet
module install command, or install and manage them with a Puppetfile and Code
Manager. For more details, see the installing modules documentation.


## Inspecting tasks and plans

Before running tasks or plans in your environment, you can inspect them to
determine their effect using noop mode, or using the Bolt show commands.


### Run in noop mode

Some tasks can run as noop, so you can run them without making changes to your
target node. This way, you ensure the tasks perform as designed. To run a task
in noop mode with Bolt, use the `--noop` flag. If a task doesn't support running
in noop mode, you'll get an error.  `bolt task run package name=vim
action=install --noop -n example.com`

### Show a task list

Bolt displays a list of what tasks are installed in the current module path
with the show command.

```
bolt task show
```

### Show documentation for a task

To see parameters and other details for a task, including whether a task
supports `--noop`, use the `show <TASK NAME>` command.

```
bolt task show <TASK NAME>
```


### Discover plans
Bolt can display a list of what plans are installed on the current module path
with the show command.
```
bolt plan show
```

## Running tasks

Bolt can run Puppet tasks on remote nodes without requiring any Puppet infrastructure.

To execute a task, run bolt task run, specifying:

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
- The nodes on which to run the plan and the connection protocol, formatted as parameters: node=<NODE1>,<NODE2>.
- The module path that contains the plan, with the --modulepath flag.
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

You can provide task or plan parameters as either environment variables or a JSON hash on standard input.

Parameters for tasks can be passed to the `bolt` command as CLI arguments or as a
JSON hash. Parameters passed as CLI arguments are always parsed as strings; for
other types, you must pass parameters as a JSON hash. When you run a command
with parameters, before Bolt executes the task, it sets the the values you
specify, submitting the parameters as environment variables and as simple JSON
on `stdin`.

To pass parameters to your task or plan, specify the parameter value on the
command line in the format parameter=value. Pass multiple parameters as a
space-separated list.

For example, to run the `mysql::sql` task to show tables from a database called mydatabase:

```
bolt task run mysql::sql database=mydatabase sql="SHOW TABLES" --nodes neptune --modules ~/modules
```
Alternatively, you can specify parameters as JSON with the `--params` flag,
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
