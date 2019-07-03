---
title: Debugging common Bolt errors
---

## Bolt can't find my task

Run `bolt task show` and look for any warnings related to your task metadata.

Make sure your task name is valid. Task names must be lowercase, must start with a letter, and can only contain letters, numbers and underscores.

Make sure your task executable is named same as your task metadata, ie. `mytask.rb` and `mytask.json`.

## My task fails mysteriously

Make sure your task executable starts with a `#!` line indicating the interpreter to use and verify that the executable is present on the target system.

Try running Bolt with `--debug` to see the exact output from your task.

## Bolt can't connect to my hosts over SSH

### Host key verification failures

When connecting over SSH, Bolt checks the host key against the fingerprint in `~/.ssh/known_hosts` to verify the host is the one it's expecting to connect to.

This will show up as an error like the following:

    fingerprint SHA256:6+fv7inQSgU2DuYF5NolTlGF6xM8RBRTw1W6B9rbHkc is unknown for "hostname.example.com,10.16.112.82"

This error means that there is no key for the host in `~/.ssh/known_hosts`, so Bolt doesn't know how to tell if it's the right host.

If you can connect to the host over SSH outside Bolt, you can store the SSH host key fingerprint with `ssh-keyscan hostname.example.com >> ~/.ssh/known_hosts`.

You can disable this check entirely with `--no-host-key-check` on the CLI or the `host-key-check: false` option under the `ssh` section of `bolt.yaml`. Note that doing so will reduce the security of your SSH connection.

### Timeout or connection refused

By default, Bolt tries to connect over the standard SSH port 22. If you need to connect over a different port, either include in the name of the target (`hostname.example.com:2345`) or set it in your Bolt config or inventory.

## Bolt can't connect to my Windows hosts

### Timeout or connection refused

Make sure you've specified the `winrm` protocol for the target. You can either include it in the name of the target (`winrm://hostname.example.com`), pass `--transport winrm` on the CLI, or set the transport in your Bolt config or inventory. By default, Bolt will try to connect over SSH.

## Puppet log functions are not logging to the console

The default log level for the console is `warn`. When a `notice` function is used in a plan, it will not be printed to the console. When you have messages you want to be printed to the console regardless of log level you should use the `out::message` plan function. The [`out::message`](../pre-docs/plan_functions.md#outmessage) function is not available for use in an apply block and only accepts string values.

If you need to send a message that is not a String value or is in an apply block you can use the `warning` Puppet log function. The `notice` Puppet log function could be used when you only wish to see the output in the console when executing your plan with the `--debug` flag which will set the console log level to `debug` for that run.

See the docs for configuring the [Bolt's log level](https://puppet.com/docs/bolt/latest/bolt_configuration_options.html#log-file-configuration-options) for more information about how to configure the log levels.

## I still need help

Visit the **#bolt** channel in the [Puppet Community Slack](https://slack.puppet.com) and you will find a whole community of people waiting to help!
