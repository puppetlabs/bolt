# Known issues

Known issues for the Bolt 1.x release series.

## String segments in commands must be triple-quoted in PowerShell

When running Bolt in PowerShell with commands to be run on \*nix nodes, string segments that can be interpreted by PowerShell need to be triple quoted. [\(BOLT-159\)](https://tickets.puppet.com/browse/BOLT-159)

## No Kerberos support

While we would like to support Kerberos over SSH for authentication, a license incompatibility with other components we are distributing means that we cannot recommend using the net-ssh-krb gem for this functionality. [\(BOLT-980\)](https://tickets.puppet.com/browse/BOLT-980)

Note that support for Kerberos over WinRM, both from Windows and non-Windows hosts, is also unimplemented. [\(BOLT-126\)](https://tickets.puppet.com/browse/BOLT-126)
