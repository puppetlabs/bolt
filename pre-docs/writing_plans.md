# Writing plans

Plans allow you to run more than one task with a single command, compute values for the input to a task, process the results of tasks, or make decisions based on the result of running a task.

Write plans in the Puppet language, giving them a `.pp` extension, and place them in the module's `/plans` directory.

**Related information**  


[Plan execution functions and standard library](plan_functions.md#)
[Puppet functions available in plans](https://puppet.com/docs/puppet/6.1/function.html)

## Naming plans

Plan names are named based on the filename of the plan, the name of the module containing the plan, and the path to the plan within the module.

Write plan files in Puppet, give them the extension `.pp` , and place them in your module's `./plans` directory.

Plan names are composed of two or more name segments, indicating:

-   The name of the module the plan is located in.

-   The name of the plan file, without the extension.

-   The path within the module, if the plan is in a subdirectory of `./plans`.


For example, given a module called `mymodule` with a plan defined in `./mymodule/plans/myplan.pp`, the plan name is `mymodule::myplan`. A plan defined in `./mymodule/plans/service/myplan.pp`would be `mymodule::service::myplan`. This name is how you refer to the plan when you run commands.

The plan filename `init` is special: the plan it defines is referenced using the module name only. For example, in a module called `mymodule`, the plan defined in `init.pp` is the `mymodule` plan.

Avoid giving plans the same names as constructs in the Puppet language. Although plans do not share their namespace with other language constructs, giving plans these names makes your code difficult to read.

Each plan name segment must begin with a lowercase letter and:

-   May include lowercase letters.

-   May include digits.

-   May include underscores.

-   Must not be a [reserved word](https://docs.puppet.com/puppet/5.3/lang_reserved.html).

-   Must not have the same name as any Puppet data types.

-   Namespace segments must match the following regular expression `\A[a-z][a-z0-9_]*\Z`


## Defining plan parameters

You can specify parameters in your plan.

Specify each parameter in your plan with its data type. For example, you might want parameters to specify which nodes to run different parts of your plan on.

The following example shows node parameters specified as data type `TargetSpec`. This allows this parameter to be passed as a single URL, comma-separated URL list, Target data type or Array of either. For more information about these data types, see the common data types table in the related metadata type topic.

This allows the user to pass, for each parameter, either a simple node name or a URI that describes the protocol to use, the hostname, username and password.

The plan then calls the `run_task` function, specifying which nodes the tasks should be run on.

```
plan mymodule::my_plan(
  String[1] $load_balancer,
  TargetSpec  $frontends,
  TargetSpec  $backends,
) {

  # process frontends
  run_task('mymodule::lb_remove', $load_balancer, frontends => $frontends)
  run_task('mymodule::update_frontend_app', $frontends, version => '1.2.3')
  run_task('mymodule::lb_add', $load_balancer, frontends => $frontends)
}
```

To execute this plan from the command line, pass the parameters as `parameter=value`. The `Targetspec` will accept either an array as json or a comma separated string of target names.

```
bolt plan run mymodule::myplan --modulepath ./PATH/TO/MODULES --params load_balancer=lb.myorg.com frontends='["kermit.myorg.com","gonzo.myorg.com"]' backends=waldorf.myorg.com,statler.myorg.com

```

**Related information**  


[Task metadata types](writing_tasks.md#)

## Returning results from plans

Use plans to return results that you can use in other plans or save for use outside of Bolt.

Plans, unlike functions, are primarily run for side effects but they can optionally return a result. To return a result from a plan use the `return` function. Any plan that does not call the `return` function will return `undef`.

```
plan return_result(
  $nodes
) {
  return run_task('mytask', $nodes)
}
```

The result of a plan must match the `PlanResult` type alias. This roughly includes JSON types as well as the Plan language types which have well defined JSON representations in Bolt.

-    `Undef`
-    `String`
-    `Numeric`
-    `Boolean`
-    `Target`
-    `Result`
-    `ResultSet`
-    `Error`
-   `Array` with only `PlanResult`
-   Hash with `String` keys and `PlanResult` values

or

```
Variant[Data, String, Numeric, Boolean, Error, Result, ResultSet, Target, Array[Boltlib::PlanResult], Hash[String, Boltlib::PlanResult]]

```

## Returning errors in plans

To return an error if your plan fails, include an `Error` object in your plan.

Specify `Error` parameters to provide details about the failure.

For example, if called with `run_plan('mymodule::myplan')`, this would return an error to the caller.

```
plan mymodule::myplan {
  Error(
    message    => "Sorry, this plan does not work yet.",
    kind       => 'mymodule/error',
    issue_code => 'NOT_IMPLEMENTED'
    )
  }
```

## Success and failure in plans

Indicators that a plan has run successfully or failed.

Any plan that completes execution without an error is considered successful. The `bolt` command exits 0 and any calling plans continue execution. If any calls to `run_` functions fail without `_catch_errors` then the plan will halt execution and be considered a failure. Any calling plans will also halt until a `run_plan` call with `_catch_errors` is reached. If one isn't the `bolt` command will exit 2. When writing a plan if you have reason to believe it has failed you can fail the plan with the `fail_plan` function. This causes the bolt command to exit 2 and prevents calling plans executing any further, unless `run_plan` was called with `_catch_errors`.

### Failing plans

If `upload_file`, `run_command`, `run_script`, or `run_task` are called without the `_catch_errors` option and they fail on any nodes, the plan itself will fail. To fail a plan directly call the `fail_plan` function. Create a new error with a message and include the kind, details, or issue code, or pass an existing error to it.

```
fail_plan('The plan is failing', 'mymodules/pear-shaped', {'failednodes' => $result.error_set.names})
# or
fail_plan($errorobject)
```

### Responding to errors in plans

When you call `run_plan` with `_catch_errors` or call the `error` method on a result, you may get an error.

The `Error` data type includes:

-   `msg`: The error message string.

-   `kind`: A string that defines the kind of error similar to an error class.

-   `details`: A hash with details about the error from a task or from information about the state of a plan when it fails, for example, `exit_code` or `stack_trace`.

-   `issue_code`: A unique code for the message that can be used for translation.


Use the `Error` data type in a case expression to match against different kind of errors. To recover from certain errors, while failing on or ignoring others, set up your plan to include conditionals based on errors that occur while your plan runs. For example, you can set up a plan to retry a task when a timeout error occurs, but to fail when there is an authentication error.

Below, the first plan continues whether it succeeds or fails with a`mymodule/not-serious`error. Other errors cause the plan to fail.

```
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

This is useful for packaging common general logic in your plan. You can also call the plan functions, such as `run_task` or `run_plan`, from within a function.

Not all Puppet language constructs are allowed in plans. The following constructs are not allowed:

-   Defined types.

-   Classes.

-   Resource expressions, such as `file { title: mode => '0777' }`

-   Resource default expressions, such as `File { mode => '0666' }`

-   Resource overrides, such as `File['/tmp/foo'] { mode => '0444' }`

-   Relationship operators: `-> <- ~> <~`

-   Functions that operate on a catalog: `include`, `require`, `contain`, `create_resources`.

-   Collector expressions, such as `SomeType <| |>`, `SomeType <<| |>>`

-   ERB templates are not supported. Use EPP instead.


You should be aware of some other Puppet behaviors in plans:

-   The `--strict_variables` option is on, so if you reference a variable that is not set, you will get an error.

-   `--strict=error` is always on, so minor language issues generate errors. For example `{ a => 10, a => 20 }` is an error because there is a duplicate key in the hash.

-   Most Puppet settings are empty and not-configurable when using Bolt.

-   Logs include "source location" \(file, line\) instead of resource type or name.


## Handling plan function results

Plan execution functions each return a result object that returns details about the execution.

Each [execution function](plan_functions.md#) returns an object type `ResultSet`. For each node that the execution takes place on, this object contains a `Result` object. The [apply action](applying_manifest_blocks.md#) returns a `ResultSet` containing `ApplyResult` objects.

A `ResultSet` has the following methods:

-   `names()`: The `String` names \(node URIs\) of all nodes in the set as an `Array`.

-   `empty()`: Returns `Boolean` if the execution result set is empty.

-   `count()`: Returns an `Integer` count of nodes.

-   `first()`: The first `Result` object, useful to unwrap single results.

-   `find(String $target_name)`: Look up the `Result` for a specific target.

-   `error_set()`: A `ResultSet`containing only the results of failed nodes.

-   `ok_set()`: A `ResultSet` containing only the successful results.

-   `targets()`: An array of all the `Target` objects from every `Result`in the set.

-   `ok():``Boolean` that is the same as `error_nodes.empty`.


A `Result` has the following methods:

-   `value()`: The hash containing the value of the `Result`.

-   `target()`: The `Target` object that the `Result` is from.

-   `error()`: An `Error` object constructed from the `_error` in the value.

-   `message()`: The `_output` key from the value.

-   `ok()`: Returns `true` if the `Result` was successful.

-   `[]`: Accesses the value hash directly.


An `ApplyResult` has the following methods:

-   `report()`: The hash containing the Puppet report from the application.

-   `target()`: The `Target` object that the `Result` is from.

-   `error()`: An `Error` object constructed from the `_error` in the value.

-   `ok()`: Returns `true` if the `Result` was successful.


An instance of `ResultSet` is `Iterable` as if it were an `Array[Variant[Result, ApplyResult]]` so that iterative functions such as `each`, `map`, `reduce`, or `filter` work directly on the ResultSet returning each result.

This example checks if a task ran correctly on all nodes. If it did not, the check fails:

```
$r = run_task('sometask', ..., '_catch_errors' => true)
unless $r.ok {
  fail("Running sometask failed on the nodes ${r.error_nodes.names}")
}
```

You can do iteration and checking if the result is an Error. This example outputs some simple feedback about the result of a task:

```
$r = run_task('sometask', ..., '_catch_errors' => true)
$r.each |$result| {
  $node = $result.target.name
  if $result.ok {
    notice("${node} returned a value: ${result.value}")
  } else {
    notice("${node} errored with a message: ${result.error.message}")
  }
}
```

## Passing sensitive data to tasks

Task parameters defined as sensitive are masked when they appear in plans.

You define a task parameter as sensitive with the metadata property `"sensitive": true`. When a task runs, the values for these sensitive parameters are masked.

```
run_task('task_with_secrets', ..., password => '$ecret!')
```

### Working with the sensitive function

In Puppet you use the `Sensitive` function to mask data in output logs. Since plans are written in Puppet DSL you can use this type freely. The `run_task()` function does not allow parameters of `Sensitive` function to be passed. When you need to pass a sensitive value to a task, you must unwrap it prior to calling `run_task()`.

```
$pass = Sensitive('$ecret!')
run_task('task_with_secrets', ..., password => $pass.unwrap)

```

**Related information**  


[Adding parameters to metadata](writing_tasks.md#)

## Target objects

The `Target` object represents a node and its specific connection options.

The state of a target is stored in the inventory for the duration of a plan allowing you to collect facts or set vars for a target and retrieve them later. You can get a printable representation via the `name` function, as well as access components of the target: `protocol, host, port, user, password`.

### TargetSpec

The execution function take a parameter with the type alias TargetSpec. This alias accepts the pattern strings allowed by `--nodes`, a single Target object, or an Array of Targets and node patterns. Plans that accept a set of targets as a parameter should generally use this type to interact cleanly with the CLI and other plans. To operate on individual nodes, resolve it to a list via `get_targets`. For example to loop over each node in a plan accept a `TargetSpec` argument but call `get_targets `on it before looping.

```
plan loop(TargetSpec $nodes) {
  get_targets($nodes).each |$target| {
    run_task('my_task', $target)
  }
}
```

If your plan accepts a single `TargetSpec` parameter you can call that parameter `nodes` so that it can be specified with the `--nodes` flag from the command line.

### Variables and facts on targets

When Bolt runs, it loads transport config values, variables, and facts from the inventory. These can be accessed with the `$target.facts()` and `$target.vars()` functions. During the course of a plan, you can update the facts or variables for any target. Facts usually come from running `facter` or another fact collection application on the target or from a fact store like PuppetDB. Variables are computed externally or assigned directly.

Set variables in a plan using `$target.set_var`:

```
plan vars(String $host) {
	$target = get_targets($host)[0]
	$target.set_var('newly_provisioned', true)
	$targetvars = $target.vars
	run_command("echo 'Vars for ${host}: ${$targetvars}'", $host)
}

```

Or set variables in the inventory file using the `vars` key at the group level.

```
groups:
  - name: my_nodes
    nodes:
      - localhost
    vars:
      operatingsystem: windows
    config:
      transport: ssh
```

### Collect facts from the targets

The facts plan connects to the target and discovers facts. It then stores these facts on the targets in the inventory for later use.

The methods used to collect facts:

-   On `ssh` targets it runs a simple bash script.
-   On `winrm` targets it runs a simple PowerShell script.
-   On `pcp` or targets where the puppet agent is present, it runs facter.

This example collects facts with the facts plan and then uses those facts to decide which task to run on the targets.

```
plan run_with_facts(TargetSpec $nodes) {
  # This will collect facts on nodes and update the inventory
  run_plan(facts, nodes => $nodes)

  $centos_nodes = get_targets($nodes).filter |$n| { $n.facts['os']['name'] == 'CentOS' }
  $ubuntu_nodes = get_targets($nodes).filter |$n| { $n.facts['os']['name'] == 'Ubuntu' }
  run_task(centos_task, $centos_nodes)
  run_task(ubuntu_task, $ubuntu_nodes)
}
```

### Collect facts from PuppetDB

When targets are running a Puppet agent and sending facts to PuppetDB, you can use the `puppetdb_fact` plan to collect facts for them. This example collects facts with the `puppetdb_fact` plan, and then uses those facts to decide which task to run on the targets. You must configure the PuppetDB client before you run it.

```
plan run_with_facts(TargetSpec $nodes) {
  # This will collect facts on nodes and update the inventory
  run_plan(**puppetdb\_fact**, nodes => $nodes)

  $centos_nodes = get_targets($nodes).filter |$n| { $n.facts['os']['name'] == 'CentOS' }
  $ubuntu_nodes = get_targets($nodes).filter |$n| { $n.facts['os']['name'] == 'Ubuntu' }
  run_task(centos_task, $centos_nodes)
  run_task(ubuntu_task, $ubuntu_nodes)
}
```

**Related information**  


[Connecting Bolt to PuppetDB](bolt_connect_puppetdb.md)

## Plan logging

Set up log files to record certain events that occur when you run plans.

### Puppet log functions

To generate log messages from a plan, use the Puppet log function that corresponds to the level you want to track: `error`, `warn`, `notice`, `info`, or `debug`. The default log level for Bolt is `notice` but you can set it to `info` with the `--verbose `flag or `debug` with the `--debug` flag.

### Default action logging

Bolt logs actions that a plan takes on targets through the  `upload_file`,  `run_command`, `run_script`, or `run_task`  functions. By default it logs a notice level message when an action starts and another when it completes. If you pass a description to the function, that will be used in place of the generic log message.

```
run_task(my_task, $targets, "Better description", param1 => "val")
```

If your plan contains many small actions you may want to suppress these messages and use explicit calls to the Puppet log functions instead. This can be accomplished by wrapping actions in a `without_default_logging` block which will cause the action messages to be logged at info level instead of notice. For example to loop over a series of nodes without logging each action.

```
plan deploy( TargetSpec $nodes) {
  without_default_logging() || {
    get_targets($nodes).each |$node| {
      run_task(deploy, $node)
    }
  }
}

```

To avoid complications with parser ambiguity, always call `without_default_logging` with `()` and empty block args `||`.

```
without_default_logging() || { run_command('echo hi', $nodes) }
```

not

```
without_default_logging { run_command('echo hi', $nodes) }
```

### puppetdb\_query



You can use the `puppetdb_query` function in plans to make direct queries to PuppetDB. For example you can discover nodes from PuppetDB and then run tasks on them. You'll have to configure the [puppetdb client](bolt_connect_puppetdb.md)before running it. You can learn how to [structure pql queries here](https://puppet.com/docs/puppetdb/latest/api/query/tutorial-pql.html), and find [pql reference and examples here](https://puppet.com/docs/puppetdb/latest/api/query/v4/pql.html)

```
plan pdb_discover {
  $result = puppetdb_query("inventory[certname] { app_role == 'web_server' }")
  # extract the certnames into an array
  $names = $result.map |$r| { $r["certname"] }
  # wrap in url. You can skip this if the default transport is pcp
  $nodes = $names.map |$n| { "pcp://${n}" }
  run_task('my_task', $nodes)
}
```

