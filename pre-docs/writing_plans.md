
# Writing plans

Plans allow you to run more than one task with a single command, compute values
for the input to a task, process the results of tasks, or make decisions based
  on the result of running a task.

Write plans in the Puppet language, giving them a .pp extension, and place them
in the module's `/plans` directory.


## Naming plans

Plan names are named based on the filename of the plan, the name of the module
containing the plan, and the path to the plan within the module.

Write plan files in Puppet, give them the extension `.pp` , and place them in
your module's `./plans` directory.

Plan names are composed of two or more name segments, indicating:
- The name of the module the plan is located in.
- The name of the plan file, without the extension.
- The path within the module, if the plan is in a subdirectory of ./plans.

For example, given a module called mymodule with a plan defined in
`./mymodule/plans/myplan.pp`, the plan name is `mymodule::myplan`. A plan defined
in `./mymodule/plans/service/myplan.pp` would be `mymodule::service::myplan`. This
name is how you refer to the plan when you run commands.

The plan filename init is special: the plan it defines is referenced using the
module name only. For example, in a module called `mymodule`, the plan defined in
`init.pp` is the `mymodule` plan.

Avoid giving plans the same names as constructs in the Puppet language. Although
plans do not share their namespace with other language constructs, giving plans
these names makes your code difficult to read.

Each plan name segment must begin with a lowercase letter and:

- May include lowercase letters.
- May include digits.
- May include underscores.
- Must not be a reserved word.
- Must not have the same name as any Puppet data types.

Namespace segments must match the following regular expression
`\A[a-z][a-z0-9_]*\Z`


## Defining plan parameters

You can specify parameters in your plan.

Specify each parameter in your plan with its data type. For example, you might
want parameters to specify which nodes to run different parts of your plan on.

The following example shows node parameters specified as data type
`TargetSpec`. This allows this parameter to be passed as a single url, comma
seperated url list, Target data type, or Array of either. For more information
about these data types, see the common data types table in the related metadata
type topic.

This allows the user to pass, for each parameter, either a simple node name or
a URI that describes the protocol to use, the hostname, username and password.

The plan then calls the `run_task` function, specifying which nodes the tasks
should be run on.

```
plan mymodule::my_plan(
  String[1]  $load_balancer,
  TargetSpec $frontends,
  TargetSpec $backends,
) {

  # process frontends
  run_task('mymodule::lb_remove', $load_balancer, frontends => $frontends)
  run_task('mymodule::update_frontend_app', $frontends, version => '1.2.3')
  run_task('mymodule::lb_add', $load_balancer, frontends => $frontends)
}
```

To execute this plan from the command line, pass the parameters as
`parameter=value`. The Targetspec will accept either an array as json
or a comma seperated string of target names.

```
bolt plan run mymodule::myplan --modulepath ./PATH/TO/MODULES --params load_balancer=lb.myorg.com frontends='["kermit.myorg.com","gonzo.myorg.com"]' backends=waldorf.myorg.com,statler.myorg.com
```

## Returning results from plans

> Plans can optionally return a result that can be used from other plans or
> saved externally.

Plans, unlike functions, are primarily run for side effects but they can
optionally return a result. To return a result from a plan use the `return`
function. Any plan that does not call the `return` function will return
`undef`.

```puppet
plan return_result(
  $nodes
) {
  return run_task('mytask', $nodes)
}
```

The result of a plan must match the `PlanResult` type alias. This roughly
includes JSON types as well as the Plan lanuguage types which have well defined
json representations in Bolt.

- `Undef`
- `String`
- `Numeric`
- `Boolean`
- `Target`
- `Result`
- `ResultSet`
- `Error`
- `Array` with only `PlanResult`
- `Hash` with `String` keys and `PlanResult` values

or

```
Variant[Data, String, Numeric, Boolean, Error, Result, ResultSet, Target, Array[Boltlib::PlanResult], Hash[String, Boltlib::PlanResult]]
```


## Plan execution functions
Your plan can execute multiple functions on remote systems.

Your plan can include functions to run commands, scripts, tasks, and other
plans on remote nodes. These execution functions correspond to task runner
commands.

- `run_command`: Runs a command on one or more nodes.
- `run_script`: Runs a script (a non-task executable) on one or more nodes.
- `run_task`: Runs a task on one or more nodes.
- `run_plan`: Runs a plan on one or more nodes.
- `file_upload`: Uploads a file to one or more nodes.


### Calling basic plan functions

Basic functions in plans share a similar structure. Call these functions with their parameters.

