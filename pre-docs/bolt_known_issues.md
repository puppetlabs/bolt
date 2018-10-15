# Known issues

Known issues for the Bolt 1.x release series.

## SSH Keys generated with ssh-keygen from OpenSSH 7.8+ fail

OpenSSH 7.8 switched to generating private keys with its own format rather than the OpenSSL PEM format. Our SSH implementation assumes any key using the OpenSSH format uses ed25519, resulting in false errors such as
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

Workaround: generate keys with ssh-keygen's `-m PEM` flag. For existing keys, OpenSSH provides a `-e` option for exporting from its own format, but export is not implemented for all private key types. [\(BOLT-920\)](https://tickets.puppet.com/browse/BOLT-920)

## String segments in commands must be triple-quoted in PowerShell

When running Bolt in PowerShell with commands to be run on \*nix nodes, string segments that can be interpreted by PowerShell need to be triple quoted. [\(BOLT-159\)](https://tickets.puppet.com/browse/BOLT-159)

