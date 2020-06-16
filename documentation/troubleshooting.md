# Troubleshooting common issues

## Bolt can't find my task

Run `bolt task show` and look for any warnings related to your task metadata.

Make sure your task name is valid: Task names must
- Be lowercase
- Start with a letter
- Can only contain letters, numbers and underscores

Make sure your task executable is named the same as your task metadata. For
example, if your task is named `mytask.rb`, you must name your metadata file
`mytask.json`.

## My task fails mysteriously

Try running Bolt with `--debug` to see the exact output from your task.

Make sure your task executable starts with a shebang (`#!`) line indicating the
interpreter to use and verify that the executable is present on the target
system. For example, if you write a Python task and include the line:
`#!/usr/bin/env python`, Bolt attempts to execute the script using the default
`python` executable on the target system.

## Bolt can't connect to my hosts over SSH

### Host key verification failures

This will show up as an error similar to the following:

```shell
fingerprint SHA256:6+fv7inQSgU2DuYF5NolTlGF6xM8RBRTw1W6B9rbHkc is unknown for "hostname.example.com,10.16.112.82"
```

When connecting over SSH, Bolt checks the host key against the fingerprint in
`~/.ssh/known_hosts` to verify the host is the one it's expecting to connect to.
This error means that there is no key for the host in `~/.ssh/known_hosts`, so
Bolt doesn't know how to tell if it's the right host.

If you can connect to the host over SSH outside Bolt, you can store the SSH host
key fingerprint with `ssh-keyscan hostname.example.com >> ~/.ssh/known_hosts`.

You can disable this check entirely with `--no-host-key-check` on the CLI or the
`host-key-check: false` option under the `ssh` section of `bolt.yaml`. Note that
doing so will reduce the security of your SSH connection.

### Timeout or connection refused

By default, Bolt tries to connect over the standard SSH port 22. If you need to
connect over a different port, either include the port in the name of the target
(`hostname.example.com:2345`) or set it in your Bolt config or inventory.

## Bolt can't connect to my Windows hosts

### Timeout or connection refused

By default, Bolt tries to connect over SSH. Make sure you've specified the
`winrm` protocol for the target. There are three ways to specify `winrm`:
- Include the `winrm` in the name of the target. For example:
  `winrm://hostname.example.com` 
- Pass `--transport winrm` on the CLI
- Set the `winrm` transport in your Bolt config or inventory:
  For example:
  ```yaml
  ...
  config:
    transport: winrm
  ```

## Puppet log functions are not logging to the console

The default log level for the console is `warn`. If you use a `notice` function
in a plan, Bolt does not print it to the console. When you have messages
you want to be printed to the console regardless of log level you should use the
`out::message` plan function. The
[`out::message`](plan_functions.md#outmessage) function is not
available for use in an apply block and only accepts string values.

If you need to send a message that is not a string value or is in an apply
block, you can use the `warning` Puppet log function. 

If you only wish to see the output in the console when executing your plan with
the `--debug` flag, use the `notice` Puppet log function. The `notice` function
sets the console log level to `debug` for that run.

For more information, see the docs for configuring [Bolt's log
level](https://puppet.com/docs/bolt/latest/bolt_configuration_options.html#log-file-configuration-options).

## 'Extensions are not built' error message
If you see a `gem` related error similar to the following: 
```shell
    Ignoring nokogiri-1.10.2 because its extensions are not built. Try: gem pristine nokogiri --version 1.10.2
    Ignoring unf_ext-0.0.7.5 because its extensions are not built. Try: gem pristine unf_ext --version 0.0.7.5
```
Use the Bolt-provided gem command to reinstall/install these gems. For example:
```shell
    sudo /opt/puppetlabs/bolt/bin/gem pristine nokogiri --version 1.10.2
    sudo /opt/puppetlabs/bolt/bin/gem pristine unf_ext --version 0.0.7.5
```

## I still need help

Visit the **#bolt** channel in the [Puppet Community
Slack](https://slack.puppet.com) to find a whole community of people waiting
to help!