`run_script`
Runs a script on one or more nodes.
`$fileref`, `$nodes`, `$description`, `$options`

`file_upload`
Uploads a file to a specified location on one or more nodes. Note that most transports are not
optimized for file copying, so this is best limited to small files.
`$source`, `$destination`, `$nodes`, `$description`, `$options`

`run_command`
Runs a command on one or more nodes.
`$cmd`, `$nodes`, `$description`, `$options`

`get_targets`
Parses common ways of referring to targets and returns an Array of Target objects.
`TargetSpec $targetspec`

For the functions `run_script` and `file_upload`, the `$fileref` and `$source`
parameters accept either an absolute path or a module relative path, `<MODULE
NAME>/<FILE>` reference, which will search for `<FILE>` relative to a module's
files directory. For example, the reference `mysql/mysqltuner.pl` searches for
the file `<MODULES DIRECTORY>/mysql/files/mysqltuner.pl`.

The `$options` parameter is used for options that modify how Bolt executes the function. For `run_script`, arguments to the script can be passed as an array of strings under an `arguments` key in `$options`.

Note that all the `$nodes` arguments support the patterns supported by `--nodes`
(except for shell expansion).

The `$description` parameter is always optional. It can be used to provide a description of the intent behind running the function that will be included in logging. The `pcp` transport in particular passes this on to Orchestrator when running tasks.

For example, to have your plan run the script located in
`./mymodule/files/my_script.sh` on a set of nodes, as follows. Note that these
functions will raise an exception and stop further execution of the plan if
they fail on any node. To prevent this and handle the error, pass the
`_catch_errors => true` option to the command.

```
run_script("mymodule/my_script.sh", $nodes, '_catch_errors'=> true)
```

## Running tasks from plans

When you need to run multiple tasks, or you need some tasks to depend on
others, you can call the tasks from a task plan.

To run a task from your plan, call the `run_task` function, specifying `$task_name`, `$nodes`, `$description`, `$parameters`. Specify
the full task name, as `<MODULE>::<TASK>`. Parameters are supplied as a hash of parameter name to value, and can also include anything that would be passed in `$options` for other functions.

For example, the following plan runs several tasks, each on a different set of
nodes. Note that `run_task` raises an exception and stops further execution of
the plan if it fails on any node. To prevent this and handle the error, pass
the `_catch_errrors => true` option to the command.

```puppet
# If this task errors, the plan will continue to execute.
run_task('mymodule::lb_remove', $load_balancer, nodes => $frontends, '_catch_errors' => true)
# If the following task errors on any nodes, the plan will stop executing.
run_task('mymodule::update_frontend_app', $frontends, version => '1.2.3')
run_task('mymodule::lb_add', $load_balancer, nodes => $frontends)
```

### Running plans in a plan

Use your plan to run another plan. Write reusable chunks of plan logic and run
them directly with the bolt command or from another plan.

Use the function `run_plan` to run a plan from within another plan. This function
accepts the name of the plan to run and a hash of arguments and options to the
plan.

This example plan, `mymodule::update_everything`, runs the plan `mymodule::myplan`,
and passes the necessary parameter values to it.

```puppet
plan mymodule::update_everything {
  run_plan('mymodule::myplan',
    load_balancer => 'lb.myorg.com',
    frontends => ['kermit.myorg.com', 'gonzo.myorg.com'],
    backends => ['waldorf.myorg.com', 'statler.myorg.com' ])
}
```

If `mymodule::myplan` fails `mymodule::update_everything` will stop executing at
that point. To catch the error in myplan and handle it, pass the option
`_catch_errors => true` to `run_plan`. This will return an error if it fails.

```puppet
plan mymodule::update_everything {
  $r = run_plan('mymodule::myplan',
    _catch_errors => true,
    load_balancer => 'lb.myorg.com',
    frontends => ['kermit.myorg.com', 'gonzo.myorg.com'],
    backends => ['waldorf.myorg.com', 'statler.myorg.com' ])
  if($r =~ Error) {
    notice("myplan failed: ${r.message}")
  } else {
    notice("myplan succeeded")
  }
}
```

## Success and failure in plans

Indicators that a plan has run successfully or failed.

Any plan that completes execution without an error is considered successful.
The `bolt` command exits 0 and any calling plans continue execution. If any
calls to `run_` functions fail without `_catch_errors` then the plan will halt
execution and be considered a failure. Any calling plans will also halt until a
`run_plan` call with `_catch_errors` is reached. If one isn't the `bolt`
command will exit 2. When writing a plan if you have reason to believe it has
failed you can fail the plan with the `fail_plan` function. This causes the
bolt command to exit 2 and prevents calling plans executing any further, unless
`run_plan` was called with `_catch_errors`.

