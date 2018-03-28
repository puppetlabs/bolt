
# Writing plans

Plans allow you to run more than one task with a single command, or compute
values for the input to a task, or make decisions based on the result of
running a task.

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

Plan names must be unique. If there are two plans with the same name in a
module, the task runner won't load either of them.

The plan filename init is special: the plan it defines is referenced using the
module name only. For example, in a module called `mymodule`, the plan defined in
`init.pp` is the `mymodule` plan. Use this kind of naming sparingly, if at all, as
top named elements like this can clash with other constructs.

Do not give plans the same names as constructs in the Puppet language. Although
plans do not share their namespace with other language constructs, giving plans
these names makes your code difficult to read.

Each plan name segment must begin with a lowercase letter and:

- May include lowercase letters.
- May include digits.
- May include underscores.
- Must not use reserved words.
- Must not use the reserved extensions .md or .json.
- Must not have the same name as any Puppet data types.

Namespace segments must match the following regular expression
`\A[a-z][a-z0-9_]*\Z`


## Defining plan parameters

You can specify parameters in your plan.

Specify each parameter in your plan with its data type. For example, you might
want parameters to specify which nodes to run different parts of your plan on.

The following example shows node parameters specified as data type
`Variant[String[1], Array[String[1]]]`. For more information about these data
types, see the common data types table in the related metadata type topic.

This allows the user to pass, for each parameter, either a simple node name or
a URI that describes the protocol to use, the hostname, username and password.

The plan then calls the `run_task` function, specifying which nodes the tasks
should be run on.

```
plan mymodule::my_plan(
  String[1]                             $load_balancer,
  Variant[String[1], Array[String[1]]]  $frontends,
  Variant[String[1], Array[String[1]]]  $backends,
) {

  # process frontends
  run_task('mymodule::lb_remove', $load_balancer, frontends => $frontends)
  run_task('mymodule::update_frontend_app', $frontends, version => '1.2.3')
  run_task('mymodule::lb_add', $load_balancer, frontends => $frontends)
}
```

To execute this plan from the command line, pass the parameters as `parameter=value`:
```
bolt plan run mymodule::myplan --modulepath ./PATH/TO/MODULES --params '{"load_balancer":"lb.myorg.com","frontends":["kermit.myorg.com","gonzo.myorg.com"],"backends":["waldorf.myorg.com","statler.myorg.com"]}'
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

Add basic functions to your plan by calling the function with its data type and
arguments.

Basic functions in plans share a similar structure. Call these functions with
their data type and parameters.

`run_script`
Runs a script on one or more nodes.
`$fileref`, `$nodes`, `**$options`

`file_upload`
Uploads a file to a specified location on one or more nodes.
`$source`, `$destination`, `$nodes`, `$options`

`run_command`
Runs a command on one or more nodes.
`$cmd`, `$nodes`, `$options`

`get_targets`
Parses common ways of referring to targets and returns an Array of Target objects.
`TargetSpec $targetspec`

For the functions `run_script` and `file_upload`, the `$fileref` and `$source`
parameters accept either an absolute path or a module relative path, `<MODULE
NAME>/<FILE>` reference, which will search for `<FILE>` relative to a module's
files directory. For example, the reference `mysql/mysqltuner.pl` searches for
the file `<MODULES DIRECTORY>/mysql/files/mysqltuner.pl`.

Note that all the `$nodes` arguments support the patterns supported by `--nodes`
(except for shell expansion).

For example, to have your plan run the script located in
`./mymodule/files/my_script.sh` on a set of nodes, as follows. Note that these
functions will raise an exception and stop further execution of the plan if
they fail on any node. To prevent this and handle the error, pass the
`_catch_errrors => true` option to the command.

```
run_script("mymodule/my_script.sh", $nodes, 'catch_errors'=> true)
```

### Target objects

The Target object represents a node and its specific connection options. You
can get a printable representation via the name function, as well as access
components of the target: `protocol`, `host`, `port`, `user`, `password`. You can also
assign variables (`set_var`) to a target and get a list of existing variables the
target has (`target.vars`).

Set vars in a plan using `$target.set_var`.


```
plan vars(String $host) {
	$target = get_targets($host)[0]
	$target.set_var('operatingsystem', 'windows')
	$targetvars = $target.vars
	run_command("echo 'Vars for ${host}: ${$targetvars}'", $host)
}
```

Or set `vars` in the inventory file using the `vars` key at the group level.

```yaml
groups:
  - name: my_nodes
	nodes:
  	  - 'localhost'
	vars:
  	  operatingsystem: windows
	config:
  	  transport: ssh
```

The `TargetSpec` parameter is an abstract specification of targets that can
include the patterns allowed by `--nodes`, a single Target object, or an Array of
Targets (as returned by `get_targets`). Implemented as a type alias that matches
String (which may describe targets), Target, and Arrays of these. This is the
primary type to use when you want to accept a reference to one or more target
nodes. To operate on individual nodes, resolve it to a list via `get_targets`.


## Running tasks from plans

When you need to run multiple tasks, or you need some tasks to depend on
others, you can call the tasks from a task plan.

To run a task from your plan, call the `run_task` function, specifying the task
to run, any task parameters, and the nodes on which to run the task. Specify
the full task name, as `<MODULE>::<TASK>`.

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
The `bolt` command exits 0 and any calling plans continue execution. When a plan
is unsuccessful and you have reason to believe the caller should not continue
as normal, it fails with the `fail_plan` function. This causes the bolt command
to exit non-zero and prevents calling plans executing any further, unless
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

- message: The error message string.
- kind: A string that defines the kind of error.
- details: A hash with details about the error from a task or from information about the state of a plan when it fails, for example, exit_code or stack_trace.
- issue_code: A string that is a code for the error message.

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
- Facts are for the machine where the script or plan is running, not for the
  nodes on which the tasks are executed.
- Settings are for the machine where the script or plan is running.
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
- `find(target-name)`: Look up the Result for a specific target.
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
execution result.

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
