# Troubleshooting

## Bolt can't find my task

Run the `bolt task show` command or `Get-BoltTask` PowerShell cmdlet and look
for any warnings related to your task metadata.

Make sure your task name is valid: Task names must
- Be lowercase
- Start with a letter
- Can only contain letters, numbers and underscores

Make sure your task executable is named the same as your task metadata. For
example, if your task is named `mytask.rb`, you must name your metadata file
`mytask.json`.

## I can't add a module to my Bolt project

If you receive the following error:

```shell
Unable to use command 'bolt module add'. To use this command, update your project configuration to manage module dependencies.
```

You need to upgrade your project so Bolt can manage your modules and
dependencies. For more information, see [migrate a Bolt
project](./projects.md#migrate-a-bolt-project).

## My task fails with a "permission denied" error (`noexec` issue)

If your task fails with the following error, the issue may be that your temporary directory (tmpdir)
is [mounted with noexec](https://superuser.com/questions/728127/what-does-noexec-flag-mean-when-mounting-directories-on-rhel).

```
The task failed with exit code 126 and no stdout but stderr contained: 
.... <temp path to task>>.rb: Permission denied
```

You can resolve this by [configuring an alternate tmpdir](bolt_transports_reference.md) for the
transport you're using, or by talking to your administrator about updating permissions for the
directory.

## My task fails mysteriously

Try running Bolt with `--log-level debug` to see the exact output from your task.

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
`host-key-check: false` option under the `config: ssh` section of [inventory.yaml](inventory_file_v2.md).
Note that doing so will reduce the security of your SSH connection.

```yaml
config:
  ssh:
    host-key-check: false
```

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
- Set the `winrm` transport in your config or inventory file:
  ```yaml
  # inventory.yaml
  ...
  config:
    transport: winrm
  ```
If you're still getting "connection refused" messages, try disabling SSL. By
default, Bolt connects to targets over WinRM using the HTTPS port 5986. Your
target may not be set up to connect over HTTPS. If you disable SSL, Bolt
connects to the target using the HTTP port 5985. You can disable SSL in one of
the following ways:

- Pass `--no-ssl` on the CLI
- Set the `ssl` key to `false` in your config or inventory file:

  ```yaml
  # inventory.yaml
  ...
  config:
    transport: winrm
    winrm:
      ssl: false
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
the `--log-level debug` command-line option, use the `notice` Puppet log
function. The `notice` function sets the console log level to `debug` for that
run.

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


## Certificate verify failed when installing modules

When running on Windows, Bolt automatically sets the `SSL_CERT_DIR` and
`SSL_CERT_FILE` environment variables if they are not already set. Assuming a
default install location, the variables are set to the following directory and
certificate, which are installed with the Bolt package:

- `SSL_CERT_DIR = C:\Program Files\Puppet Labs\Bolt\ssl\certs`
- `SSL_CERT_FILE = C:\Program Files\Puppet Labs\Bolt\ssl\cert.pem`

If you see an SSL connection error similar to the following when running on
Windows:

```
SSL_connect returned=1 errno=0 state=error: certificate verify failed (unable to get local issuer certificate)
```

Set the `SSL_CERT_DIR` and `SSL_CERT_FILE` environment variables to use a valid
certificate and certificate directory.

## I still need help

Visit the **#bolt** channel in the [Puppet Community
Slack](https://slack.puppet.com) to find a whole community of people waiting
to help!
