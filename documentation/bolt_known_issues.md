# Known issues

Known issues for the Bolt 1.x release series.

## Tasks executed with PowerShell version 2.x or earlier cannot use parameters named `type`

When executing PowerShell tasks on targets using a PowerShell interpreter version 2.x or earlier, you cannot use a task parameter with the name `type`. Bolt versions 1.30.0 and earlier contained a [bug](https://github.com/puppetlabs/bolt/issues/1205) that made parameters with the string `type` in their name (for example, `serverType`) incompatible. Starting with Bolt version 1.31.0, only PowerShell parameters with `type` as their complete name are incompatible. For PowerShell version 3 and later, any parameter names are permissible.

## JSON strings as command arguments might require additional escaping in PowerShell

When passing complex arguments to tasks with `--params`, JSON strings (typically created with the `ConvertTo-Json` cmdlet) might require additional escaping. In some cases, you can use the PowerShell stop parsing symbol `--%` as a workaround. ([BOLT-1130](https://tickets.puppetlabs.com/browse/BOLT-1130))

## SSH keys generated with ssh-keygen from OpenSSH 7.8+ fail

OpenSSH 7.8 switched to generating private keys with its own format rather than the OpenSSL PEM format. The Bolt SSH implementation assumes any key using the OpenSSH format uses ed25519, resulting in false errors such as:

```
 OpenSSH keys only supported if ED25519 is available net-ssh requires the following gems for ed25519 support: * ed25519 (>= 1.2, < 2.0) * bcrypt_pbkdf (>= 1.0, < 2.0) See https://github.com/net-ssh/net-ssh/issues/565 for more information Gem::LoadError : "ed25519 is not part of the bundle. Add it to your Gemfile."
```

or

```
Failed to connect to HOST: expected 64-byte String, got NUM
```

As a workaround, you can generate new keys with the ssh-keygen `-m PEM` flag. For existing keys, you can try exporting keys from the OpenSSH format using the `-e` option, although export is not implemented for all private key types. ([BOLT-920](https://tickets.puppetlabs.com/browse/BOLT-920))

## Commands fail in remote Windows sessions

Interactive tools fail when run in a remote PowerShell session. For example, using
`--password-prompt` to prompt for a password when running Bolt triggers an error. As a workaround,
consider putting the password in `bolt.yaml` or an inventory file, or passing the password on the
command line. ([BOLT-1075](https://tickets.puppetlabs.com/browse/BOLT-1075))

## Unable to authenticate with ed25519 keys over SSH transport on Windows

Using `ed25519` keys to authenticate over the SSH transport when using Windows bolt controllers is currently unsupported because the ed25519 gem is not installable on Windows. The error message below is an example of an error message to expect.

```
unsupported key type `ssh-ed25519'
 net-ssh requires the following gems for ed25519 support:
  * ed25519 (>= 1.2, < 2.0)
  * bcrypt_pbkdf (>= 1.0, < 2.0)
```

## Limited Kerberos support

Support for Kerberos over WinRM from a Linux host is currently experimental and requires the [MIT Kerberos library](https://web.mit.edu/Kerberos/www/krb5-latest/doc/admin/install_clients.html) to be installed. In the future, Bolt will support Kerberos when running on Windows ([BOLT-1323](https://tickets.puppet.com/browse/BOLT-1323)) and macOS ([BOLT-1471](https://tickets.puppet.com/browse/BOLT-1471)).

## Errno::EMFILE Too many open files

This error is raised when there are too many files open in Bolt's Ruby process. To see what
your current limit is, run:

```
ulimit -n
```

To raise the limit, set the following in your shell configuration file (For example,
`~/.bash_profile`):

```
ulimit -n 1024
```

You can also set Bolt's concurrency lower to have fewer file descriptors opened at once. The default
is 100, and you can use `--concurrency` on the CLI, or set `concurrency: <CONCURRENCY>` in [Bolt
config](configuring_bolt.md)
