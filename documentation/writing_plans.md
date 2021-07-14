# Writing plans in the Puppet language

Bolt plans allow you to tie together complex workflows that include multiple
tasks, scripts, commands, and even other plans.

Plans written in the Puppet language allow for more sophisticated control flow
and better error handling than YAML plans. Puppet plans also allow you to apply
blocks of Puppet code to remote targets.

When you're writing a plan, you can use any combination of [Bolt
functions](plan_functions.md) or [built-in Puppet
functions](https://puppet.com/docs/puppet/latest/function.html).

> **Note:** For information on how to convert an existing YAML plan to a Puppet
> plan, see [Converting YAML plans to Puppet language
> plans](writing_yaml_plans.md).

📖 **Related information**

- For information on using Hiera data in plans, see [Using Bolt with Hiera](hiera.md).

## Plan location

Bolt content follows the same directory structure as Puppet modules. Bolt loads
downloaded module plans from `modules/<MODULE_NAME>/plans/`, and local plans
from `site-modules/<MODULE_NAME>/plans/`.

Put your Bolt plan in your module's `plans` directory and give it the `.pp`
extension. For example, given a plan named `my_plan.pp` in a module named
`my_module`, the location of the plan would be
`site-modules/my_module/plans/my_plan.pp`.

## Creating a new project-level Puppet language plan

You can create a new project-level Puppet language plan in your Bolt project
using a Bolt command. The command accepts a single argument: the name of the
plan. Project-level plans must be namespaced to the project.

_\*nix shell command_

```shell
bolt plan new <PLAN NAME> --pp
```

_PowerShell cmdlet_

```powershell
New-BoltPlan -Name <PLAN NAME> -Pp
```

For example, running `bolt plan new myproject::myplan --pp` will result in
a directory structure similar to this:

```shell
myproject/
├── bolt-project.yaml
└── plans/
    └── myplan.pp
```

## Naming plans

The first line of your plan contains the plan name. You use the plan name to
call the plan from the Bolt command line, or from other plans.

Plan names are composed of two or more name segments, indicating:
-   The name of the module the plan is located in.
-   The name of the plan file, without the extension.
-   The path within the module, if the plan is in a subdirectory of `./plans`.

Each plan name segment must begin with a lowercase letter and:
-   Can include lowercase letters.
-   Can include digits.
-   Can include underscores.
-   Must not be a [reserved
    word](https://puppet.com/docs/puppet/latest/lang_reserved.html).
-   Must not have the same name as any Puppet data types.
-   Namespace segments must match the regular expression: `\A[a-z][a-z0-9_]*\Z`.

> **Note**: Avoid giving plans the same names as constructs in the Puppet
> language. Although plans do not share their namespace with other language
> constructs, giving plans these names makes your code difficult to read.

For example, given a module called `mymodule` with a plan defined in
`./mymodule/plans/myplan.pp`, the plan name is `mymodule::myplan`. The first
line in `myplan.pp` would be:

```puppet
plan mymodule::myplan()
```

Similarly, to call a plan defined in `./mymodule/plans/service/myplan.pp`, you
would use the name, `mymodule::service::myplan`.

### `init` plans

The plan filename `init` is special. You reference an `init` plan using the
module name only. For example, in a module called `mymodule`, the plan defined
in `mymodule/plans/init.pp` is the `mymodule` plan. However, this does not apply
to `init` plans nested in subdirectories. For example, an `init` plan at
`mymodule/plans/service/init.pp` is the `mymodule::service::init` plan.

For an example of an `init` plan, see the [facts
plan](https://github.com/puppetlabs/puppetlabs-facts/blob/master/plans/init.pp).

## Defining plan parameters

After the plan's name, in parentheses, define any parameters that you want to
pass into your plan as arguments. To define a parameter, use the syntax `<TYPE>
<PARAMETER_NAME>`. For example, the following plan defines two parameters, `src`
and `dest`, which are both strings:

```puppet
plan mymodule::myplan(
  String $src,
  String $dest
)
...  
```

You can use the `TargetSpec` type to pass a target, or multiple targets, into a
plan parameter. For more information, see [`TargetSpec`](#targetspec).

### JSON serialization

Parameters that are passed to the `run_*` plan functions are serialized to JSON.

In the following plan, the default value of `$example_nul` is `undef`. The plan
calls the task `test::demo_undef_bash` with the `example_nul` parameter.

```
plan test::parameter_passing (
  TargetSpec $targets,
  Optional[String[1]] $example_nul = undef,
) {
  return run_task('test::demo_undef_bash', $targets, 'example_nul' => $example_nul)
}
```

The implementation of the `demo_undef_bash.sh` task is:

```shell script
#!/bin/bash
example_env=$PT_example_nul
echo "Environment: $PT_example_nul"
echo "Stdin:" 
cat -
```

By default, the task expects parameters passed as a JSON string on standard
input (stdin) to be accessible in prefixed environment variables.

Consider the output of running the plan against localhost:

```console
bolt@bolt: bolt plan run test::parameter_passing -n localhost
Starting: plan test::parameter_passing
Starting: task test::demo_undef_bash on localhost
Finished: task test::demo_undef_bash with 0 failures in 0.0 sec
Finished: plan test::parameter_passing in 0.01 sec
Finished on localhost:
  Environment: null
  Stdin:
  {"example_nul":null,"_task":"test::demo_undef_bash"}
  {
  }
Successful on 1 target: localhost
Ran on 1 target
```

The parameters `example_nul` and `_task` metadata are passed to the task as a
JSON string over stdin.

Similarly, parameters are made available to the task as environment variables
where the name of the parameter is converted to an environment variable prefixed
with `PT_`. The prefixed environment variable points to the `String`
representation in `JSON` format of the parameter value. So, the `PT_example_nul`
environment variable has the value of `null` of type `String`.

📖 **Related information**  

- [Task metadata types](writing_tasks.md#common-task-data-types)

### Sensitive parameters

Use the `Sensitive` data type to mask parameters that should not be displayed in
logs.

When you pass a value to a `Sensitive` parameter, Bolt automatically masks the
value before the plan is run.

To access the unmasked value, call the `unwrap` function on the parameter.

```
plan sensitive_task(
  Sensitive $password
) {
  $result = run_task('task_with_password', ..., 'password' => $password.unwrap)
  return($result)
}
```

Sensitive parameters are only masked if they use the un-parameterized or
parameterized `Sensitive` type, such as `Sensitive` or `Sensitive[Hash]`. Other
types, such as `Optional[Sensitive]` or `Hash[String, Sensitive]`, will not be
automatically masked.

## Returning results from plans

Use plans to return results that you can use in other plans or save for use
outside of Bolt.

Plans, unlike functions, are primarily run for side effects, but they can
optionally return a result. To return a result from a plan, use the `return`
function. Any plan that does not call the `return` function returns `undef`.

```
plan return_result(
  $targets
) {
  return run_task('mytask', $targets)
}
```

The result of a plan must match the `PlanResult` type alias. This roughly
includes JSON types as well as the plan language types which have well defined
JSON representations in Bolt.

-   `Undef`
-   `String`
-   `Numeric`
-   `Boolean`
-   `Target`
-   `Result`
-   `ResultSet`
-   `Error`
-   `Array` with only `PlanResult`
-   `Hash` with `String` keys and `PlanResult` values

or

```
Variant[Data, String, Numeric, Boolean, Error, Result, ResultSet, Target, Array[Boltlib::PlanResult], Hash[String, Boltlib::PlanResult]]

```

## Returning errors in plans

To return an error if your plan fails, call the `fail_plan` function.

Specify parameters to provide details about the failure.

For example, if called with `run_plan('mymodule::myplan')`, this would return an
error to the caller:

```
plan mymodule::myplan {
  fail_plan("Sorry, this plan does not work yet.", 'mymodule/error')
}
```

## Debugging plans

By default, Bolt does not print verbose logs for each plan execution to stdout.
However, you can use one of the following methods to investigate a plan
execution:

- Each time you run a Bolt command, Bolt prints a debug log to a
  `bolt-debug.log` file in the root of your project directory.
- You can use the `--verbose` CLI option for verbose logging to stdout.
- You can print a message to stdout and the `info` log level using the
  `out::message` function. 
- You can adjust your log level for detailed information on how Bolt is
  executing your plan.

### Using `out::message` to debug a plan

You can print a message, or a variable, to stdout and to the `info` log level
using the `out::message` function. If the variable contains a valid plan result,
Bolt formats the plan result using a JSON representation of the result object.
If the object is not a plan result, Bolt prints the object as a string.

To print a variable to stdout and the `info` log level with `out::message`, use
the following syntax:

```puppet
out::message($variable) 
```

For example, the following plan uses a `run_task` function to check targets for
the MySQL package and assigns the result to a variable called `$check_mysql`.
The plan uses `out::message($check_mysql)` to print the result set from
`$check_mysql` to stdout.

```puppet
plan website::test(
  TargetSpec $targets
) {
  $check_mysql = run_task('package', $targets, "Check for MySQL", {'action' => 'status', 'name' => 'mysql'})
  out::message($check_mysql)
}
```

The output from this plan looks something like this:

```console
Starting: plan website::test
Starting: Check for MySQL on target0
Finished: Check for MySQL with 0 failures in 0.76 sec
[
  {
    "target": "target0",
    "action": "task",
    "object": "package",
    "status": "success",
    "value": {
      "status": "uninstalled",
      "version": ""
    }
  }
]
Finished: plan website::test in 0.77 sec
Plan completed successfully with no result
```

### Debug logs

Bolt logs additional information about a plan run, including output sent to
standard error (stderr), at the `debug` level. Use the `--log-level debug` CLI
option or the [`log` configuration setting](bolt_project_reference.md#log).

```shell
$ bolt task run mytask param1=foo param2=bar -t all --log-level debug
```

Each time you run a Bolt command, Bolt prints a debug level log to a
`bolt-debug.log` file in the root of your project directory. You can disable the
log file by specifying the following in your `bolt-project.yaml`:

```yaml
log:
  bolt-debug.log: disable
```

## Success and failure in plans

If `upload_file`, `run_command`, `run_script`, or `run_task` are called without
the `_catch_errors` option and they fail on any targets, the plan itself fails.
To fail a plan directly, call the `fail_plan` function. Create an error with a
message and include the kind, details, or issue code, or pass an existing error
to it.

```
fail_plan('The plan is failing', 'mymodules/pear-shaped', {'failedtargets' => $result.error_set.names})
# or
fail_plan($errorobject)
```

### Catching errors in plans

Bolt includes a `catch_errors` function that executes a block of code and
returns the error if an error is raised, or returns the result of the block if
no errors are raised. You might get an `Error` object returned if you:
- call `run_plan` with `_catch_errors`.
- use a `catch_errors` block.
- call the `error` method on a result.

The `Error` data type includes:

-   `msg`: The error message string.
-   `kind`: A string that defines the kind of error similar to an error class.
-   `details`: A hash with details about the error from a task or from
    information about the state of a plan when it fails, for example,
    `exit_code` or `stack_trace`.
-   `issue_code`: A unique code for the message that can be used for
    translation.


Use the `Error` data type in a case expression to match against different kinds
of errors. To recover from certain errors, while failing on or ignoring others,
set up your plan to include conditionals based on errors that occur while your
plan runs. For example, you can set up a plan to retry a task when a timeout
error occurs, but to fail when there is an authentication error.

In the following example, the `mymodule::myplan` module runs a task and returns
a `ResultSet` object. The `handle_errors` plan calls it with `_catch_errors`,
extracts the `ResultSet` from the error if possible, and runs another task on
the successful targets.

```
plan mymodule::handle_errors {
  $result_or_error = run_plan('mymodule::myplan', '_catch_errors' => true)
  $result = case $result_or_error {
    # When the plan returned a ResultSet use it.
    ResultSet: { $result_or_error }
    # If the run_task failed extract the result set from the error.
    Error['bolt/run-failure'] : { $result_or_error.details['result_set'] }
    # The sub-plan failed for an unexpected reason.
    default : { fail_plan($result_or_error) } }
  # Run a task on the successful targets
  run_task('mymodule::task', $result.ok_set)
}
```

Using the `catch_errors` function:

```
plan test (String[1] $role) {
  $result_or_error = catch_errors(['bolt/puppetdb-error']) || {
    puppetdb_query("inventory[certname] { app_role == ${role} }")
  }
  $targets = if $result_or_error =~ Error {
    # If the PuppetDB query fails
    warning("Could not fetch from puppet. Using defaults instead")
    # TargetSpec string
    "all"
  } else {
    $result_or_error
  }
}
```

## Puppet and Ruby functions in plans

You can define and call [built-in Puppet
functions](https://puppet.com/docs/puppet/latest/function.html) and custom Ruby
functions in plans.

This is useful for packaging common general logic in your plan. You can also
call the plan functions, such as `run_task` or `run_plan`, from within a
function.

> 🔩 **Tip**: You can use any combination of [Bolt functions](plan_functions.md)
> or [built-in Puppet
> functions](https://puppet.com/docs/puppet/latest/function.html) in a plan.

Not all Puppet language constructs are allowed in plans. The following
constructs are not allowed:

-   Defined types
-   Classes
-   Resource expressions, such as `file { title: mode => '0777' }`
-   Resource default expressions, such as `File { mode => '0666' }`
-   Resource overrides, such as `File['/tmp/foo'] { mode => '0444' }`
-   Relationship operators: `-> <- ~> <~`
-   Functions that operate on a catalog: `contain`, `create_resources`,
    `include`, `realize`, `require`, `tag`, `tagged`
-   Collector expressions, such as `SomeType <| |>`, `SomeType <<| |>>`
-   ERB templates are not supported. Use EPP instead

Be aware of a few other Puppet behaviors in plans:

-   The `--strict_variables` option is on, so if you reference a variable that
    is not set, you get an error.
-   `--strict=error` is always on, so minor language issues generate errors. For
    example `{ a => 10, a => 20 }` is an error because there is a duplicate key
    in the hash.
-   Most Puppet settings are empty and not-configurable when using Bolt.
-   Logs include "source location" (file, line) instead of resource type or
    name.

## Handling plan function results

Plan execution functions each return a result object that returns details about
the execution.

Each [execution function](plan_functions.md#) returns an object type
`ResultSet`. For each target that the execution takes place on, this object
contains a `Result` object. The [apply action](applying_manifest_blocks.md#)
returns a `ResultSet` containing `ApplyResult` objects.

For information on the types returned from plan functions, see [Bolt data
types](bolt_types_reference.md).

An instance of `ResultSet` is `Iterable` as if it were an `Array[Variant[Result,
ApplyResult]]` so that iterative functions such as `each`, `map`, `reduce`, or
`filter` work directly on the `ResultSet` returning each result.

This example checks if a task ran correctly on all targets. If it did not, the
check fails:

```
$r = run_task('sometask', ..., '_catch_errors' => true)
unless $r.ok {
  fail("Running sometask failed on the targets ${r.error_set.names}")
}
```

You can do iteration and checking if the result is an Error. This example
outputs feedback about the result of a task:

```
$r = run_task('sometask', ..., '_catch_errors' => true)
$r.each |$result| {
  $target = $result.target.name
  if $result.ok {
    notice("${target} returned a value: ${result.value}")
  } else {
    notice("${target} errored with a message: ${result.error.message}")
  }
}
```

Similarly, you can iterate over the array of hashes returned by calling
`to_data` on a `ResultSet` and access hash values. For example:

```
$r = run_command('whoami', 'localhost,local://0.0.0.0')
$r.to_data.each |$result_hash| { notice($result_hash['result']['stdout']) }
```

You can also use `filter_set` to filter a `ResultSet` and apply a `ResultSet`
function such as `targets` to the output:

```
$filtered = $result.filter_set |$r| {
  $r['tag'] == "you're it"
}.targets
```

## Passing sensitive data to tasks

Task parameters defined as sensitive are masked when they appear in plans.

You define a task parameter as sensitive with the metadata property
`"sensitive": true`. When a task runs, the values for these sensitive parameters
are masked.

```
run_task('task_with_secrets', ..., 'password' => 'hunter2')
```

### Working with the `Sensitive` function

In Puppet you use the `Sensitive` function to mask data in output logs. Because
plans are written in Puppet DSL, you can use this type freely. The
`run_task()` function does not allow parameters of `Sensitive` function to be
passed. When you need to pass a sensitive value to a task, you must unwrap it
prior to calling `run_task()`.

```
$pass = Sensitive('hunter2')
run_task('task_with_secrets', ..., 'password' => $pass.unwrap)
```

📖 **Related information**  

- [Adding parameters to metadata](writing_tasks.md#)

## Target objects

The target object represents a target and its specific connection options.

The state of a target is stored in the inventory for the duration of a plan,
allowing you to collect facts or set variables for a target and retrieve them
later. You can get a printable representation via the `name` function, as well
as access components of the target: `protocol, host, port, user, password`. For
a list of functions available to a target, see [Bolt data
types](./bolt_types_reference.md#target) 

### `TargetSpec`

The `TargetSpec` type is a wrapper for defining targets that allows you to pass
a target, or multiple targets, into a plan. To ensure clean interaction with the
CLI and other plans, use this type for plans that accept a set of targets as a
parameter.

`TargetSpec` accepts a URI string, a target object, or an array of URI strings
and Target objects. URI strings must include a hostname, and can also set the
protocol, the username, the password, and the port to use using the format
`protocol://user:password@hostname:port`. 

To operate on individual targets, resolve `TargetSpec` to a list via
`get_targets`. For example, to loop over each target in a plan, accept a
`TargetSpec` argument, but call `get_targets` on it before looping.

```
plan loop(TargetSpec $targets) {
  get_targets($targets).each |$target| {
    run_task('my_task', $target)
  }
}
```

If your plan accepts a single `TargetSpec` parameter, you can call that
parameter `targets` so that it can be specified with the `--targets`
command-line option.

#### Example with `TargetSpec`

The following example shows two target parameters, `load_balancer` and
`webservers`, specified as data type `TargetSpec`.

The plan calls the `run_task` function, specifying which targets to run the
tasks on. The target names are collected and stored in `$webserver_names` by
iterating over the list of target objects returned by `get_targets`. Task
parameters are serialized to JSON format; therefore, extracting the names into
an array of strings ensures that the `webservers` parameter is in a format that
can be converted to JSON.

```
plan mymodule::my_plan(
  TargetSpec $load_balancer,
  TargetSpec $webservers,
) {

  # Extract the Target name from $webservers
  $webserver_names = get_targets($webservers).map |$n| { $n.name }
  
  # process webservers
  run_task('mymodule::lb_remove', $load_balancer, 'webservers' => $webserver_names)
  run_task('mymodule::update_frontend_app', $webservers, 'version' => '1.2.3')
  run_task('mymodule::lb_add', $load_balancer, 'webservers' => $webserver_names)
 }
```

To execute this plan from the command line, you would pass the parameters as
`<PARAMETER>=<VALUE>`. The `Targetspec` accepts either an array as JSON, or a
comma separated string of target names.

```
bolt plan run mymodule::myplan --modulepath ./PATH/TO/MODULES load_balancer=lb.myorg.com webservers='["kermit.myorg.com","gonzo.myorg.com"]'        
```

### Creating target objects

Creating target objects in a plan means they are part of the in-memory
inventory; they can be referenced and run alongside targets that are loaded from
the inventory file, but their data is not saved between plan runs. They only
exist for the life cycle of the plan run.

There are two main ways you might want to instantiate target objects within a
plan: getting a target that might already exist, or making a new target object
that clobbers any existing targets with the same name. 

To get or create a target, use the `get_target` function. This takes a single
URI and returns a single target object with the same name if it already exists
in the inventory, otherwise it will create the target and return it. Similarly
`get_targets` takes an array of URIs, gets or creates each target, and returns
an array of target objects. Some transport options can be [configured in the URI
string](https://puppet.com/docs/bolt/latest/configuring_bolt.html), but if this
isn't sufficient you can use
[set_config](https://puppet.com/docs/bolt/latest/plan_functions.html#set-config)
to set configuration options on the targets.

Use `Target.new()` to create a target that clobbers an existing target with the
same name. `Target.new()` takes a data hash with the same keys as [inventory
target
definitions](inventory_files.md#target-object).
You can use this to configure more options for the target than are available in
the URI alone, but it is a destructive action: if you try to create a target
with the same name as a target that already exists in the inventory (either from
in-memory or from the file), the old target will be completely destroyed and
replaced with the new target.

All new targets are added to the `all` inventory group, and no other groups. See
[modifying target objects](#modifying-target-objects) for information on
modifying group membership.

```
plan create_targets(
  TargetSpec $targetspecs
) {
  # Create a single Target object
  $target1 = get_target('ssh://user:password@myhostname.com:8022')
  $target2 = get_target('2hostname2handle')

  # Create an array of Target objects
  $target_list = get_targets(['host1', 'host2', 'hostred', 'hostblue'])
  # This also accepts TargetSpec objects
  $listy_list = get_targets($targetspecs)
  # And inventory group names
  $listerine = get_targets('all')

  # Create a Target object with options
  $opts_hash = {'uri' => 'myuri',
                'name' => 'nodename',
                'config' => {
                  'transport' => 'ssh',
                  'ssh' => {
                    'host-key-check' => false
                  }
                }
              }
  $with_opts = Target.new($opts_hash)

  # All of these target vars can be operated on
  run_command('hostname', $target1)
}
```

### Modifying target objects

There are a handful of functions available to modify existing target objects
inside a plan:

* [add_facts](https://puppet.com/docs/bolt/latest/plan_functions.html#add-facts)
* [add_to_group](https://puppet.com/docs/bolt/latest/plan_functions.html#add-to-group)
* [remove_from_group](https://puppet.com/docs/bolt/latest/plan_functions.html#remove-from-group)
* [set_config](https://puppet.com/docs/bolt/latest/plan_functions.html#set-config)
* [set_feature](https://puppet.com/docs/bolt/latest/plan_functions.html#set-feature)
* [set_var](https://puppet.com/docs/bolt/latest/plan_functions.html#set-var)

These can be used to add facts, transport specific configuration options,
features, and variables to target objects, as well as add or remove objects from
existing [inventory
groups](https://puppet.com/docs/bolt/latest/inventory_file.html). Targets are
modified in-memory for the life cycle of the plan and are not saved between plan
runs.

### Temporarily modifying target objects

Target objects can be temporarily modified during a plan run. For example, you
can store a target's configuration in a temporary variable, modify the target's
configuration using the [`set_config`](plan_functions.md#set-config) function,
and then restore the target's original configuration.

Temporarily modify a target's configuration:

```
plan test(String $host) {
  $target = get_target($host)

  # Store the target's original configuration
  $original_config = $target.config['ssh']

  # Modify the target's configuration
  $config =  {
    'user'     => 'bolt',
    'password' => 'secret'
  }

  set_config($target, 'ssh', $config)

  ...

  # Restore the target's original configuration
  set_config($target, 'ssh', $original_config)

  ...
}
```

### Variables and facts on targets

When Bolt runs, it loads transport configuration values, variables, and facts
from the inventory. These can be accessed with the `$target.facts()` and
`$target.vars()` functions. During the course of a plan, you can update the
facts or variables for any target. Facts usually come from running `facter` or
another fact collection application on the target, or from a fact store like
PuppetDB. Variables are computed externally or assigned directly.

Using the `facts` plan function does not automatically collect facts for a
target, and will only return facts that are currently set in the inventory. To
collect facts from a target and set them in the inventory, run the
[facts](#collect-facts-from-targets) plan or
[puppetdb_fact](#collect-facts-from-puppetdb) plan.

Set variables in a plan using `$target.set_var`:

```
plan vars(String $host) {
  $target = get_targets($host)[0]
  $target.set_var('newly_provisioned', true)
  $targetvars = $target.vars
  run_command("echo 'Vars for ${host}: ${$targetvars}'", $host)
}
```

Or set variables in the inventory file using the `vars` key at the group level.

```yaml
groups:
  - name: my_targets
    targets:
      - localhost
    vars:
      operatingsystem: windows
    config:
      transport: ssh
```

### Collect facts from the targets

The facts plan connects to the target and discovers facts. It stores these facts
on the targets in the inventory for later use.

The methods used to collect facts:

-   On `ssh` targets, it runs a Bash script.
-   On `winrm` targets, it runs a PowerShell script.
-   On `pcp` or targets where the Puppet agent is present, it runs Facter.

This example collects facts with the facts plan and uses those facts to decide
which task to run on the targets.

```
plan run_with_facts(TargetSpec $targets) {
  # This collects facts on targets and updates the inventory
  run_plan('facts', 'targets' => $targets)

  $centos_targets = get_targets($targets).filter |$n| { $n.facts['os']['name'] == 'CentOS' }
  $ubuntu_targets = get_targets($targets).filter |$n| { $n.facts['os']['name'] == 'Ubuntu' }
  run_task('centos_task', $centos_targets)
  run_task('ubuntu_task', $ubuntu_targets)
}
```

### Collect facts from PuppetDB

When targets are running a Puppet agent and sending facts to PuppetDB, you can
use the `puppetdb_fact` plan to collect facts for them. This example collects
facts with the `puppetdb_fact` plan, and uses those facts to decide which task
to run on the targets. You must configure the PuppetDB client before you run it.

```
plan run_with_facts(TargetSpec $targets) {
  # This collects facts on targets and update the inventory
  run_plan('puppetdb_fact', 'targets' => $targets)

  $centos_targets = get_targets($targets).filter |$n| { $n.facts['os']['name'] == 'CentOS' }
  $ubuntu_targets = get_targets($targets).filter |$n| { $n.facts['os']['name'] == 'Ubuntu' }
  run_task('centos_task', $centos_targets)
  run_task('ubuntu_task', $ubuntu_targets)
}
```

### Collect general data from PuppetDB

You can use the `puppetdb_query` function in plans to make direct queries to
PuppetDB. For example, you can discover targets from PuppetDB and run tasks on
them. You'll have to configure the PuppetDB client before running it. You can
learn how to structure Puppet Query Language (PQL) queries using [the PQL
tutorial](https://puppet.com/docs/puppetdb/latest/api/query/tutorial-pql.html).
For information, see [the PQL reference
guide](https://puppet.com/docs/puppetdb/latest/api/query/v4/pql.html).

```
plan pdb_discover {
  $result = puppetdb_query("inventory[certname] { app_role == 'web_server' }")
  # extract the certnames into an array
  $names = $result.map |$r| { $r["certname"] }
  # wrap in url. You can skip this if the default transport is pcp
  $targets = $names.map |$n| { "pcp://${n}" }
  run_task('my_task', $targets)
}
```

📖 **Related information**  

- [Connecting Bolt to PuppetDB](bolt_connect_puppetdb.md)

## Plan logging

Print message strings to stdout using the `out::message` plan function. This
function prints messages at the `info` level and always prints messages to
stdout regardless of the log level.

### Default action logging

Bolt logs actions that a plan takes on targets through the  `upload_file`,
 `run_command`, `run_script`, or `run_task` functions. By default, it logs
a notice level message when an action starts and another when it completes. If
you pass a description to the function, that is used in place of the generic log
message.

```
run_task('my_task', $targets, 'Better description', 'param1' => 'val')
```

If your plan contains many small actions, you might want to suppress these
messages and use explicit calls to the log functions instead. This can be
accomplished by wrapping actions in a `without_default_logging` block, which
causes the action messages to be logged at info level instead of notice. For
example to loop over a series of targets without logging each action:

```
plan deploy( TargetSpec $targets) {
  without_default_logging() || {
    get_targets($targets).each |$target| {
      run_task('deploy', $target)
    }
  }
}
```

To avoid complications with parser ambiguity, always
call `without_default_logging` with `()` and empty block args `||`.

```
without_default_logging() || { run_command('echo hi', $targets) }
```

not

```
without_default_logging { run_command('echo hi', $targets) }
```

For information on configuring log levels, see [Logs](logs.md).

### Log functions

Bolt ships with built-in functions for logging at each of Bolt's log levels.

| Log level | Plan function |
| --- | --- |
| `trace` | [`log::trace`](plan_functions.md#logtrace) |
| `debug` | [`log::debug`](plan_functions.md#logdebug) |
| `info` | [`log::info`](plan_functions.md#loginfo) |
| `warn` | [`log::warn`](plan_functions.md#logwarn) |
| `error` | [`log::error`](plan_functions.md#logtrace) |
| `fatal` | [`log::fatal`](plan_functions.md#logfatal) |

### Puppet log functions in Bolt

You can use Puppet log functions in Bolt plans, but Bolt log levels do not map
directly to Puppet log levels. For example, a `notice` function in a plan logs
at the `info` level in Bolt. Whenever possible, use Bolt log functions instead
of Puppet log functions. Log levels map as follows:

| Puppet log level | Bolt log level |
| --- | --- |
| `debug` | `trace` |
| `info` | `debug` |
| `notice` | `info` |
| `warning` | `warn` |
| `err` | `error` |
| `alert` | `error` |
| `emerg` | `fatal` |
| `crit` | `fatal` |

## Documenting plans

When writing plans, it's helpful to document what the plan does and the
parameters that it accepts. This information can be used in `bolt plan show`
output or in the Puppet Enterprise console to provide users with context
on how to run the plan.

Unlike tasks, plans do not have a corresponding
[metadata.json](writing_tasks.md#task-metadata) file. Instead, Bolt pulls
documentation directly from the plan using Puppet Types and [Puppet
Strings](https://puppet.com/docs/puppet/latest/puppet_strings.html).

### Plan description

You can add a description for a plan by adding a comment to the top of the
plan file. Each line of a comment begins with a `#` symbol.

```ruby
# This plan prints 'hello world' to the console.
plan hello_world () {
  out::message('hello world')
}
```

Running `bolt plan show hello_world` will display the plan's documentation,
which includes the plan's description:

```shell
$ bolt plan show hello_world

hello_world - This plan prints 'hello world' to the console.

USAGE:
bolt plan run hello_world

MODULE:
/Users/bolt/.puppetlabs/bolt
```

### Parameter names, types, and defaults

When a plan accepts parameters, the parameter's name and type are automatically
included in the plan's documentation. If a parameter has a default value, that
value will also be displayed in the documentation.

For example, the following plan accepts two parameters, one of which has a
default value:

```ruby
# This plan runs a single command on a group of targets.
plan single_command (
  TargetSpec $targets,
  String     $command = 'uptime'
) {
  $results = run_command($command, $targets)
  return $results
}
```

Running `bolt plan show single_command` will display the plan's documentation,
which includes the parameter names and types:

```shell
$ bolt plan show single_command

single_command - This plan runs a single command on a group of targets.

USAGE:
bolt plan run single_command targets=<value> [command=<value>]

PARAMETERS:
- targets: TargetSpec
- command: String
    Default: 'uptime'

MODULE:
/Users/bolt/.puppetlabs/bolt
```

### Parameter descriptions

You can add a description for a parameter using the `@param` Puppet Strings
tag in a comment at the top of the plan file. To add a description, begin the
comment with `@param`, followed by the name of the parameter and the
parameter's description.

```ruby
# This plan runs a single command on a group of targets.
# @param targets The list of targets to run the command on.
# @param command The command to run on the targets.
plan single_command (
  TargetSpec $targets,
  String     $command = 'uptime'
) {
  $results = run_command($command, $targets)
  return $results
}
```

Running `bolt plan show single_command` will display the plan's documentation,
which includes the parameter descriptions:

```shell
$ bolt plan show single_command

single_command - This plan runs a single command on a group of targets.

USAGE:
bolt plan run single_command targets=<value> [command=<value>]

PARAMETERS:
- targets: TargetSpec
    The list of targets to run the command on.
- command: String
    Default: 'uptime'
    The command to run on the targets.

MODULE:
/Users/bolt/.puppetlabs/bolt
```

## Making plans private

As a plan author, you might not want users to run your plan directly or know it exists. This is useful
for plans that are used by other plans 'under the hood', but aren't designed to be run by a human.
You can hide plans from `bolt plan show` and `Get-BoltPlan` output by specifying the `# @private
true` Puppet strings tag. Private plans are still viewable with `bolt plan show <PLAN NAME>` and
`Get-BoltPlan -Name <PLAN NAME>`, and can still be run with Bolt.

```
# This plan isn't shown in plan list output
# @private true
# @param targets The list of targets to run the command on.
plan single_command (
  TargetSpec $targets,
) {
  run_command("echo 'Strawberry rhubarb pie sounds so good right now'", $targets)
}
```

The `private` metadata is cached in your Bolt project. Bolt updates the cache:

- When you update plans in the current Bolt project.
- When you update modules in the `<PROJECT DIRECTORY>/modules/` directory.
- When you install modules using a Bolt command that installs modules.
- When you generate Puppet types using a `generate` command. 

If you manually edit a plan that is located outside of the `<PROJECT DIRECTORY>/plans/` directory or
`<PROJECT DIRECTORY>/modules/` path, Bolt might not pick up manual edits to metadata. If your plan
still appears in the output of `bolt plan show` and `Get-BoltPlan`, clear the metadata cache by
running with the `--clear-cache` flag.

## Example plans

Check out some examples for inspiration on writing your own plans.

### Beginner plans

These resources show simple use cases such as running a task and manipulating
the results.

- [facts module](https://forge.puppet.com/puppetlabs/facts): Contains tasks and
  plans to discover facts about target systems.
- [facts
  plan](https://github.com/puppetlabs/puppetlabs-facts/blob/master/plans/init.pp):
  Gathers facts using the facts task and sets the facts in inventory.
- [facts::info
  plan](https://github.com/puppetlabs/puppetlabs-facts/blob/master/plans/info.pp):
  Uses the facts task to discover facts and map relevant fact values to targets.

### Intermediate plans

These resources show more advanced features in the plan language.

- [reboot module](https://forge.puppet.com/puppetlabs/reboot): Contains tasks
  and plans for managing system reboots.
- [reboot
  plan](https://github.com/puppetlabs/puppetlabs-reboot/blob/master/plans/init.pp):
  Restarts a target system and waits for it to become available again.

### Advanced plans

These resources show more complex use cases such as applying puppet code blocks
and using external modules.

- [Introducing Masterless Puppet with
  Bolt](https://puppet.com/blog/introducing-masterless-puppet-bolt): Blog post
  explaining how plans can be used to deploy a load-balanced web server.
- [patching::deploy_scripts
  plan](https://github.com/EncoreTechnologies/puppet-patching/tree/master/plans/deploy_scripts.pp): Plan to deploy scripts from a Bolt controller to several targets using Puppet.
