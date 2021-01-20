# Logs

Bolt supports multiple log levels. You can configure the log level from the CLI,
or in a project configuration file. Supported logging levels, in order from most
to least information logged, are `trace`, `debug`, `info`, `warn`, `error`, and
`fatal`.

By default, Bolt logs a debug-level log to a `bolt-debug.log` file in the root
of your project directory. You can also configure custom logs from your project
configuration file.

## The `bolt-debug.log` file
 
Each time you run a Bolt command, Bolt prints a debug-level log to a
`bolt-debug.log` file in the root of your project directory.

You can disable the log file by specifying the following in your
`bolt-project.yaml` file:

```yaml
log:
  bolt-debug.log: disable
```

## Setting log level

You can set Bolt's log level from the CLI or use a
configuration file.

### Setting log level on the CLI

To set the log level from the CLI, use the `log-level` option along with the
desired level. Available log levels are `trace`, `debug`, `info`, `warn`,
`error`, and `fatal`. For example:

- _\*nix shell command_

  ```shell
  bolt command run whoami -t target1 --log-level trace
  ```

- _PowerShell cmdlet_

  ```powershell
  Invoke-BoltCommand -Command whoami -Targets target1 -LogLevel trace
  ```

### Setting log level in a configuration file

To set the log level for the console, add a `log` map with a `console` mapping
to your [project configuration file](configuring_bolt.md#project-level-configuration).

Use the `level` key to set the log level. For example:

```yaml
# bolt-project.yaml
name: lotsalogs

log:
  console:
    level: debug
```

If you want to write a log to a file, add a map with the file destination to the
log mapping. For example, the following `bolt-project.yaml` file writes `info`
and `trace` level logs to a `logs` directory in the Bolt project:

```yaml
# bolt-project.yaml
name: lotsalogs

log:
  "logs/trace.log":
    append: false
    level: trace
  "logs/info.log":
    append: false
    level: info
```

Set the `append` key to `false` if you want to overwrite the file on each run,
or `true` if you want to append to the existing file.
 
> **Note**: The directory you set for logging must exist, and Bolt must have
> permission to write to it.

## Log levels

### `trace`

Trace logs contain the most detailed information for actions run on individual
targets. For example, the logs include each command run on a target, each step
of compiling a puppet code file (manifest) for an apply block, and information about establishing
connections with targets.

Trace logs are useful when you're trying to troubleshoot a problem with Bolt.
They contain information about what exactly Bolt is doing when it runs an action
on each target.

### `debug`

Debug logs contain information for target-specific steps and detailed
information about where Bolt is loading data from. For example, debug logs
include information on how Bolt locates the project to load, where different
content is loaded from, and information about actions run on each individual
target.

Debug logs are useful for troubleshooting a problem with a plan or the way
you're using Bolt. You can use debug logs for a high-level understanding of what
actions Bolt is running on individual targets, or to find out where Bolt is
loading data from.

### `info`

Info logs give you a high-level overview of what Bolt is doing. For example, an
info log contains information about which Bolt project is loaded, when different
actions run on targets start and finish, and results from actions run on
targets.

Info logs are useful when you want to see the results for an action in a Bolt
execution. They're also useful for a high-level understanding of what Bolt is
doing.

### `warn`

Warn logs contain warnings about deprecations and potentially harmful situations
that might affect your Bolt run, even though they don't prevent Bolt from
executing. For example, Bolt warns you if your inventory file includes an
unsupported transport configuration that might result in Bolt connecting to
targets in a way that you don’t expect.

Bolt prints warnings to the console by default.

Use a warn log if you're trying to find out if you're using Bolt in a way that
might result in unexpected behavior, or to see if you're using a deprecated
feature.

### `error`

Error logs contain messages for errors that Bolt encountered during execution.
For example, Bolt prints an error if a PuppetDB query fails.

Bolt prints errors to the console by default.

Use an error log if you want to see errors that Bolt raised during a Bolt run.

### `fatal`

Fatal logs contain `emerg` and `critical` messages from a Puppet code file
(manifest) or apply block.

Use a fatal error log if you want to see fatal errors raised by issues in your
Puppet code.

## Using `verbose` output

The following Bolt commands include the `--verbose` CLI option: 
- `bolt command run`
- `bolt task run`
- `bolt plan run`
- `bolt script run`
- `bolt file upload`
- `bolt file download`
- `bolt apply`

The following PowerShell cmdlets include the `-Verbose` argument:
- `Invoke-BoltCommand`
- `Invoke-BoltTask`
- `Invoke-BoltPlan`
- `Invoke-BoltScript`
- `Send-BoltFile`
- `Receive-BoltFile`
- `Invoke-BoltApply`

Verbose output is useful when you want to see the results for Bolt actions on your targets that are
usually not printed to standard out (stdout). Verbose isn't a log level, but is a way of telling
Bolt to output additional information in a human-readable format. Verbose output is particularly
useful for debugging your tasks and plans - if you're not sure why something is failing, try running
it with `--verbose` to get more information.

## Suppress warnings

You can suppress warning messages from being logged by Bolt. To disable specific
warnings, add a list of warning IDs to the `disable-warnings` configuration
option in `bolt-project.yaml` or `bolt-defaults.yaml`. If defined in both files,
the lists of warnings are concatenated per the [configuration merge
strategy](configuring_bolt.md#merge-strategy). For example, if Bolt issues the
following warning:

```shell
The configuration option 'apples' is deprecated. Use 'oranges' instead. [ID: fruit_option]
```

You could add the ID `fruit_option` under the `disable-warnings` configuration option:

```
# bolt-project.yaml
---
name: myproject
disable-warnings:
  - fruit_option
```

The next time you run Bolt, the warning message will not be logged.

📖 **Related information**  

- [Debugging tasks](writing_tasks.md#debugging-tasks)
- [Debugging YAML plans](writing_tasks.md#debugging-tasks)
- [Debugging Puppet language plans](writing_plans.md#debugging-plans)
- [Project level configuration](configuring_bolt.md#project-level-configuration)
- [Applying Puppet code](applying_manifest_blocks.md) 
- [Bolt command reference](bolt_command_reference.md)