### Failing plans

If `file_upload`, `run_command`, `run_script`, or `run_task` are called without the
`_catch_errors` option and they fail on any nodes, the plan itself will fail. To
fail a plan directly call the `fail_plan` function. Create a new error with a
message and include the `kind`, `details`, or `issue code`, or pass an existing error
to it.

```puppet
fail_plan('The plan is failing', 'mymodules/pear-shaped', {'failednodes' => $result.error_set.names})
# or
fail_plan($errorobject)
```


### Responding to errors in plans

When you call `run_plan` with `_catch_errors` or call the error method on a result,
you may get an error.

The `Error` data type includes:

- msg: The error message string.
- kind: A string that defines the kind of error similar to an error class..
- details: A hash with details about the error from a task or from information about the state of a plan when it fails, for example, exit_code or stack_trace.
- issue_code: A unique code for the message that can be used for translation.

Use the `Error` data type in a case expression to match against different kind of
errors. To recover from certain errors, while failing on or ignoring others,
set up your plan to include conditionals based on errors that occur while your
plan runs. For example, you can set up a plan to retry a task when a timeout
error occurs, but to fail when there is an authentication error.

Below, the first plan continues whether it succeeds or fails with a
`mymodule/not-serious` error. Other errors cause the plan to fail.

```puppet
plan mymodule::handle_errors {
  $result = run_plan('mymodule::myplan', '_catch_errors' => true)
  case $result {
    Error['mymodule/not-serious'] : {
      notice("${result.message}")
    }
    Error : { fail_plan($result) } }
  run_plan('mymodule::plan2')
}
```

## Puppet and Ruby functions in plans

You can define and call Puppet language and Ruby functions in plans.

This is useful for packaging common general logic in your plan. You can also
call the plan functions, such as `run_task` or `run_plan`, from within a function.

Not all Puppet language constructs are allowed in plans. The following constructs are not allowed:

- Defined types.
- Classes.
- Resource expressions, such as file { title: mode => '0777' }
- Resource default expressions, such as File { mode => '0666' }
- Resource overrides, such as File['/tmp/foo'] { mode => '0444' }
- Relationship operators: -> <- ~> <~
- Functions that operate on a catalog: include, require, contain, create_resources.
- Collector expressions, such as SomeType <| |>, SomeType <<| |>>
- ERB templates are not supported. Use EPP instead.

You should be aware of some other Puppet behaviors in plans:

- The `--strict_variables` option is on, so if you reference a variable that is not set, you will get an error.
- `--strict=error` is always on, so minor language issues generate errors. For
  example `{ a => 10, a => 20 }` is an error because there is a duplicate key
  in the hash.
  nodes on which the tasks are executed.
- Most Puppet settings are empty and not-configurable when using bolt.
- Logs include "source location" (file, line) instead of resource type or name.


## Handling plan function results

Plan execution functions each return a result object that returns details about
the execution.

Each execution function returns an object type `ResultSet`. For each node that
the execution takes place on, this object contains a `Result` object.

A `ResultSet` has the following methods:
- `names()`: The String names (node URIs) of all nodes in the set as an Array.
- `empty()`: Returns Boolean if the execution result set is empty.
- `count()`: Returns an Integer count of nodes.
- `first()`: The first Result object, useful to unwrap single results.
- `find(String $target_name)`: Look up the Result for a specific target.
- `error_set()`: A ResultSet containing only the results of failed nodes.
- `ok_set()`: A ResultSet containing only the sucessful results.
- `targets()`: An array of all the Target objects from every Result in the set.
- `ok()`: Boolean that is the same as error_nodes.empty.

A `Result` has the following methods:
- `value()`: The hash containing the value of the Result.
- `target()`: The Target object that the Result is from.
- `error()`: An Error object constructed from the _error in the value.
- `message()`: The _output key from the value.
- `ok()`: Returns true if the Result was successful.
- `[]`: Accesses the value hash directly.

An instance of `ResultSet` is `Iterable` as if it were an `Array[Result]` so that
iterative functions such as `each`, `map`, `reduce`, or `filter` work directly on the
ResultSet returning each result.

This example checks if a task ran correctly on all nodes. If it did not, the
check fails:

