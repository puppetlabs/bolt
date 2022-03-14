# Debugging plans

By default, Bolt does not print the result for each step of a plan to standard
output (stdout). However, there are multiple ways to debug a Bolt plan.

To investigate a plan's execution:

- You can view the default debug log, which Bolt prints to each time you run a
  Bolt command.

- You can adjust your log level for detailed information on how Bolt is
  executing your plan, including the results returned from each step.

- You can print logs using built-in plan functions.

- You can print verbose output, which includes the results of each step in a
  plan, by running the plan in verbose mode.

- You can print any value or the result of any step to stdout using built-in
  plan functions.

## Logs

### Default debug log

Bolt logs additional information about a plan run, including output sent to
standard error (stderr), at the `debug` level. When you run a Bolt command, Bolt
automatically prints to a debug log named `bolt-debug.log`, located in the root
of your project. This log includes all messages printed at the `debug` level or
higher.

### Setting the log level

You can adjust the log level that Bolt prints at using the `log-level`
command-line option:

_\*nix shell command_

```shell
$ bolt plan run example --targets example.org --log-level trace
```

_PowerShell cmdlet_

```powershell
> Invoke-BoltPlan -Name example -Targets example.org -LogLevel trace
```

### Default action logging

Bolt logs actions that a plan takes on targets, such as running commands,
scripts, or tasks, or downloading or uploading files. By default, Bolt logs
an `info` level message when an action starts and another when it completes. If
you pass a description to the action, Bolt uses the description in place of the
generic log message.

_Puppet language plan_

```puppet
run_task('my_task', $targets, 'Better description', 'param1' => 'val')
```

_YAML plan_

```yaml
steps:
  - description: Better description
    task: my_task
    targets: $targets
    parameters:
      param1: val
```

If your plan contains many small actions, you might want to suppress these
messages and use explicit calls to log functions instead. You can accomplish
this by wrapping actions in a `without_default_logging` block in Puppet language
plans. For example, to loop over a series of targets without logging each
action:

```puppet
plan deploy( TargetSpec $targets) {
  without_default_logging() || {
    get_targets($targets).each |$target| {
      run_task('deploy', $target)
    }
  }
}
```

To avoid complications with parser ambiguity, always
call `without_default_logging` with `()` and empty block args `||`:

```puppet
without_default_logging() || { run_command('echo hi', $targets) }
```

Not:

```puppet
without_default_logging { run_command('echo hi', $targets) }
```

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

## Running in verbose mode

When you run a plan in verbose mode, Bolt automatically prints the results for
commands, scripts, tasks, and plans to stdout. To run in verbose mode, specify
the `verbose` command-line option:

_\*nix shell command_

```shell
$ bolt plan run example --targets example.org --verbose
```

_PowerShell cmdlet_

```powershell
> Invoke-BoltPlan -Name example -Targets example.org -Verbose
```

## Printing values

If you need to examine a value in a plan, you can print the value to stdout.
Both Puppet language plans and YAML plans support printing values. You can also
choose to always print values or only print values when running a plan in
verbose mode.

When you print a value that is a valid [plan
result](bolt_types_reference.md#planresult), Bolt formats and prints the value
as JSON. If the object is not a plan result, then Bolt prints the value as a
string.

### Printing values in Puppet language plans

To print values to stdout from a Puppet language plan, use the `out::message`
or `out::verbose` plan functions. 

To print a message every time the plan is run, use the `out::message` plan
function. When a message is printed using the `out::message` function, it is
also logged at the `info` level.

```puppet
plan example (
  TargetSpec $targets
) {
  $result = run_task('package', $targets, 'Check for MySQL',
    'action' => 'status',
    'name'   => 'mysql'
  )

  # Print the results of the task
  out::message($result)
}
```

To print a message only when running in verbose mode, use the `out::verbose`
plan fuction. When a message is printed using the `out::verbose` function, it is
also logged at the `debug` level.

```puppet
plan example (
  TargetSpec $targets
) {
  $result = run_task('package', $targets, 'Check for MySQL',
    'action' => 'status',
    'name'   => 'mysql'
  )

  # Print the results of the task
  out::verbose($result)
}
```

📖 **Related information**

- Using the [`out::message` plan function](plan_functions.md#outmessage).
- Using the [`out::verbose` plan function](plan_functions.md#outverbose).

### Printing values in YAML plans

You can print the result of a step to stdout by passing the step name
to a `message` or `verbose` step as a parameter.

To print a message every time the plan is run, use the `message` step. When a
message is printed using the `message` step, it is also logged at the `info`
level.

```yaml
parameters:
  targets:
    type: TargetSpec

steps:
  - name: check_mysql
    description: Check for MySQL
    targets: $targets
    task: package
    parameters:
      action: status
      name: mysql
  - message: $check_mysql
```

To print a message only when running in verbose mode, use `verbose` step. When a
message is printed using the `verbose` step, it is also logged at the `debug`
level.

```yaml
parameters:
  targets:
    type: TargetSpec

steps:
  - name: check_mysql
    description: Check for MySQL
    targets: $targets
    task: package
    parameters:
      action: status
      name: mysql
  - verbose: $check_mysql
```

📖 **Related information**

- Using the [`message` step](writing_yaml_plans.md#message-step).
- Using the [`verbose` step](writing_yaml_plans.md#verbose-step).
