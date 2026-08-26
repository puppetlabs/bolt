# Known issues

## `facts` task fails on Windows targets with Facter 3 installed

When running the `facts` task on a Windows target that has Facter 3 installed,
the task will fail but still return facts for the target. Output might look
similar to the following:

```shell
$ bolt task run facts --targets windows_target
Started on windows_target...
Failed on windows_target:
{
  ...
}
Failed on 1 target: windows_target
Ran on 1 target in 4.97 sec
```

This failure is caused by a bug in Facter 3 on Windows that causes Facter to
terminate with a segmentation violation signal when attempting to resolve Puppet
facts.

📖 **Related issues**

- [#2344 - Bolt error caused by a Facter warning on
  Windows](https://github.com/puppetlabs/bolt/issues/2344)
- [FACT_1349 - testing custom fact via RUBYLIB causes
  segfaults](https://tickets.puppetlabs.com/browse/FACT-1349)

## Tasks executed with PowerShell version 2.x or earlier cannot use parameters named `type`

When executing PowerShell tasks on targets using PowerShell version 2.x or
earlier, you cannot use a task parameter with the name `type`. Because
PowerShell version 2.x and earlier do not support `type` as a named argument,
and PowerShell tasks convert parameters to named arguments, Bolt will filter out
a `type` parameter before running the task.

When running PowerShell tasks on targets using PowerShell version 3.0 or later,
any parameter name is permissible.

📖 **Related issues**

- [#1988 - Tasks executed with PowerShell version 2.x or earlier cannot use
  parameters named `type`](https://github.com/puppetlabs/bolt/issues/1988)

## JSON strings as command arguments might require additional escaping in PowerShell

When passing complex arguments to tasks with `--params`, JSON strings (typically
created with the `ConvertTo-Json` cmdlet) might require additional escaping. In
some cases, you can use the PowerShell stop parsing symbol `--%` as a
workaround.

📖 **Related issues**

- [#1985 - Bolt PowerShell wrapper should allow for the use of `Convert-ToJson`
  when using `--params`](https://github.com/puppetlabs/bolt/issues/1985)

## Commands fail in remote Windows sessions

Interactive tools fail when run in a remote PowerShell session. For example,
using `--password-prompt` to prompt for a password when running Bolt triggers an
error.

As a workaround, consider putting the password in a configuration file
such as [`bolt-defaults.yaml`](bolt_defaults_reference.md) or
[`bolt-project.yaml`](bolt_project_reference.md), in an
[inventory file](bolt_inventory_reference.md), or passing the password on the
command line with the `--password` option.

📖 **Related issues**

- [#1986 - Commands fail if in a remote session to
  Windows](https://github.com/puppetlabs/bolt/issues/1986)

## 🧪 Limited Kerberos support over WinRM

🧪 Authenticating with Kerberos over WinRM is considered experimental and is
only supported when running Bolt from a Linux host. You must install the
the [MIT Kerberos
library](https://web.mit.edu/Kerberos/www/krb5-latest/doc/admin/install_clients.html)
to authenticate with Kerberos over WinRM.

📖 **Related issues**

- [#1187 - Support WinRM with Kerberos (from Windows
  node)](https://github.com/puppetlabs/bolt/issues/1187)
- [#1989 - Support WinRM with Kerberos (from
  macOS)](https://github.com/puppetlabs/bolt/issues/1989)

## Errno::EMFILE Too many open files

This error is raised when there are too many files open in Bolt's Ruby process.
To see what your current limit is, run:

```
ulimit -n
```

To raise the limit, set the following in your shell configuration file (For
example, `~/.bash_profile`):

```
ulimit -n 1024
```

You can also set Bolt's concurrency lower to have fewer file descriptors opened
at once. The default concurrency is 100. You can use `--concurrency` on the CLI,
or set `concurrency: <CONCURRENCY>` in [Bolt config](configuring_bolt.md).

📖 **Related issues**

- [#1789 - Too Many Open Files 
  Error](https://github.com/puppetlabs/bolt/issues/1789)