```puppet
$r = run_task('sometask', ..., '_catch_errors' => true)
unless $r.ok {
  fail("Running sometask failed on the nodes ${r.error_nodes.names}")
}
```

You can do iteration and checking if the result is an Error. This example
outputs some simple feedback about the result of a task:
```puppet
$r = run_task('sometask', ..., '_catch_errors' => true)
$r.each |$result| {
  $node = $result.target.name
  if $result.ok {
    notice("${node} errored with a message: ${result.error.message}")
  } else {
   notice("${node} returned a value: ${result.value}")
  }
}
```

## Target objects

The Target object represents a node and its specific connection options. The
state of a target is stored in the inventory for the duration of a plan allowing
you to collect facts or set vars for a target and retrieve them later.
You can get a printable representation via the name function, as well as access
components of the target: `protocol`, `host`, `port`, `user`, `password`.

### `TargetSpec`

The execution function take a parameter with the type alias TargetSpec. This
alias accepts the pattern strings allowed by `--nodes`, a single Target object,
or an Array of Targets and node patterns. Plans that accept a set of targets as
a parameter should generally use this type to interact cleanly with the CLI and
other plans. To operate on individual nodes, resolve it to a list via
`get_targets`. For example to loop over each node in a plan accept a
`TargetSpec` argument but call `get_targets` on it before looping.

```puppet
plan loop(TargetSpec $nodes) {
  get_targets($nodes).each |$target| {
    run_task('my_task', $target)
  }
}
```

If your plan accepts a single `TargetSpec` parameter you can call that
parameter `nodes` so that it can be specified with the `--nodes` flag from the
cli.

### Variables and Facts on Targets

When bolt runs it loads transport config values, variables, and facts from
the inventory.  These can be accessed with the `$target.facts()` and
`$target.vars()` functions. During the course of a plan you can update the
facts or vars for any target. In general Facts are observed about the state of
a node while `vars` are more general information. Facts will usually come from
running `facter` or another fact collection application on the target or be
looked up from a fact store like Puppetdb. `vars` are computed externally or
assigned directly.


Set vars in a plan using `$target.set_var`.

```
plan vars(String $host) {
	$target = get_targets($host)[0]
	$target.set_var('newly_provisioned', true)
	$targetvars = $target.vars
	run_command("echo 'Vars for ${host}: ${$targetvars}'", $host)
}
```

Or set `vars` in the inventory file using the `vars` key at the group level.

```yaml
---
groups:
  - name: my_nodes
    nodes:
      - localhost
    vars:
      operatingsystem: windows
    config:
      transport: ssh
```

Collect facts with the `fact` plan and filter nodes based on them.

```puppet
plan run_with_facts(TargetSpec $nodes) {
  # This will collect facts on nodes and update the inventory
  run_plan(facts, nodes => $nodes)

  $centos_nodes = get_targets($nodes).filter |$n| { $n.facts['os']['name'] == 'CentOS' }
  $ubuntu_nodes = get_targets($nodes).filter |$n| { $n.facts['os']['name' == 'Ubuntu' }
  run_task(centos_task, $centos_nodes)
  run_task(ubuntu_task, $ubuntu_nodes)
}
```

## Plan Logging

### Puppet log functions

To generate log messages from a plan use the puppet log function corresponding
to the level you want to log at. `error`, `warn`, `notice`, `info`, or `debug`.
The default log level for bolt is `notice` but can be set to `info` with the
`--verbose` flag or `debug` with the `--debug` flag.

### Default Action Logging

Bolt logs actions that a plan takes on targets through the `file_upload`,
`run_command`, `run_script` or `run_task` functions. By default it will log a
`notice` level message when an action starts and another when it completes. If
you pass a description to the function that will be used in place of the
generic log message.

```
run_task(my_task, $targets, "Better description", param1 => "val")
```

If your plan contains many small actions you may want to suppress these messages
and use explicit calls to the puppet log functions instead. This can be
accomplished by wrapping actions in a `without_default_logging` block which
will cause the action messages to be logged at `info` level instead of
`notice`. For example to loop over a series of nodes without logging each action.

```puppet
plan deploy( TargetSpec $nodes) {
  without_default_logging() || {
    get_targets($nodes).each |$node| {
      run_task(deploy, $node)
    }
  }
}
```

To avoid complications with parser ambiguity always call
`without_default_logging` with `()` and empty block args `||`.

```puppet
without_default_logging() || { run_command('echo hi', $nodes) }
```
not

```puppet
without_default_logging { run_command('echo hi', $nodes) }
```
