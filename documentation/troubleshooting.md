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

If your task fails with the following error, the issue might be that your temporary directory (tmpdir)
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

## My task fails on Windows targets

Bolt does not support PowerShell 2.0. If your task targets a Windows OS that has only PowerShell 2.0 installed, the task will fail.

In 2017, Microsoft [deprecated PowerShell 2.0](https://docs.microsoft.com/en-US/windows/deployment/planning/windows-10-removed-features). For a more detailed explanation, see [Micosoft's blog post on the subject](https://devblogs.microsoft.com/powershell/windows-powershell-2-0-deprecation).

Both Microsoft and Puppet recommend updating the target with Windows PowerShell 5.1, but versions 3.0 and 4.0 are also supported.

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
`host-key-check: false` option under the `config: ssh` section of [inventory.yaml](inventory_files.md).
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
target might not be set up to connect over HTTPS. If you disable SSL, Bolt
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

## PowerShell does not recognize Bolt cmdlets

PowerShell 3.0 cannot automatically discover and load the Bolt module. If you're
using PowerShell 3.0, add the Bolt module manually.

> 🔩 **Tip** To confirm your PowerShell version, run`$PSVersionTable`.

To allow PowerShell to load Bolt, add the correct module to your PowerShell
profile.

1.  Update your PowerShell profile.
    ```
    'Import-Module -Name ${Env:ProgramFiles}\WindowsPowerShell\Modules\PuppetBolt' | Out-File -Append $PROFILE
    ```
1.  Load the module in your current PowerShell window.
    ```
    . $PROFILE
    ```

## PowerShell could not load the Bolt PowerShell module

PowerShell's execution policy is a safety feature that controls the conditions
under which PowerShell loads configuration files and runs scripts. This feature
helps prevent the execution of malicious scripts. The default policy is
`Restricted` (allow no scripts to run) for Windows _clients_ and `RemoteSigned`
(allow signed scripts and non-signed scripts not from the internet) for Windows
_servers_. Some environments change this to `AllSigned`, which only allows
scripts to run as long as they are signed by a trusted publisher.

As of Bolt 2.21.0, we sign Bolt PowerShell module files with a Puppet code
signing certificate. If your PowerShell environment uses an `AllSigned`
execution policy and you add Puppet as a trusted publisher, the `bolt` command
works without any further input. If you're using the `AllSigned` policy and you
have not added Puppet as a trusted publisher, you can accept the publisher
without having to change your execution policy.

If your environment uses a `Restricted` policy, you must change your policy to
`RemoteSigned` or `AllSigned`. Check with your security team before you make any
policy changes.

If you see this or a similar error when trying to run Bolt, you probably need to
change your script execution policy restrictions:

```
bolt : The 'bolt' command was found in the module 'PuppetBolt', but the module could not be loaded. 
For more information, run 'Import-Module PuppetBolt'.
                At line:1 char:1
                + bolt --help
                + ~~~~
                + CategoryInfo          : ObjectNotFound: (bolt:String) [], CommandNotFoundExceptio
                n
                + FullyQualifiedErrorId : CouldNotAutoloadMatchingModule
```

To change your script execution policy:

1.  Press **Windows+X**, **A** to run PowerShell as an administrator.

1.  Set your script execution policy to at least `RemoteSigned`:
    ```
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
    ```
    For more information about PowerShell execution policies, see Microsoft's
    documentation about [execution
    policies](http://go.microsoft.com/fwlink/?LinkID=135170) and [how to set
    them](https://msdn.microsoft.com/en-us/powershell/reference/5.1/microsoft.powershell.security/set-executionpolicy).

## 'Could not parse PKey: no start line' error message when using SSH private key

Bolt does not support encrypted SSH private keys if the keys are provided using the
`key-data` field in your transport configuration. If providing a decrypted key is feasible
for your use case and security practices, you can manually decrypt the key by running
`openssl rsa -in <KEY FILE>` and providing your passphrase. Alternatively, you can
add the key to your SSH agent and *not* specify a `private-key` for Bolt to use. Bolt
will use the agent to authenticate your connection.

## Running commands with the Docker transport does not use environment variables

When Bolt runs a command using the Docker transport, it shells out to the
`docker exec` command and sets environment variables using the `--env`
command-line option to set environment variables. When you run a command
using the Docker transport, and the command includes environment variable
interpolations, the environment variables are not interpolated as expected.

For example, the following command:

```shell
bolt command run 'echo \"\$PHRASE\"' --env-var PHRASE=hello --targets docker://example
```

Results in output similar to:

```shell
Started on docker://example...
Finished on docker://example:
  $PHRASE
Successful on 1 target: docker://example
Ran on 1 target in 0.59 sec
```

To run commands that interpolate environment variables using the Docker
transport, update the command to execute a new shell process and then read
the command from a string. For example, you can update the command to:

```shell
bolt command run "/bin/sh -c 'echo \"\$PHRASE\"'" --env-var PHRASE=hello --targets docker://example
```

This results in the expected output:

```shell
Started on docker://example...
Finished on docker://example:
  hello
Successful on 1 target: docker://example
Ran on 1 target in 0.59 sec
```

You can configure the Docker transport to always execute a new shell process
when running commands by setting the `docker.shell-command` configuration option
in your inventory file or `bolt-defaults.yaml` file:

```yaml
# inventory.yaml
config:
  docker:
    shell-command: /bin/sh -c
```

```yaml
# bolt-defaults.yaml
inventory-config:
  docker:
    shell-command: /bin/sh -c
```

## I still need help

Visit the **#bolt** channel in the [Puppet Community
Slack](https://slack.puppet.com) to find a whole community of people waiting
to help!
