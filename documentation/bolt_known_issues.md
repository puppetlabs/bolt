# Known issues

## Resolving module dependencies does not support proxies or alternate Forge

When running the `bolt module add|install` commands or `Add|Install-BoltModule`
cmdlets, Bolt does not support a configured proxy or alternate Forge when it
resolves module dependencies, even if the `module-install` configuration
option is set. Support for resolving module dependencies with proxies or an
alternate Forge requires changes to one of Bolt's gem dependencies, which is
currently in progress.

While Bolt will not resolve module dependencies with proxies or an alternate
Forge, it will respect this configuration when installing modules.

If your project configures the `module-install` option, you may experience
one of the following issues:

- On a restricted network where a proxy is required, resolving modules may
  cause Bolt to fail.

- When an alternate Forge is specified, Bolt may resolve and install a
  different set of modules than expected.

### Install modules without resolving dependencies

To avoid this limitation and any potential errors, you can manually edit your
Puppetfile to add and install modules without resolving dependencies. This is a
similar workflow to using the `bolt puppetfile install` and
`Install-BoltPuppetfileModules` commands.

For example, if your project requires the `puppetlabs/apache` module, but
you need to download modules hosted on an alternate Forge, you should write
your Puppetfile manually. That Puppetfile might look similar to this:

```ruby
mod 'puppetlabs/apache', '5.7.0'
mod 'puppetlabs/stdlib', '6.5.0'
mod 'puppetlabs/concat', '6.3.0'
mod 'puppetlabs/translate', '2.2.0'
```

Once you have a Puppetfile, you can install modules without resolving
dependencies using the `no-resolve` command-line option:

_\*nix command_

```shell
bolt module install --no-resolve
```

_PowerShell cmdlet_

```powershell
Install-BoltModule -NoResolve
```

If you need to add a module to your project, manually add the module and
its dependencies to your Puppetfile and then run the above command again.

### Set the HTTP proxy environment variables

If you only need to configure a proxy to work around network restrictions,
you can set the HTTP proxy environment variables when you run Bolt. For
example, if you only configure the `proxy` option under `module-install` like
this:

```yaml
# bolt-project.yaml
module-install:
  proxy: http://myproxy.com
```

Then you can set the `HTTP_PROXY` and `HTTPS_PROXY` environment variables
to this value when you run `bolt module add|install` or `Add|Install-BoltModule`.
This will configure a proxy that Bolt will use when it makes requests to the
Puppet Forge and GitHub when it resolves modules.

_\*nix command_

```shell
HTTP_PROXY=http://myproxy.com HTTPS_PROXY=http://myproxy.com bolt module install
```

_PowerShell cmdlet_

```powershell
SET HTTP_PROXY=http://myproxy.com
SET HTTPS_PROXY=http://myproxy.com
Install-BoltModule
```

## `facts` task fails on Windows targets with Facter 3 installed

When running the `facts` task on a Windows target that has Facter 3 installed,
the task will fail but still return facts for the target. Output may look
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
