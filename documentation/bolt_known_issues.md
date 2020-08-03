# Known issues

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

## Unable to authenticate with ed25519 keys over SSH transport on Windows

By default, Bolt uses the `net-ssh` Ruby libary to connect to targets over SSH.
The `net-ssh` library requires the `ed25519` and `bcrypt_pbkdf` gems as
dependencies, which are not supported in Bolt's packaging process due to issues
with compiling native extensions.

Attempting to authenticate with ed25519 keys over SSH on Windows will result
in an error message similar to this:

```
unsupported key type `ssh-ed25519'
 net-ssh requires the following gems for ed25519 support:
  * ed25519 (>= 1.2, < 2.0)
  * bcrypt_pbkdf (>= 1.0, < 2.0)
```

A workaround is to use native SSH when you need to authenticate with ed25519
keys. When native SSH is enabled, Bolt will use a specified SSH client to
connect to targets instead of the `net-ssh` Ruby library. To learn more about
native SSH, see [native SSH
transport](experimental_features.md#native-ssh-transport). 

🧪 Native SSH is
experimental and might change in future minor (y) releases.

📖 **Related issues**

- [#1987 - Unable to authenticate with ed25519 keys over SSH transport
  on Windows](https://github.com/puppetlabs/bolt/issues/1987)

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
