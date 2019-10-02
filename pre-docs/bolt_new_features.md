# New features

New features added to Bolt in the 1.x release series.

## Plugins can ship with modules \(1.31.0\)

Modules can now include Bolt plugins by adding a `bolt_plugin.json` file at the top level. Users can configure these task-based plugins in `bolt.yaml`. \([\#1133](https://github.com/puppetlabs/bolt/issues/1133)\)

## Add CHANGELOG.md \(1.30.0\)

Bolt now tracks release notes about new features, bug fixes, and deprecation warnings in a `CHANGELOG.md` file in the root of the repo. This file is updated per pull request. \([\#1138](https://github.com/puppetlabs/bolt/issues/1138)\)

## Allow users to configure the `apply_prep()` plan function \(1.30.0\)

Users can now configure how the Puppet agent gets installed when a plan calls the `apply_prep()` function. \([\#1123](https://github.com/puppetlabs/bolt/issues/1123)\)

Users can configure two plugins:

-   `install_agent`, which maintains the previous `apply_prep` behavior and is the default
-   `task`, which allows users to use the `puppet_agent::install` task with non-default parameters, or else use their own task

## Remote state files for Terraform inventory plugin \(1.29.0\)

The Terraform plugin for inventory configuration now supports both local and remote state files. \([BOLT-1469](https://tickets.puppetlabs.com/browse/BOLT-1469)\)

## Reorganized command reference documentation \(1.29.0\)

The command reference documentation now shows a list of options available for each command, instead of having separate sections for commands and options. \([BOLT-1422](https://tickets.puppetlabs.com/browse/BOLT-1422)\)

## YAML plans automatically call `apply_prep` before executing a `resources` step \(1.28.0\)

Bolt automatically calls `apply_prep` on all target nodes before running any `resources` step in a YAML plan. \([BOLT-1451](https://tickets.puppetlabs.com/browse/BOLT-1451)\)

## Publish Bolt images to Docker Hub \(1.28.0\)

We now publish Bolt container images to the [Puppet Docker Hub](https://hub.docker.com/r/puppet/puppet-bolt) when new versions are released. \([BOLT-1407](https://tickets.puppetlabs.com/browse/BOLT-1407)\)

## AWS plugin has a new location for configuring information \(1.28.0\)

You now configure the AWS plugin in the configuration file's `plugin` section instead of its `aws` section. \([BOLT-1501](https://tickets.puppetlabs.com/browse/BOLT-1501)\)

## Use Vault KV secrets engine to populate inventory fields \(1.28.0\)

You can now populate inventory configuration fields \(such as passwords\) by looking up secrets from a Vault KV engine. \([BOLT-1424](https://tickets.puppetlabs.com/browse/BOLT-1424)\)

## Alert users about analytics policies \(1.28.0\)

When Bolt first runs, it warns users about collecting and sending analytics and gives instructions for turning analytics collection off. \([BOLT-1487](https://tickets.puppetlabs.com/browse/BOLT-1487)\)

## Improved documentation for converting plans from YAML to the Puppet language \(1.28.0\)

Bolt documentation explains what structures within a YAML plan can't fully convert into a Puppet language plan. \([BOLT-1286](https://tickets.puppetlabs.com/browse/BOLT-1286)\)

## Use WinRM with Kerberos \(1.27.0\)

You can now use Kerberos to authenticate WinRM connections from a Linux host node. This feature is experimental. \([BOLT-126](https://tickets.puppetlabs.com/browse/BOLT-126)\)

## New analytics about Boltdir usage \(1.27.0\)

Bolt now reports analytics about whether it is using `Boltdir` in the default location, `Boltdir` in a user-specified location, or a bare `bolt.yaml` without a `Boltdir`. \([BOLT-1315](https://tickets.puppetlabs.com/browse/BOLT-1315)\)

## AWS inventory discovery integration \(1.27.0\)

You can now dynamically load AWS EC2 instances as Bolt targets in the inventory. \([BOLT-1328](https://tickets.puppetlabs.com/browse/BOLT-1328)\)

## New analytics for inventory plugins \(1.27.0\)

Bolt now sends an analytics event when the built-in inventory plugins are used. \([BOLT-1410](https://tickets.puppetlabs.com/browse/BOLT-1410)\)

## Options for PCP transport now configurable in bolt.yaml \(1.26.0\)

The `job-poll-timeout` and `job-poll-interview` options for the `PCP` transport are now configurable in bolt.yaml. \([BOLT-1425](https://tickets.puppetlabs.com/browse/BOLT-1425)\)

## Task plugin improvements \(1.26.0\)

The `task` plugin now enables you to run a task to discover targets or look up configuration information in the version 2 inventory file. \([BOLT-1408](https://tickets.puppetlabs.com/browse/BOLT-1408)\)

## Ability to see nodes in an inventory group \(1.26.0\)

You can now see what nodes a Bolt command acts on using the `bolt inventory show` subcommand. Pass a targeting option, such as `-n node1,node2`, `-n groupname`, `-q query`, `--rerun`, and other targeting options to specify which nodes to list. \([BOLT-1398](https://tickets.puppetlabs.com/browse/BOLT-1398)\)

## Support for an apply step \(1.26.0\)

YAML plans now support applying Puppet resources with a `resources` step. \([BOLT-1222](https://tickets.puppetlabs.com/browse/BOLT-1222)\)

## Help text only lists options for a given command \(1.24.0\)

Help text now only shows options for the specified subcommand and action. Previously, all options were displayed in the help text, even if those options did not apply to the specified subcommand and action. \([BOLT-1342](https://tickets.puppetlabs.com/browse/BOLT-1342)\)

## Packages for Fedora 30 \(1.24.0\)

Bolt packages are now available for Fedora 30. \([BOLT-1302](https://tickets.puppetlabs.com/browse/BOLT-1302)\)

## Adds support for embedding eyaml data in the inventory \(1.24.0\)

This change adds a hiera-eyaml compatible pkcs7 plugin and support for embedding eyaml data in the inventory. \([BOLT-1270](https://tickets.puppetlabs.com/browse/BOLT-1270)\)

## Allow `$nodes` as positional arg for `run_plan()` \(1.24.0\)

This change allows the `run_plan()` function to be invoked with `$nodes` as the second positional argument, so that it can be used the same way `run_task()` is used. \([BOLT-1197](https://tickets.puppetlabs.com/browse/BOLT-1197)\)

## `catch_errors` function \(1.23.0\)

The new plan function, `catch_errors`, accepts a list of types of errors to catch and a block of code to run where, if it errors, the plan continues executing. \([BOLT-1316](https://tickets.puppetlabs.com/browse/BOLT-1316)\)

## Forge `baseurl` setting in `puppetfile` config \(1.23.0\)

The `puppetfile` config section now supports a Forge subsection that you can use to set an alternate Forge location from which to download modules. \([BOLT-1376](https://tickets.puppetlabs.com/browse/BOLT-1376)\)

## Proxy configuration \(1.22.0\)

You can now specify an HTTP proxy for `bolt puppetfile install` in `bolt.yaml`, for example:

```
puppetfile: 
  proxy: https://proxy.example.com
```

\([BOLT-1327](https://tickets.puppetlabs.com/browse/BOLT-1327)\)

## Support for version 4 Terraform state files \(1.22.0\)

Target-lookups using the Terraform plugin are now compatible with the version 4 Terraform state files generated by Terraform version 0.12.x. \([BOLT-1341](https://tickets.puppetlabs.com/browse/BOLT-1341)\)

## Prompt for sensitive data from inventory v2 \(1.22.0\)

A new `prompt` plugin in inventory v2 allows setting configuration values via a prompt. \([BOLT-1269](https://tickets.puppetlabs.com/browse/BOLT-1269)\)

## Set custom exec commands for Docker transport \(1.21.0\)

New configuration options, `shell-command` and `tty`, for the Docker transport allow setting custom Docker exec commands.

## Check existence and readability of files \(1.21.0\)

New functions, `file::exists` and `file::readable`, test whether a given file exists and is readable, respectively. \([BOLT-1338](https://tickets.puppetlabs.com/browse/BOLT-1338)\)

## Output a message \(1.21.0\)

The new `out::message()` function can be used to print a message to the user during a plan. \([BOLT-1325](https://tickets.puppetlabs.com/browse/BOLT-1325)\)

## Return a filtered `ResultSet` with a `ResultSet` \(1.21.0\)

A new `filter_set` function in the `ResultSet` data type filters a `ResultSet` with a lambda to return a `ResultSet` object. \([BOLT-1337](https://tickets.puppetlabs.com/browse/BOLT-1337)\)

## Improved error handling for unreadable private keys \(1.21.0\)

A more specific warning is now surfaced when an SSH private key can't be read from Bolt configuration. \([BOLT-1297](https://tickets.puppetlabs.com/browse/BOLT-1297)\)

## Look up PuppetDB facts in inventory v2 \(1.21.0\)

The PuppetDB plugin can now be used to look up configuration values from PuppetDB facts for the `name`, `uri`, and `config` inventory options for each target. \([BOLT-1264](https://tickets.puppetlabs.com/browse/BOLT-1264)\)

## Terraform plugin in inventory v2 \(1.20.0\)

A new plugin in inventory v2 loads Terraform state and map resource properties to target parameters. This plugin enables using a Terraform projectto dynamically determine the targets to use when running Bolt. \([BOLT-1265](https://tickets.puppetlabs.com/browse/BOLT-1265)\)

## Type info available in plans \(1.20.0\)

A new `to_data` method is available for plan result objects that provides a hash representation of the object. \([BOLT-1223](https://tickets.puppetlabs.com/browse/BOLT-1223)\)

## Improved logging for `apply` \(1.20.0\)

The Bolt apply command and the `apply` function from plans now show log messages for changes and failures that happened while applying Puppet code. \([BOLT-901](https://tickets.puppetlabs.com/browse/BOLT-901)\)

## Convert YAML plans to Puppet plans \(1.19.0\)

You can now convert YAML plans to Puppet plans with the `bolt plan convert` command. \([BOLT-1195](https://tickets.puppetlabs.com/browse/BOLT-1195)\)

## Improved error handling for missing commands \(1.19.0\)

A clear error message is now shown when no object is specified on the command line, for example `bolt command run --nodes <NODE_NAME>`. \([BOLT-1243](https://tickets.puppetlabs.com/browse/BOLT-1243)\)

## Inventory file version 2 \(1.18.0\)

An updated version of the inventory file, [version 2](inventory_file_v2.md), is now available for experimentation and testing. In addition to several syntax changes, this version enables setting a human readable name for nodes and dynamically populating groups from PuppetDB queries. This version of the inventory file is still in development and might experience breaking changes in future releases. \( [BOLT-1232](https://tickets.puppetlabs.com/browse/BOLT-1232)\)

## YAML plan validation \(1.18.0\)

YAML plan validation now alerts on syntax errors before plan execution. \([BOLT-1194](https://tickets.puppetlabs.com/browse/BOLT-1194)\)

## Rerun failed commands \(1.17.0\)

Bolt now stores information about the last failed run in a `.rerun.json` file in the Bolt project directory. You can use this record to target nodes for the next run using `--retry failure` instead of `--nodes`.

For repositories that contain a Bolt project directory, add `$boltdir/.last_failure.json` to `.gitignore` files.

Stored information may include passwords, so if you save passwords in URIs, set `save-failures: false` in your Bolt config file to avoid writing passwords to the `.rerun.json` file. \( [BOLT-843](https://tickets.puppetlabs.com/browse/BOLT-843)\)

## Packaged `hiera-eyaml` gem \(1.16.0\)

Bolt packages now include the `hiera-eyaml` gem. \( [BOLT-1026](https://tickets.puppetlabs.com/browse/BOLT-1026)\)

## Local transport options for `run-as`, `run-as-command`, and `sudo-password` \(1.16.0\)

The local transport now accepts the `run-as`, `run-as-command`, and `sudo-password` options on non-Windows nodes. These options escalate the system user \(who ran `bolt`\) to the specified user, and behave like the same options using the SSH transport. `_run_as` can also be configured for individual plan function calls for the local transport. \( [BOLT-1052](https://tickets.puppetlabs.com/browse/BOLT-1052)\)

## `Localhost` target applies the `puppet-agent` feature \(1.16.0\)

When the target hostname is `localhost`, the `puppet-agent` feature is automatically added to the target, because the Puppet agent installed with Bolt is present on the local system. This functionality is available on all transports, not just the local transport. \( [BOLT-1200](https://tickets.puppetlabs.com/browse/BOLT-1200)\)

## Tasks use the Bolt Ruby interpreter only for `localhost` \(1.16.0\)

Bolt sets its own installed Ruby as the default interpreter for all `.rb` scripts running on `localhost`. Previously, this default was used on all commands run over the local transport; it's now used when the hostname is `localhost` regardless of the transport. \( [BOLT-1205](https://tickets.puppetlabs.com/browse/BOLT-1205)\)

## Fact indicates whether Bolt is compiling a catalog \(1.16.0\)

If Bolt is compiling a catalog, `$facts['bolt']` is set to `true`, allowing you to determine whether modules are being used from a Bolt catalog. \( [BOLT-1199](https://tickets.puppetlabs.com/browse/BOLT-1199)\)

## YAML plans \(1.15.0\)

You can now write plans in the YAML language. YAML plans run a list of steps in order, which allows you to define simple workflows. Steps can contain embedded Puppet code expressions to add logic where necessary. For more details about YAML plans, see [Writing plans in YAML](writing_yaml_plans.md#). For an example of a YAML plan in use, see the [Puppet blog](https://puppet.com/blog/new-era-dawns-today-bolt-now-supports-yaml). \( [BOLT-1150](https://tickets.puppetlabs.com/browse/BOLT-1150)\)

This version also adds analytics data collection about the number of steps and the return type of YAML plans. \( [BOLT-1193](https://tickets.puppetlabs.com/browse/BOLT-1193)\)

## Support for Red Hat Enterprise Linux 8 \(1.15.0\)

A Bolt package is now available for RHEL 8. \( [BOLT-1204](https://tickets.puppetlabs.com/browse/BOLT-1204)\)

## Improved load time \(1.15.0\)

Bolt startup is now more efficient. \( [BOLT-1119](https://tickets.puppetlabs.com/browse/BOLT-1119)\)

## Details about `Result` and `ResultSet` objects \(1.15.0\)

The `Result` and `ResultSet` objects now include information in the JSON output about the action that generated the result. \( [BOLT-1125](https://tickets.puppetlabs.com/browse/BOLT-1125)\)

## Inventory warning about unexepected keys \(1.15.0\)

An informative warning message is now logged when invalid `group` or `node` configuration keys are detected in the `inventoryfile`. \( [BOLT-1017](https://tickets.puppetlabs.com/browse/BOLT-1017)\)

## `BoltSpec::Run` support for uploading files to remote systems \(1.15.0\)

`BoltSpec::Run` now supports the `upload_file` action. \( [BOLT-953](https://tickets.puppetlabs.com/browse/BOLT-953)\)

## Support for Puppet device modules in a manifest block \(1.14.0\)

You can now apply Puppet code on targets that can't run a Puppet agent using the remote transport via a proxy. This is an experimental feature and might change in future minor \(y\) releases. \( [BOLT-645](https://tickets.puppetlabs.com/browse/BOLT-645)\)

## Validation and error handling for invalid PCP tokens \(1.14.0\)

The PCP transport `token-file` configuration option now includes validation and a more helpful error message. \( [BOLT-1076](https://tickets.puppetlabs.com/browse/BOLT-1076)\)

## SMB file transfer on Windows \(1.13.0\)

When transferring files to a Windows host, you can now optionally use the SMB protocol to reduce transfer time. You must have either administrative rights to use an administrative share, like `\\host\C$`, or use UNC style paths to access existing shares, like `\\host\share`. You can use SMB file transfers only over HTTP, not HTTPS, and SMB3, which supports encryption, is not yet supported. \( [BOLT-153](https://tickets.puppetlabs.com/browse/BOLT-153)\)

## Interpreter configuration option \(1.13.0\)

An `interpreters` configuration option enables setting the interpreter that is used to execute a task based on file extension. This options lets you override the shebang defined in the task source code with the path to the executable on the remote system. \( [BOLT-146](https://tickets.puppetlabs.com/browse/BOLT-146)\)

## Improved error handling \(1.13.0\)

Clearer error messages now alert you when you use plan functions not meant to be called in manifest blocks. \([BOLT-1131](https://tickets.puppetlabs.com/browse/BOLT-1131)\)

## Updated project directory structure \(1.12.0\)

Within your project directory, we now recommend using a directory called `site-modules`, instead of the more ambiguously named `site`, to contain any modules not intended to be managed with a Puppetfile. Both `site-modules` and `site` are included on the default modulepath to maintain backward compatibility. \( [BOLT-1108](https://tickets.puppetlabs.com/browse/BOLT-1108)\)

## `bolt puppetfile show-modules` command \(1.12.0\)

A new `bolt puppetfile show-modules` command lists the modules, and their versions, installed in the current `Boltdir`. \( [BOLT-1118](https://tickets.puppetlabs.com/browse/BOLT-1118)\)

## `BoltSpec::Run` helpers accept options consistently \(1.12.0\)

All `BoltSpec::Run` helpers now require the `params` or `arguments` argument to be passed. \( [BOLT-1057](https://tickets.puppetlabs.com/browse/BOLT-1057)\)

## `bolt task show` displays module path \(1.11.0\)

Task and plan list output now includes the module path to help you better understand why a task or plan is not included. \( [BOLT-1027](https://tickets.puppetlabs.com/browse/BOLT-1027)\)

## PowerShell scripts over the PCP transport \(1.11.0\)

You can now run PowerShell scripts on Windows targets over the PCP transport. \( [BOLT-830](https://tickets.puppetlabs.com/browse/BOLT-830)\)

## RSA keys with OpenSSH format \(1.11.0\)

RSA keys stored in the OpenSSH format can now be used for authentication with the SSH transport. \( [BOLT-1124](https://tickets.puppetlabs.com/browse/BOLT-1124)\)

## Support for new platforms \(1.11.0\)

Bolt packages are now available for these platforms:

-   Fedora 28 and 29 \( [BOLT-978](https://tickets.puppetlabs.com/browse/BOLT-978)\)

-   macOS 10.14 Mojave \( [BOLT-1040](https://tickets.puppetlabs.com/browse/BOLT-1040)\)


## Hyphens allowed in aliases and group names \(1.10.0\)

Node aliases and group names in the Bolt inventory can now contain hyphens. \([BOLT-1022](https://tickets.puppetlabs.com/browse/BOLT-1022)\)

## Improved out-of-the-box tasks \(1.9.0\)

The `package` and `service` tasks now select task implementation based on available target features while their platform-specific implementations are private. \( [BOLT-1049](https://tickets.puppetlabs.com/browse/BOLT-1049)\)

## Respect multiple PuppetDB `server_urls` \(1.9.0\)

Bolt now tries to connect to all configured PuppetDB`server_urls` before failing. \( [BOLT-938](https://tickets.puppetlabs.com/browse/BOLT-938)\)

## Standard library functions \(1.8.0\)

Bolt now includes several standard library functions useful for writing plans, including:

-   `ctrl::sleep`

-   `ctrl::do_until`

-   `file::read`

-   `file::write`

-   `system::env`


See [Plan execution functions and standard libraries](plan_functions.md#) for details. \( [BOLT-1054](https://tickets.puppetlabs.com/browse/BOLT-1054)\)

## Configure proxy SSH connections through jump hosts \(1.7.0\)

You can now configure proxy SSH connections through jump hosts from the inventory file with the `proxyjump` SSH configuration option. \( [BOLT-1039](https://tickets.puppetlabs.com/browse/BOLT-1039)\)

## Query resource states from a plan \(1.7.0\)

You can now query resource states from a plan with the `get_resources` function. \( [BOLT-1035](https://tickets.puppetlabs.com/browse/BOLT-1035)\)

## Specify an array of directories in `modulepath` \(1.7.0\)

You can now specify an array of directories for the `modulepath` setting in `bolt.yaml`, rather than just a string. This change enables using a single `bolt.yaml` on both \*nix and Windows clients. \( [BOLT-817](https://tickets.puppetlabs.com/browse/BOLT-817)\)

## Save keystrokes on `modulepath`, `inventoryfile`, and `verbose` \(1.7.0\)

You can now use shortened command options for `modulepath` \(`-m`\), `inventoryfile` \(`-i`\), and `verbose` \(`-v`\). \( [BOLT-1047](https://tickets.puppetlabs.com/browse/BOLT-1047)\)

## Remote tasks \(1.6.0\)

You can now run tasks on a proxy target that remotely interacts with the real target, as defined by the `run-on` option. Remote tasks are useful for targets like network devices that have limited shell environments, or cloud services driven only by HTTP APIs. Connection information for non-server targets, like HTTP endpoints, can be stored in inventory. \( [BOLT-791](https://tickets.puppetlabs.com/browse/BOLT-791)\)

## `reboot` module plan \(1.6.0\)

Bolt now ships with the [`reboot` module](https://forge.puppet.com/puppetlabs/reboot), and that module now provides a plan that reboots targets and waits for them to become available. \( [BOLT-459](https://tickets.puppetlabs.com/browse/BOLT-459)\)

## Local transport on Windows \(1.6.0\)

The `local` transport option is now supported on Windows. \( [BOLT-608](https://tickets.puppetlabs.com/browse/BOLT-608)\)

## `bolt_shim` module contents marked as sensitive \(1.6.0\)

The `bolt_shim` module that enables using Bolt with PE now marks file content as sensitive, preventing it from being logged or stored in a database. \( [BOLT-815](https://tickets.puppetlabs.com/browse/BOLT-815)\)

## Node aliases \(1.5.0\)

You can now specify aliases for nodes in your inventory and then use the aliases to refer to specific nodes. \( [BOLT-510](https://tickets.puppetlabs.com/browse/BOLT-510)\)

## Run `apply` with PE orchestrator without installing `puppet_agent` module \(1.5.0\)

Bolt no longer requires installing the `puppet_agent` module in PE in order to run `apply` actions with the PE orchestrator. \( [BOLT-940](https://tickets.puppetlabs.com/browse/BOLT-940)\)

## Bolt`apply` with orchestrator \(1.4.0\)

A new `puppetlabs-apply_helper` module enables using Bolt`apply` with orchestrator. For details, see the [module README](https://forge.puppet.com/puppetlabs/apply_helpers). \( [BOLT-941](https://tickets.puppetlabs.com/browse/BOLT-941)\)

## Add targets to a group \(1.4.0\)

A new `add_to_group` function allows you to add targets to an inventory group during plan execution. \( [BOLT-942](https://tickets.puppetlabs.com/browse/BOLT-942)\)

## Additional plan test helpers \(1.4.0\)

The `BoltSpec::Plans` library now supports unit testing plans that use the `_run_as` parameter, `apply`, `run_command`, `run_script`, and `upload_file`. \( [BOLT-984](https://tickets.puppetlabs.com/browse/BOLT-984)\)

## Data collection about applied catalogs \(1.4.0\)

If analytics data collection is enabled, we now collect randomized info about the number of statements in a manifest block, and how many resources that produces for each target. \( [BOLT-644](https://tickets.puppetlabs.com/browse/BOLT-644)\)

## Docker transport for running commands on containers \(1.3.0\)

A new Docker transport option enables running commands on container instances with the Docker API. The Docker transport is experimental because the capabilities and role of the Docker API might change.\( [BOLT-962](https://tickets.puppetlabs.com/browse/BOLT-962)\)

## Wait until all target nodes accept connections \(1.3.0\)

A new `wait_until_available` function waits until all targets are accepting connections, or triggers an error if the command times out. \( [BOLT-956](https://tickets.puppetlabs.com/browse/BOLT-956)\)

## Apply Puppet manifest code with bolt apply command \(1.2.0\)

The command `bolt apply` has been added to apply Puppet manifest code on targets without wrapping them in an `apply()` block in a plan.

**Note:** This command is in development and subject to change.

[\(BOLT-858](https://tickets.puppetlabs.com/browse/BOLT-858)\)

## Python and Ruby helper libraries for tasks \(1.2.0\)

Two new libraries have been added to help you write tasks in Ruby and Python:

-   [https://github.com/puppetlabs/puppetlabs-ruby\_task\_helper](https://github.com/puppetlabs/puppetlabs-ruby_task_helper)

-   [https://github.com/puppetlabs/puppetlabs-python\_task\_helper](https://github.com/puppetlabs/puppetlabs-python_task_helper)


Use these libraries to parse task input, catch errors, and produce task output. For details, see [Task Helpers](https://puppet.com/docs/bolt/1.x/writing_tasks.html#task-helpers). \( [BOLT-906](https://tickets.puppetlabs.com/browse/BOLT-906) and [BOLT-907](https://tickets.puppetlabs.com/browse/BOLT-907)\)

## Redacted passwords for printed target objects \(1.2.0\)

When the `Target` object in a Bolt plan is printed, it includes only the host, user, port, and protocol used. The values for `password` and `sudo-password` are redacted. [\(BOLT-944](https://tickets.puppetlabs.com/browse/BOLT-944)\)

## Share code between tasks \(1.1.0\)

Bolt includes the ability to share code between tasks. A task can include a list of files that it requires, from any module, that it copies over and makes available via a \_installdir parameter. This feature is also supported in Puppet Enterprise 2019.0. For more information see, [Sharing task code](writing_tasks.md#). \( [BOLT-755](https://tickets.puppetlabs.com/browse/BOLT-755)\)

## Upgraded WinRM gem dependencies \(1.1.0\)

The following gem dependencies have been upgraded to fix the connection between OMI server on Linux and the WinRM transport:

-   winrm 2.3.0

-   winrm-fs 1.3.1

-   json-schema 2.8.1


\([BOLT-929](https://tickets.puppetlabs.com/browse/BOLT-929)\)

## Mark internal tasks as private \(1.1.0\)

In the task metadata, you can mark internal tasks as private and prevent them from appearing in task list UIs. \( [BOLT-734](https://tickets.puppetlabs.com/browse/BOLT-734)\)

## Upload directories via plans \(1.1.0\)

The `bolt file upload` command and `upload_file` action now upload directories. For use over the PCP transport these commands require puppetlabs-bolt\_shim 0.2.0 or later. \( [BOLT-191](https://tickets.puppetlabs.com/browse/BOLT-191)\)

## Support for public-key signature system ed25519 \(1.1.0\)

The ed25519 key type is now supported out-of-the-box in Bolt packages. \( [BOLT-380](https://tickets.puppetlabs.com/browse/BOLT-380)\)

**Parent topic:**[Bolt release notes](bolt_release_notes.md)

