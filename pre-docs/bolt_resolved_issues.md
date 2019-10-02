# Resolved issues

Security and bug fixes in the Bolt 1.x release series.

## Some configuration options did not support file path expansion \(1.31.0\)

The `token-file` and `cacert` file paths for the PCP transport, and the `cacert` file path for the WinRM transport all now support file expansion. \([\#1174](https://github.com/puppetlabs/bolt/issues/1174)\)

## Tried to read `cacert` file when using WinRM without SSL \(1.31.0\)

When using the WinRM transport without SSL, Bolt no longer tries to read the `cacert` file. This avoids confusing errors when `cacert` is not readable. \([\#1164](https://github.com/puppetlabs/bolt/issues/1164)\)

## **Task parameters with `type` in the name were filtered out in PowerShell version 2.x or earlier \(1.30.1\)**

PowerShell tasks executed on targets with PowerShell version 2.x or earlier can now use task parameters with the string `type` in the name \(though a parameter simply named `type` is still incompatible\). PowerShell version 3.x or higher does not have this limitation. \([\#1205](https://github.com/puppetlabs/bolt/issues/1205)\)

## `apply()` blocks ignored the `_run_as` argument passed to their containing plan \(1.30.1\)

Apply blocks in sub-plans now honor the parent plan's `_run_as` argument. \([\#1167](https://github.com/puppetlabs/bolt/issues/1167)\)

## Task helpers did not print errors \(1.30.0\)

The Ruby task helper and Python task helper now wrap error results in `{ _error: < error >}` and correctly display errors. \([ruby\_task\_helper \#5](http://github.com/puppetlabs/puppetlabs-ruby_task_helper/pull/5) and [python\_task\_helper \#8](https://github.com/puppetlabs/puppetlabs-python_task_helper/pull/8)\)

## `bolt-inventory-pdb` was not installed on path \(1.30.0\)

During Bolt installation, the `bolt-inventory-pdb` tool is now installed on the user's path. \([\#1172](https://github.com/puppetlabs/bolt/issues/1172)\)

## **`task show` and `plan show` modulepaths used incorrect file path separator** \(1.30.0\)

The modulepath displayed by `bolt task show` and `bolt plan show` now uses an OS-correct file path separator. \([\#1183](https://github.com/puppetlabs/bolt/issues/1183)\)

## **Tasks with input method `stdin` hung with the `--tty` option \(1.29.1\)**

Tasks no longer hang over the SSH transport when the input method is `stdin`, the `--tty` option is set, and the `--run-as` option is unset. \([GH-1129](https://github.com/puppetlabs/bolt/issues/1129)\)

## Docker transport was incompatible with the Windows Bolt controller \(1.29.1\)

When running on Windows, the Docker transport can now execute actions on Linux containers. \([GH-1060](https://github.com/puppetlabs/bolt/issues/1060)\)

## Using `--sudo-password` without `--run-as` raised a warning \(1.29.0\)

CLI commands that contain `--sudo-password` but not `--run-as` now run as expected without any warnings. \([BOLT-1514](https://tickets.puppetlabs.com/browse/BOLT-1514)\)

## Bolt actions hung over SSH when `ProxyCommand` is set in OpenSSH config \(1.28.0\)

A new `disconnect-timeout` configuration option for the SSH transport ensures that SSH connections are terminated. \([BOLT-1423](https://tickets.puppetlabs.com/browse/BOLT-1423)\)

## Calling `get_targets` in manifest blocks with inventory version 2 caused an exception \(1.27.1\)

`get_targets` now returns a new `Target` object within a manifest block with inventory version 2. When you pass the argument `all` with inventory v2, `get_targets` always returns an empty array. \([BOLT-1492](https://tickets.puppetlabs.com/browse/BOLT-1492)\)

## Bolt ignored script arguments that contain "=" \(1.27.1\)

Bolt now properly recognizes script arguments that contain "=". For example, `bolt script run myscript.sh foo a=b c=d -n mynode` recognizes and uses all three arguments. \([BOLT-1412](https://tickets.puppetlabs.com/browse/BOLT-1412)\)

## Bolt debug output showed task and script arguments as Ruby hashes, not JSON \(1.27.0\)

Bolt debug output now prints task and script arguments as JSON instead of Ruby hashes. \([BOLT-1456](https://tickets.puppetlabs.com/browse/BOLT-1456)\)

## `out::message` didn't print when `format=json` \(1.27.0\)

The `out::message` standard plan function now prints messages as expected even when it is configured to use JSON. \([BOLT-1455](https://tickets.puppetlabs.com/browse/BOLT-1455)\)

## Modulepath now handles folder names in uppercase characters on Windows \(1.26.0\)

Bolt now prints a warning stating that it is case sensitive when the specified path is not found but another path is found with different capitalization. For example, if the actual path is `C:\User\Administrator\modules` but the user specifies `C:\user\administrator\modules`, a warning states that the specified path was not used and that the correct path is `C:\User\Administrator\modules`. \([BOLT-1318](https://tickets.puppetlabs.com/browse/BOLT-1318)\)

## `out::message` didn't work inside `without_default_logging` \(1.25.0\)

The `out::message` standard library plan function now works within a `without_default_logging` block. \([BOLT-1406](https://tickets.puppetlabs.com/browse/BOLT-1406)\)

## Task action stub parameter method incorrectly merged options and arguments \(1.25.0\)

When a task action stub expectation fails, the expected parameters are now properly displayed. \([BOLT-1399](https://tickets.puppetlabs.com/browse/BOLT-1399)\)

## The `wait_until_available` function returned incorrect results using orchestrator \(1.23.0\)

When using the PCP transport, the plan function `wait_until_available` now returns error results only for targets that can't be reached. \([BOLT-1382](https://tickets.puppetlabs.com/browse/BOLT-1382)\)

## PowerShell tasks on localhost didn't use correct default PS\_ARGS \(1.23.0\)

PowerShell scripts and tasks run over the local transport on Windows hosts no longer load profiles and are run with the `Bypass` execution policy to maintain parity with the WinRM transport. \([BOLT-1358](https://tickets.puppetlabs.com/browse/BOLT-1358)\)

## Inventory was loaded for commands that didn't use it \(1.20.0\)

Inventory was loaded even for commands that don't use targets, such as `bolt task show`. An error in the inventory could subsequently cause the command to fail. \([BOLT-1268](https://tickets.puppetlabs.com/browse/BOLT-1268)\)

## YAML plan converter wrapped single-line evaluation steps \(1.20.0\)

The `bolt plan convert` command wrapped single-line evaluation steps in a `with()` statement unnecessarily. \([BOLT-1299](https://tickets.puppetlabs.com/browse/BOLT-1299)\)

## File upload stalled with local transport using `run-as` \(1.18.0\)

The `bolt file upload` command stalled when using local the local transport if the destination file existed. \([BOLT-1262](https://tickets.puppetlabs.com/browse/BOLT-1262)\)

## Rerun file wasn't generated without an existing project directory \(1.18.0\)

If no Bolt project directory existed, a `.rerun.json` file wasn't created, preventing you from rerunning failed commands. Bolt now creates a default project directory when one doesn't exist so that `.rerun.json` files are generated as expected. \([BOLT-1263](https://tickets.puppetlabs.com/browse/BOLT-1263)\)

## SELinux management didn't work on localhost \(1.17.0\)

Bolt now ships with components similar to the Puppet agent to avoid discrepancies between using a puppet-agent to apply Puppet code locally versus using the Bolt puppet-agent. \([BOLT-1244](https://tickets.puppetlabs.com/browse/BOLT-1244)\)

## Linux implementation of the service and package tasks returned incorrect results \(1.16.0\)

The PowerShell and bash implementations for the service and package tasks are more robust and provide output more consistent with the Ruby implementation. \([BOLT-1103](https://tickets.puppetlabs.com/browse/BOLT-1103), [BOLT-1104](https://tickets.puppetlabs.com/browse/BOLT-1104)\)

## Remote tasks could run on non-remote targets \(1.15.0\)

Remote tasks can now be run only on remote targets \([BOLT-1203](https://tickets.puppetlabs.com/browse/BOLT-1203)\)

## `known_hosts` weren't parsed correctly \(1.15.0\)

Previously, when a valid hostname entry was present in `known_hosts` and the `host-key-check` SSH configuration option was set, host key validation could fail when a valid IP address was not included in the `known_hosts` entry. This behavior was inconsistent with system SSH where the IP address is not required. Host key checking has been updated to match system SSH. \([BOLT-495](https://tickets.puppetlabs.com/browse/BOLT-495)\)

## Plan variables were visible to sub-plans \(1.15.0\)

Variables defined in scope in a plan were visible to sub-plans called with `run_plan`. \([BOLT-1190](https://tickets.puppetlabs.com/browse/BOLT-1190)\)

## The `_run_as` option was clobbered by configuration \(1.13.1\)

The `run-as` configuration option took precedence over the `_run_as` parameter when calling `run_*` functions in a plan. The `_run_as` parameter now has a higher priority than config or CLI. \([BOLT-1050](https://tickets.puppetlabs.com/browse/BOLT-1050)\)

## Tasks with certain configuration options failed when using `stdin` \(1.13.1\)

When both `interpreters` and `run-as` were configured, tasks that required parameters to be passed over `stdin` failed. \([BOLT-1155](https://tickets.puppetlabs.com/browse/BOLT-1155)\)

## Ruby task helper symbolized only top-level parameter keys \(1.13.0\)

Previously the `ruby_task_helper``TaskHelper.run` method symbolized only-top level parameter keys. Now nested keys are also symbolized. \([BOLT-1053](https://tickets.puppetlabs.com/browse/BOLT-1053)\)

## String segments in commands had to be triple-quoted in PowerShell \(1.12.0\)

When running Bolt in PowerShell with commands to be run on \*nix nodes, string segments that could be interpreted by PowerShell needed to be triple-quoted. \([BOLT-159](https://tickets.puppetlabs.com/browse/BOLT-159)\)

## Unsecured download of the `puppet_agent::install` task \(1.11.0\)

The bash implementation of the `puppet_agent::install` task now downloads packages over HTTPS instead of HTTP. This fix ensures the download is authenticated and secures against a man-in-the-middle attack.

## Unsecured download of the `puppet_agent::install_powershell` task \(1.10.0\)

The PowerShell implementation of the `puppet_agent::install` task now downloads Windows .msi files using HTTPS instead of HTTP. This fix ensures the download is authenticated and secures against a man-in-the-middle attack.

## Bolt crashed if PuppetDB configuration was invalid \(1.9.0\)

If an invalid `puppetdb.conf` file is detected, Bolt now issues a warning instead of crashing \([BOLT-756](https://tickets.puppetlabs.com/browse/BOLT-756)\)

## Local transport returned incorrect exit status \(1.9.0\)

Local transport now correctly returns an exit code instead of the [stat of the process status as an integer](https://ruby-doc.org/core-2.5.0/Process/Status.html#method-i-to_i). \([BOLT-1074](https://tickets.puppetlabs.com/browse/BOLT-1074)\)

## Standard library functions weren't packaged in 1.8.0 \(1.8.1\)

Version 1.8.0 didn't include new standard library functions as intended. This release now includes standard library functions in the gem and packages. \([BOLT-1065](https://tickets.puppetlabs.com/browse/BOLT-1065)\)

## `puppet_agent::install` task didn't match on Red Hat \(1.8.0\)

The `puppet_agent::install` task now uses updates in the `facts` task to resolve Red Hat operating system facts and to download the correct `puppet-agent` package. \([BOLT-997](https://tickets.puppetlabs.com/browse/BOLT-997)\)

## Select module content missing from `puppet-bolt` package \(1.7.0\)

Previous releases of the `puppet-bolt` package omitted the `python_task_helper` and `ruby_task_helper` modules. These are now included. \([BOLT-1036](https://tickets.puppetlabs.com/browse/BOLT-1036)\)

## `wait_until_available` function didn't work with Docker transport \(1.6.0\)

We merged the Docker transport and `wait_until_available` function in the same release, and they didn't play nicely together. \([BOLT-1018](https://tickets.puppetlabs.com/browse/BOLT-1018)\)

## Python task helper didn't generate appropriate errors \(1.6.0\)

The Python task helper included with Bolt didn't produce an error if an exception was thrown in a task implemented with the helper. \([BOLT-1021](https://tickets.puppetlabs.com/browse/BOLT-1021)\)

## Plans with no return value weren't marked complete in PE \(1.3.0\)

Bolt now correctly reports plan completion to PE for plans that don't return a value. Previously, a plan that didn't return a value incorrectly logged that the plan didn't complete. \([BOLT-959](https://tickets.puppetlabs.com/browse/BOLT-959)\)

## Some functions weren't available in the BoltSpec::Plans library \(1.3.0\)

The BoltSpec::Plans library now supports plans that use `without_default_logging` and `wait_until_available`, and includes a setup helper that ensures tasks are found and that `notice` works. \([BOLT-971](https://tickets.puppetlabs.com/browse/BOLT-971)\)

## Task implementation not located relative to other files in installdir \(1.2.0\)

When you use tasks that include shared code, the task executable is located alongside shared code at `_installdir/MODULE/tasks/TASK`. \([BOLT-931](https://tickets.puppetlabs.com/browse/BOLT-931)\)

## Error when puppet\_agent task not run as root \(1.1.0\)

The puppet\_agent task now checks that it is run as root. When run as another user, it prints and fails with a helpful message. \([BOLT-878](https://tickets.puppetlabs.com/browse/BOLT-914)\)

## Bolt suppresses errors from transport \(1.1.0\)

Previously, Bolt suppressed some exception errors thrown by transports. For example, when the ed25519 gem was not present for an Net::SSH process, the NotImplementedError for ed25519 keys would not appear. These errors are now identified and displayed. \([BOLT-922](https://tickets.puppetlabs.com/browse/BOLT-922)\)

## Loading bolt/executor is "breaking" gettext setup in spec tests \(1.0.0\)

When Bolt is used as a library, it no longer loads code from r10k unless you explicitly `require 'bolt/cli'`.\([BOLT-914](https://tickets.puppetlabs.com/browse/BOLT-914)\)

## Deprecated functions in stdlib result in Evaluation Error \(1.0.0\)

Manifest blocks will now allow use of deprecated functions from stdlib, and language features governed by the 'strict' setting in Puppet. \([BOLT-900](https://tickets.puppetlabs.com/browse/BOLT-900)\)

## Bolt apply does not provide clientcert fact \(1.0.0\)

`apply_prep` has been updated to collect agent facts as listed in [Puppet agent facts](https://puppet.com/docs/puppet/latest/lang_facts_and_builtin_vars.html#puppet-agent-facts). \([BOLT-898](https://tickets.puppetlabs.com/browse/BOLT-898)\)

## C:\\Program Files\\Puppet Labs\\Bolt\\bin\\bolt.bat is non-functional \(1.0.0\)

When moving to Ruby 2.5, the .bat scripts in Bolt packaging reverted to hard-coded paths that were not accurate. As a result Bolt would be unusable outside of PowerShell. The .bat scripts have been fixed so they work from cmd.exe as well. \([BOLT-886](https://tickets.puppetlabs.com/browse/BOLT-886)\)

**Parent topic:**[Bolt release notes](bolt_release_notes.md)

