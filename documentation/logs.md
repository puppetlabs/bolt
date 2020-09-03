# Logs

Bolt supports multiple log levels. You can configure the log level from the CLI,
or in a project configuration file. Supported logging levels, in order from most
to least information logged, are `trace`, `debug`, `info`, `warn`, and `error`.

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

To set the log level from the CLI, use the `--log-level` option along with the
desired level. Available log levels are `trace`, `debug`, `info`, `warn`, and
`error`. For example:

```console
bolt command run whoami -t target1 --log-level trace
```

### Setting log level in a configuration file

To set the log level for the console, add a `log` map with a `console` mapping
to your [project configuration file](configuring_bolt.md#project-level-configuration).

Use `level` to set the log level. Available log levels are `trace`, `debug`,
`info`, `warn`, and `error`. For example:

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
of compiling a manifest for an apply block, and information about establishing
connections with targets.

Trace logs are useful when you're trying to troubleshoot a problem with Bolt.
They contain information about what exactly Bolt is doing when it runs an action
on each target.

### `debug`

Debug logs contain information for target-specific steps and detailed
information about where Bolt is loading data from. For example, you'll find
information on how Bolt locates the project to load, where different content is
loaded from, and information about actions run on each individual target.

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

Bolt always prints warnings to the console.

Use a warn log if you're trying to find out if you're using Bolt in a way that
might result in unexpected behavior, or to see if you're using a deprecated
feature.

### `error`

Error logs contain messages for errors that Bolt encountered during execution.
For example, Bolt prints an error if a PuppetDB query fails.

Bolt always prints errors to the console.

Use an error log if you want to see errors that Bolt raised during a Bolt run.

## Using `verbose` logging

Bolt's `run`, `file upload`, and `file download` commands include the
`--verbose` CLI option. Verbose logging is useful when you want to see the
results for Bolt actions on your targets that are usually not printed to
standard out (stdout). Verbose logging is particularly useful for debugging your
tasks and plans.

📖 **Related information**  

- [Debugging tasks](writing_tasks.md#debugging-tasks)
- [Debugging Puppet language plans](writing_plans.md#debugging-plans)
- [Debugging YAML plans](writing_tasks.md#debugging-tasks)
- [Project level configuration](configuring_bolt.md#project-level-configuration)
- [Bolt command reference](bolt_command_reference.md)