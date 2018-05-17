# Plan Logging

Set up log files to record certain events that occur when you run plans.

## Puppet log functions

To generate log messages from a plan, use the puppet log function that corresponds to the level you want to track: `error`, `warn`, `notice`, `info`, or `debug`. The default log level for Bolt is `notice` but you can set it to `info` with the `--verbose `flag or `debug` with the `--debug` flag.

## Default Action Logging

Bolt logs actions that a plan takes on targets through the `file_upload`, `run_command`, `run_script` or `run_task` functions. By default it will log a notice level message when an action starts and another when it completes. If you pass a description to the function that will be used in place of the generic log message.

```
run_task(my_task, $targets, "Better description", param1 => "val")
```

If your plan contains many small actions you may want to suppress these messages and use explicit calls to the puppet log functions instead. This can be accomplished by wrapping actions in a `without_default_logging` block which will cause the action messages to be logged at info level instead of notice. For example to loop over a series of nodes without logging each action.

```
plan deploy( TargetSpec $nodes) {
  without_default_logging() || {
    get_targets($nodes).each |$node| {
      run_task(deploy, $node)
    }
  }
}

```

To avoid complications with parser ambiguity always call `without_default_logging` with `()` and empty block args `||`.

```
without_default_logging() || { run_command('echo hi', $nodes) }
```

not

```
without_default_logging { run_command('echo hi', $nodes) }
```

## puppetdb\_query



You can use the `puppetdb_query `function in plans to make direct queries to PuppetDB. For example you can discover nodes from PuppetDB and then run tasks on them. You'll have to \(configure the puppetdb client\)\[bolt\_configure\_puppetdb.md\] before running it.

```
plan pdb_discover {
  $result = puppetdb_query("inventory[certname] { app_role == 'web_server' })
  # extract the certnames into an array
  $names = $result.map |$r| { $r["certname"] }
  # wrap in url. You can skip this if the default transport is pcp
  $nodes = $names.map |$n| { "pcp://${n}" }
  run_task('my_task', $nodes)
}
```
