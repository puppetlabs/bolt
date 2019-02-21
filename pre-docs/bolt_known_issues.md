# Known issues

Known issues for the Bolt 1.x release series.

## False errors for SSH Keys generated with ssh-keygen OpenSSH 7.8 and later

The OpenSSH 7.8 release introduced a change to SSH key generation. It now generates private keys with its own format rather than the OpenSSL PEM format. Because the Bolt SSH implementation assumes any key that uses the OpenSSH format uses the public-key signature system ed25519, false errors have resulted. For example:

```
OpenSSH keys only supported if ED25519 is available
  net-ssh requires the following gems for ed25519 support:
   * ed25519 (>= 1.2, < 2.0)
   * bcrypt_pbkdf (>= 1.0, < 2.0)
  See https://github.com/net-ssh/net-ssh/issues/565 for more information
  Gem::LoadError : "ed25519 is not part of the bundle. Add it to your Gemfile."
```

or

```
Failed to connect to HOST: expected 64-byte String, got NUM 
```

Workaround: Generate new keys with the ssh-keygen flag `-m PEM`. For existing keys, OpenSSH provides the export \(`-e`\) option for exporting from its own format, but export is not implemented for all private key types. [\(BOLT-920\)](https://tickets.puppet.com/browse/BOLT-920) 

## JSON strings as command arguments may require additional escaping in PowerShell

When passing complex arguments to tasks with `--params`, Bolt may require a JSON string (typically created with the `ConvertTo-Json` cmdlet) to have additional escaping. In some cases, the PowerShell stop parsing symbol `--%` may be used as a workaround, until Bolt provides better PowerShell support [\(BOLT-1130\)](https://tickets.puppet.com/browse/BOLT-1130)

## No Kerberos support

While we would like to support Kerberos over SSH for authentication, a license incompatibility with other components we are distributing means that we cannot recommend using the net-ssh-krb gem for this functionality. [\(BOLT-980\)](https://tickets.puppet.com/browse/BOLT-980)

Note that support for Kerberos over WinRM, both from Windows and non-Windows hosts, is also unimplemented. [\(BOLT-126\)](https://tickets.puppet.com/browse/BOLT-126)
