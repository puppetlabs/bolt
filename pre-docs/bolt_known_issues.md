# Known issues

Known issues for the Bolt 0.x release series.

## String segments in commands must be triple-quoted in PowerShell

When running Bolt in PowerShell with commands to be run on \*nix nodes, string segments that can be interpreted by PowerShell need to be triple quoted.[\[BOLT-159\]](https://tickets.puppet.com/browse/BOLT-159)

