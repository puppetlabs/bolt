# Changelog

## Bolt Next

### Deprecations and removals

* **WARNING**: Starting with this release, new Bolt packages are not available for macOS 10.11, 10.12,
  10.13, and Fedora 28, 29.

### Bug fixes

* **Fixed a performance regression with large inventory files** ([#1625](https://github.com/puppetlabs/bolt/pull/1607)]

  Large inventory groups were taking a long time to load and should now be much faster.

## Bolt 2.0.0

### Deprecations and removals

* **WARNING:** Support for macOS 10.11, 10.12, 10.13, and Fedora 28, 29 will be dropped in the near future.

### New features

* **Better output for errors in plans** ([#1607](https://github.com/puppetlabs/bolt/pull/1607))

  Plans that fail due to an unhandled error now print output the same as if the
  error were caught and then returned. Failures during compilation of `apply()`
  blocks now provide clean error messages.

* **Filter tasks and plans by substring** ([#1596](https://github.com/puppetlabs/bolt/issues/1596))

  Users can now filter available tasks and plans when using `bolt task show` and `bolt plan show` by
  using the `--filter` CLI option. This option accepts a substring to match task and plan names against.

### Bug fixes

* **Bundled `resolve_reference` tasks set to private** ([#1599](https://github.com/puppetlabs/bolt/issues/1599))

  `resolve_reference` tasks in bundled content have been set to private and will no longer appear when
  using `bolt task show`.

### Backward incompatible changes

Bolt 2.0 contains backward-incompatible changes to the CLI, plan language, and configuration files.

#### Output changes

* JSON output now has `target_count` instead of `node_count`

* JSON result objects now have `target` and `value` keys instead of `node` and `result`

* The `prompt` plugin now prompts on stderr instead of stdout

#### CLI changes

* `--nodes` is removed in favor of `--targets`

* `--password` and `--sudo-password` now require an argument

  These used to optionally take an argument and would prompt otherwise. Now they require an argument and the new options `--password-prompt` and `--sudo-password-prompt` can be used to trigger a prompt.

#### Plan language changes

* `add_facts()` now returns the Target passed to it

  Previously, this function returned the Target's set of facts.

* `Target.new` no longer accepts an `options` key

  Both `Target.new("options" => ...)` and `Target.new($uri, "options" => ...)` are now disallowed. `Target.new` now accepts *either* a string argument which is the URI or a hash argument shaped like a target in the inventory file.

* Puppet datatypes are available in `apply()` blocks

  These types include `Target`, `Result`, `ResultSet` and `Error`. They previously showed up in `apply()` blocks as strings or hashes.

* `get_target()` and `get_targets()` are no longer allowed in `apply()` blocks

  To access targets in an `apply()` block, call `get_target()` or `get_targets()` outside the block and assign the result to a variable.

* `run_plan(plan::name, $targets)` will fail if the plan has both a `$nodes` and `$targets` parameter

  If a plan has parameters called both `$nodes` and `$targets`, they must be set explicitly using named arguments.

#### Config changes

* `sudo-password` now defaults to the value of `password` if unspecified

* PuppetDB cert, key, cacert and token file paths are expanded relative to the Boltdir instead of the current working directory

* Inventory v1 has been removed ([#1567](https://github.com/puppetlabs/bolt/issues/1567))

  Inventory v1 is no longer supported by Bolt and has been removed. The inventory now defaults to v2.

* The `future` flag is no longer honored ([#1590](https://github.com/puppetlabs/bolt/pull/1590))

  All "future" behavior is now the only behavior.

* **Support for `config` key in a plugin's `bolt_plugin.json` has been removed** ([#1598](https://github.com/puppetlabs/bolt/issues/1598))

  Plugins can no longer set config in their `bolt_plugin.json`. Config is instead inferred from task
  parameters, with config values passed as parameters to the task.

#### Removals

* Support for Ruby 2.3 and 2.4 has been dropped

  Ruby 2.5 is now the minimum Ruby version.. This only affects gem installs, as OS packages of Bolt contain their own Ruby.

* `bolt-inventory-pdb` command has been removed

  Use the `puppetdb` plugin in an inventory file to replicate this functionality in a more dynamic way.

## Bolt 1.49.0

### New features

* **Add Kerberos support for SSH transport**

  Users can now authenticate with Kerberos when using the SSH transport.

### Bug fixes

* **Remove apply result hash from human output** ([#1585](https://github.com/puppetlabs/bolt/issues/1585))

  Apply result hashes will no longer be displayed when using human output. Instead, a metrics message
  will be shown.

## Bolt 1.48.0

### New features

* **Warning when task metadata has unknown keys** ([#1542](https://github.com/puppetlabs/bolt/pull/1542))

  Unexpected keys in task metadata may signal either a typo or a task that
  depends on features that aren't in this version of Bolt, so Bolt will now
  print a warning if it sees such keys.

* **`apply_prep` plan function ensures Puppet agent version** ([#1208](https://github.com/puppetlabs/bolt/issues/1208))

  The `apply_prep` plan function now attempts to install the specified version of the Puppet agent on a target 
  even when a version of the agent is already installed. If the specified version of the agent cannot be installed, 
  then `apply_prep` will error.

* **Add show_diff configuration option** ([#1433](https://github.com/puppetlabs/bolt/issue/1433))

  Users can now configure the `show_diff` [Puppet
  setting](https://puppet.com/docs/puppet/latest/configuration.html#showdiff) in their Bolt
  configuration file, which will be respected when applying Puppet code via Bolt.

* **Add `env_var` plugin** ([#1564](https://github.com/puppetlabs/bolt/issue/1564))

  Bolt now includes a plugin to look up data from an environment variable.

* **Support `_description` parameter for `apply` blocks** ([#1537](https://github.com/puppetlabs/bolt/issues/1537))

  `apply` blocks in plans now support a `_description` parameter that gives the block a description that is displayed in plan output.

* **Support for system-wide and user-level configuration files** ([#608](https://github.com/puppetlabs/bolt/issues/608))

  Bolt now supports system-wide and user configuration files, in addition to the existing project configuration file.
  File precedence and merge strategy can be found in the [Bolt configuration docs](https://puppet.com/docs/bolt/latest/configuring_bolt.html).

### Bug fixes

* **Require a message when using the prompt plugin** ([#1568](https://github.com/puppetlabs/bolt/issue/1568))

  The `prompt` plugin now correctly requires a `message` option.

## Bolt 1.47.0

### Deprecations and removals

* **The install_agent plugin has been officially removed.** The `install_agent` plugin was
  deprecated in version 1.35 in favor of the `puppet_agent` plugin, and is now removed. The plugins
  have the exact same behavior.

* **Support for plan method `Target.new(<uri>, <options>)` will be dropped in Bolt 2.0.** Use 
  `Target.new(<config>)`, where `config` is a hash with the same structure used to define targets in 
  the inventory V2 file. See [the docs](https://puppet.com/docs/bolt/latest/writing_plans.html#creating-target-objects) 
  for more information and examples.

* **Support for `options` key in the hash parameter for `Target.new()` plan function will be dropped in Bolt 2.0.** Use 
  `Target.new(<config>)`, where `config` is a hash with the same structure used to define targets in 
  the inventory V2 file. See [the docs](https://puppet.com/docs/bolt/latest/writing_plans.html#creating-target-objects) 
  for more information and examples.

### New features

* **Remove empty strings and objects from results in human output** ([#1544](https://github.com/puppetlabs/bolt/issues/1544))

  Human formatted results no longer show empty strings or JSON objects. When a result only has an `_options` key, and the value
  is an empty string or whitespace, a message will be displayed saying the action completed successfully with no result.

### Bug fixes

* **SSH commands will run from the home directory of the run-as user, not the connected user** ([#1518](https://github.com/puppetlabs/bolt/pull/1518))

  Connecting via SSH and then switching users will now run as though it had
  connected as the new user in the first place, using that user's home
  directory as the working directory.

## Bolt 1.45.0

### Deprecations and removals

* **Support for the `bolt-inventory-pdb` command will be dropped in Bolt 2.0.** Users can use the [puppetdb inventory plugin](https://puppet.com/docs/bolt/latest/using_plugins.html#puppetdb) with a v2 inventory file to lookup targets from PuppetDB.

* **Support for the v1 inventory files will be dropped in Bolt 2.0.** Inventory files [can be migrated](https://puppet.com/docs/bolt/latest/migrating_inventory_files.html) automatically using the `bolt project migrate` command.

### New features

* **Packages for Fedora 31** ([#1373](https://github.com/puppetlabs/bolt/issues/1373))

  Bolt packages are now available for Fedora 31.

* **Node definitions are supported when applying manifest code** ([#1338](https://github.com/puppetlabs/bolt/issues/1338))

  Node definitions can now be used with `bolt apply` (but not yet with `apply()` blocks in plans). This makes it easier to reuse existing Puppet codebases with Bolt.

* **Support trusted external facts** ([#1431](https://github.com/puppetlabs/bolt/issues/1431))

  A new Bolt configuration option `trusted-external-command` configures the path to the executable
  on the Bolt controller to run to retrieve trusted external facts. If configured, trusted external
  facts are available when running Bolt. This feature is experimental in both Puppet and Bolt, and
  this API may change or be removed.

## Bolt 1.44.0

### New features

* **New `file::join` plan function** ([#837](https://github.com/puppetlabs/bolt/issues/837))

  The new plan function, `file::join`, allows you to join file paths using the separator `/`.

### Bug fixes

* **The ssh configuration option `key-data` was not compatible with the `future` flag** ([#1504](https://github.com/puppetlabs/bolt/issues/1504))

  Bolt no longer attempts to expand a `private-key` configuration `Hash` when `key-data` is being used in conjunction with the `future` setting.

## Bolt 1.43.0

### New features

* **Plan language objects available inside apply blocks** ([#1244](https://github.com/puppetlabs/bolt/issues/1244))

  Previously, plan language objects (Result, ApplyResult, ResultSet, and Target) were not available
  inside apply blocks as objects, only as flat data. They're now accessible as read-only objects,
  where functions that modify the object (such as `$target.set_var`) are not available but functions
  that read data (such as `$target.vars`) can be used.

* **`run_plan` plan function will specify a plan's `$targets` parameter using the second positional argument** ([#1446](https://github.com/puppetlabs/bolt/issues/1446))

  When running a plan with a `$targets` parameter with the `run_plan` plan function, the second positional argument can be used to specify the `$targets` parameter. If a plan has a `$nodes` parameter, the second positional argument will only specify the `$nodes` parameter.

* **Add `script-dir` option for specifying predictable subpath to the tmpdir**

  When uploading files to remote targets, Bolt uploads them to a tmpdir which includes a randomized directory name. The `script-dir` option sets a predictable subdirectory for `tmpdir` where files will be uploaded.

* **Bundled content updated to use `$targets` parameter** ([#1376](https://github.com/puppetlabs/bolt/issues/1376))

  Plans that are part of the `canary`, `puppetdb_fact`, and `aggregate` modules have been updated to use a `$targets` parameter instead of `$nodes`. The `aggregate::nodes` plan still uses a `$nodes` parameter, but the module now includes a `aggregate::targets` plan that uses a `$targets` parameter.

* **Add `sudo-executable` transport configuration option** ([#1200](https://github.com/puppetlabs/bolt/issues/1200))

  When using `run-as`, the `sudo-executable` transport configuration option can be used to specify an executable to use to run as another user. This option can be set in a `local` or `ssh` config map or with the `--sudo-executable` flag on the CLI. This feature is experimental.

## Bolt 1.42.0

### New features

* **CLI help text updated to be more consistent with other Puppet tools** ([#1441](https://github.com/puppetlabs/bolt/issues/1441))

  Bolt's help text has been reformatted to be more consistent with the formatting in other Puppet tools.

* **Packages for Debian 10** ([#1444](https://github.com/puppetlabs/bolt/issues/1444))

  Bolt packages are now available for Debian 10.

* **SSH transport sets `sudo-password` to the same value as `password` by default** ([#1425](https://github.com/puppetlabs/bolt/issues/1425))

  If `sudo-password` is not set when using `run-as`, Bolt will set the value of `sudo-password` to match the value of `password`. This behavior is gated on the future config option, and will be available by default in Bolt 2.0.
  
### Bug fixes

* **Default PuppetDB config lookup used hardcoded path in Windows** ([#1427](https://github.com/puppetlabs/bolt/pull/1427))

  Bolt will now lookup the default PuppetDB config at `%COMMON_APPDATA%\PuppetLabs\client-tools\puppetdb.conf` instead of the hardcoded path `C:\ProgramData\PuppetLabs\client-tools\puppetdb.conf`.

* **Bolt could not find plans in subdirectories of `plans` directory** ([#1473](https://github.com/puppetlabs/bolt/pull/1473))

  Bolt now searches for subdir paths, under the `plans` directory, for plan names when determining if the plan is a Puppet or YAML plan.

## Bolt 1.41.0

### New features

* **Added `target_mapping` field in `terraform` and `aws_inventory` inventory plugins** ([#1404](https://github.com/puppetlabs/bolt/issues/1404))

  The `terraform` and `aws_inventory` inventory plugins have a new `target_mapping` field which accepts a hash of target configuration options and the lookup values to populate them with.

* **Ruby helper library for inventory plugins** ([#1404](https://github.com/puppetlabs/bolt/issues/1404))

    A new library has been added to help write inventory plugins in Ruby:

    * https://github.com/puppetlabs/puppetlabs-ruby_plugin_helper

    Use this library to map lookup values to a target's configuration options in a `resolve_references` task.
    
## Bolt 1.40.0

### New features

* **`bolt plan show` displays plan and parameter descriptions** ([#1442](https://github.com/puppetlabs/bolt/pull/1442))

  `bolt plan show` now uses Puppet Strings to parse plan documentation and show plan and parameter descriptions as well as parameter defaults.

* **New `remove_from_group` plan function** ([#1418](https://github.com/puppetlabs/bolt/issues/1418))

  The new plan function, `remove_from_group`, allows you to remove a target from an inventory group during plan execution.

* **Added `target_mapping` field in `puppetdb` inventory plugin** ([#1408](https://github.com/puppetlabs/bolt/pull/1408))

  The `puppetdb` inventory plugin has a new `target_mapping` field which accepts a hash of target configuration options and the facts to populate them with.

## Bolt 1.39.0

### New features

* **Task metadata can now specify parameter defaults** ([#1394](https://github.com/puppetlabs/bolt/pull/1394))

  Parameter defaults can be set in the task metadata file and will be used if no value is supplied for the parameter.

### Bug fixes

* **`bolt inventory show --detail` did not display all target aliases** ([#1379](https://github.com/puppetlabs/bolt/issues/1379))

  Bolt now displays aliases from all groups, where a target is a member, in the output for `bolt inventory show --detail`. Previously, only the rightmost alias appeared in the output.

* **Plugins did not ignore command line flags** ([#1382](https://github.com/puppetlabs/bolt/issues/1382))

  When running plugins locally to populate config or inventory information, command line flags such as `--run-as` will no longer be applied to the local transport.

* **Optional plan parameters referenced in `apply` blocks issued warning** ([#1288](https://github.com/puppetlabs/bolt/issues/1288))

    Previously, plan parameters that were explicitly set to `undef` (optional parameters) and were referenced in an `apply` block resulted in a warning message when applying Puppet code. The warning is no longer issued when optional parameters are referenced.

## Bolt 1.38.0

### New features

* **Addition of a YAML plugin** ([#1358](https://github.com/puppetlabs/bolt/issues/1358))

  Bolt now includes a plugin to look up data from a YAML file which allows multiple YAML files to be composed into a single Bolt inventory file. This is useful to breakup a large monolithic inventory file or to load user specific data, like credentials, from outside the project directory.

* **Pass value of `--targets` or `--nodes` to `TargetSpec $target` plan parameter** ([#1175](https://github.com/puppetlabs/bolt/issues/1175))

  Bolt now passes the value of `--targets` or `--nodes` to plans with a `TargetSpec $targets` parameter.

* **Support `_run_as` parameter for puppet_library hook** ([#1191](https://github.com/puppetlabs/bolt/issues/1191))

  Bolt now accepts the `_run_as` metaparameter for puppet_library hooks. `_run_as` specifies which user the library install task will be executed as.

* **Added `--password-prompt` and `--sudo-password-prompt` to CLI flags** ([#1269](https://github.com/puppetlabs/bolt/issues/1269))

  Two new flags have been added to support users who would like to set a `password` or `sudo-password` from a prompt without using a plugin. A deprecation message will appear when a value is not supplied for `--password` or `--sudo-password`.

* **Subcommand `project migrate` new to the CLI** ([#1377](https://github.com/puppetlabs/bolt/issues/1377))

  The CLI now provides the subcommand `project migrate` which migrates Bolt projects to the latest version. When migrating a project the [inventory file](https://puppet.com/docs/bolt/latest/inventory_file.html) will be changed from `v1` to `v2`. Changes are made in place and will not preserve comments or formatting.

* **Plugin support in `bolt.yml`** ([#1381](https://github.com/puppetlabs/bolt/pull/1381))

  Plugin configuration can now be set by looking up data from other plugins. For example, the password for one plugin can be queried from another plugin.


### Bug fixes

* **Bolt issued an error for unset environment variables with `system::env`** ([#1414](https://github.com/puppetlabs/bolt/issues/1414))

  The `system::env` function no longer errors when the environment variable is unset.

* **Results from `file::exists` and `file::readable` errored** ([#1415](https://github.com/puppetlabs/bolt/pull/1415))

  The `file::exists` and `file::readable` functions no longer error when the file path is specified relative to a module and the file doesn't exist.

## Bolt 1.37.0

### New features

* **New `resolve_references` plan function** ([#1365](https://github.com/puppetlabs/bolt/issues/1365))

  The new plan function, `resolve_references`, accepts a hash of structured data and returns a hash of structured data with all plugin references resolved.

### Bug fixes

* **Allow optional `--password` and `--sudo-password` parameters** ([#1269](https://github.com/puppetlabs/bolt/issues/1269))

  Optional parameters for `--password` and `--sudo-password` were prematurely removed. The previous behavior of prompting for a password when an argument is not specified for `--password` or `--sudo-password` has been added back. Arguments will be required in a future version.

## Bolt 1.36.0

### Deprecation

* **Change arguments for `--password` and `--sudo-password` from optional to required** ([#1269](https://github.com/puppetlabs/bolt/issues/1269))

  The `--password` and `--sudo-password` options now require a password as an argument. Previously, if the password was omitted the user would be prompted to enter one. To continue to be prompted for a password, use the `prompt` plugin.

* **Favor `--targets` over `--nodes`** ([#1375](https://github.com/puppetlabs/bolt/issues/1375))

  The `--nodes` command line option has been deprecated in favor of `--targets`. When using `--nodes`, a deprecation warning will be displayed.

### New features

* **Add `--detail` option for `inventory show` command** ([#1200](https://github.com/puppetlabs/bolt/issues/1200))

  The `inventory show` command now supports a `--detail` option to show resolved configuration for specified targets.

* **`prompt` messages print to `stderr`** ([#1269](https://github.com/puppetlabs/bolt/issues/1269))

  The `prompt` plugin now prints messages to `stderr` instead of `stdout`.

* **Subcommand `project init` new to the CLI** ([#1285](https://github.com/puppetlabs/bolt/issues/1285))

  The CLI now provides the subcommand `project init` which creates a new file `bolt.yaml` in the current working directory, making the directory a [Bolt project directory](https://puppet.com/docs/bolt/latest/bolt_project_directories.html#local-project-directory).

* **Bolt issues a warning when inventory overrides a CLI option** ([#1341](https://github.com/puppetlabs/bolt/issues/1341))

  Bolt issues a warning when an option is set both on the CLI and in the inventory, whether the inventory loads from a file or from the `bolt_inventory` environment variable.
  
### Bug fixes

* **Some configured paths were relative to Boltdir and some were relative to the current working directory** ([#1162](https://github.com/puppetlabs/bolt/issues/1162))

  This fix standardizes all configured paths, including the modulepath, to be relative to the Boltdir. It only applies to file-based configs, not command line flags which expand relative to the current working directory. It is gated on the future config option, and will be available by default in Bolt 2.0.

## 1.35.0

### Deprecation

* **Replace `install_agent` plugin with `puppet_agent` module** ([#1294](https://github.com/puppetlabs/bolt/issues/1294))

  The `puppetlabs-puppet_agent` module now provides the same functionality as the `install_agent` plugin did previously. The `install_agent` plugin has been removed and the `puppet_agent` module is now the default plugin for the `puppet_library` hook. If you do not use the bundled `puppet_agent` module you will need to update to version `2.2.1` of the module. If you reference the `install_agent` plugin you will need to now reference `puppet_agent` instead.

### New features

* **Support `limit` option for `do_until` function** ([#1270](https://github.com/puppetlabs/bolt/issues/1270))

  The `do_until` function now supports a `limit` option that prevents it from iterating infinitely.

* **Improve parameter passing for module plugins** ([#1322](https://github.com/puppetlabs/bolt/issues/1322))

  In the absence of a `config` section in `bolt_plugin.json`, Bolt will validate any configuration options in `bolt.yaml` against the schema for each task of the plugin’s hook. Bolt passes the values to the task at runtime and merges them with options set in `inventory.yaml`.

## 1.34.0

### New features

* **Harmonize JSON and Puppet language `Result` Objects** ([#1245](https://github.com/puppetlabs/bolt/issues/1245))

  Previously the JSON representation of a `Result` object showed different keys than were available when working with the object in a plan. This feature makes the same keys available in both the JSON representation and the Puppet object. It is only available when the `future` flag is set to `true` in the [bolt configuration file](https://puppet.com/docs/bolt/latest/bolt_configuration_options.html#global-configuration-options).

* **The `add_facts` plan function returns a `Target` object** ([#1211](https://github.com/puppetlabs/bolt/issues/1211))

  The `add_facts` function now returns a `Target` object to match the `set_*` plan functions for consistency and to allow chaining. This feature is only available when the `future` flag is set to `true` in the [bolt configuration file](https://puppet.com/docs/bolt/latest/bolt_configuration_options.html#global-configuration-options).


### Bug fixes

* **Failed to log transport type when making a connection** ([#1307](https://github.com/puppetlabs/bolt/issues/1307))

  When making a connection to a target node, Bolt now logs the transport type (for example, WinRM or SSH) at debug level.

* **Error when calling `puppet_library` hook of external plugin** ([#1321](https://github.com/puppetlabs/bolt/pull/1321))

  Bolt no longer errors when calling the `puppet_library` hook of a module-based plugin.

* **`apply_prep` failed when `plugin_hooks` key was not set using inventory version 2** ([#1303](https://github.com/puppetlabs/bolt/pull/1303))

  When the `plugin_hooks` key was not set for a target/group in inventory version 2, the `apply_prep` function would not work. Bolt now uses the default `plugin_hooks` and honors `plugin_hooks` from Bolt config when using inventory version 2.

* **Unhelpful error message when parsing malformed `yaml` files** ([#1296](https://github.com/puppetlabs/bolt/issues/1296))

  When parsing a malformed `yaml` file, Bolt now gives an error message containing the path to the file and the line and column in the file where the error originated.

* **`run_task` function didn't respect `_noop` option** ([#1207](https://github.com/puppetlabs/bolt/issues/1207))

  When calling the `run_task` function from a plan with the `_noop` metaparameter, `_noop` is now passed to the task.

## 1.33.0

### Bug fixes

* **Bolt failed to load `azure_inventory` plugin** ([#1301](https://github.com/puppetlabs/bolt/pull/1301))

  Bolt now looks in the default modulepath when loading plugins, so it can successfully load the Azure inventory plugin.

### New features

* **When referring to `Target`s in log or output, use their `safe_name`** ([#1243](https://github.com/puppetlabs/bolt/issues/1243))

  When using inventory version 2, a `Target`'s `safe_name` is the `uri` minus the password (unless the `Target` has an explicitly defined `name`, in which case `safe_name` is the value of `name`). For inventory version 1, `safe_name` is the value of `host`.

* **The `ResultSet` type is now indexable** ([#1178](https://github.com/puppetlabs/bolt/issues/1178))

  When working with `ResultSet` types in plans, use the bracket `[]` operator to get `Results` by index.

* **Log file transfer details at debug level** ([#1256](https://github.com/puppetlabs/bolt/issues/1256))

  When Bolt transfers a file, it logs hostname and filepath details at the debug level. Previously Bolt did not log this information.

## 1.32.0

### Bug fixes

* **The plan function `apply` incorrectly returned successful if the report was unparseable** ([#1241](https://github.com/puppetlabs/bolt/issues/1241))

  Unexpected results for the result of an `apply` are now treated as errors.

* **`interpreters` with spaces fail with the WinRM transport** ([#1158](https://github.com/puppetlabs/bolt/issues/1158))

  The `interpreters` setting on the WinRM transport now supports spaces in the path to an interpreter.

* **Resource Types were not registered while running plans** ([#1140](https://github.com/puppetlabs/bolt/issues/1140))

  Running `puppetfile generate-types` will now generate all built-in types and types on the modulepath, and make those resource types available for plan execution.

### New features

* **Azure inventory plugin** ([#1148](https://github.com/puppetlabs/bolt/issues/1148))

  A new [module based plugin](https://github.com/puppetlabs/puppetlabs-azure_inventory) allows the discovery of Bolt targets from Azure VMs.

* **Clear API for `Target`** ([#1125](https://github.com/puppetlabs/bolt/issues/1125))

  An updated `Target` API for creating and configuring Bolt `Targets` during plan execution with inventory version 2 is now available.

* **New stub for `out::message` available for `BoltSpec::Plans`** ([#1217](https://github.com/puppetlabs/bolt/pull/1217))

  Users can now use `BoltSpec::Plans` to test plans that contain calls to `out::message`.

* **New sub command `bolt group show`** ([#537](https://github.com/puppetlabs/bolt/issues/537))

  The CLI now provides a new command `bolt group show` that will list all of the groups in the inventory file.

## 1.31.1

### Bug fixes

* **Spurious plan failures and warnings on startup**

  Eliminated a race condition with the analytics client that could cause Bolt operations to fail or extraneous warnings to appear during startup.

## 1.31.0

### Deprecations and removals

* **WARNING**: Changes to `aws::ec2`, `pkcs7`, and `task` plugins.

  To improve consistency of plugin behavior, there are three changes to plugins. The `aws::ec2` plugin is now named `aws_inventory`. The `pkcs7` plugin now expects a field called `encrypted_value` rather than `encrypted-value`. The task plugin now expects tasks to return both Target lists and config data under the `value` key instead of the `targets` or `values` keys.

### Bug fixes

* **Tried to read `cacert` file when using WinRM without SSL** ([#1164](https://github.com/puppetlabs/bolt/issues/1164))

  When using the WinRM transport without SSL, Bolt no longer tries to read the `cacert` file. This avoids confusing errors when `cacert` is not readable.

* **Some configuration options would not support file path expansion** ([#1174](https://github.com/puppetlabs/bolt/issues/1174))

  The `token-file` and `cacert` file paths for the PCP transport, and the `cacert` file path for the WinRM transport all now support file expansion.


### New features

* **Plugins can ship with modules** \(1.31.0\)

  Modules can now include Bolt plugins by adding a `bolt_plugin.json` file at the top level. Users can configure these task-based plugins in `bolt.yaml`. \([\#1133](https://github.com/puppetlabs/bolt/issues/1133)\)


## 1.30.1

### Deprecations and removals

* **WARNING**: Starting with this release the puppetlabs apt repo for trusty (Ubuntu 1404) no longer contains new puppet-bolt packages.

### Bug fixes

* **`apply` blocks would ignore the `_run_as` argument passed to
their containing plan** ([#1167](https://github.com/puppetlabs/bolt/issues/1167))

  Apply blocks in sub-plans now honor the parent plan's `_run_as` argument.

* **Task parameters with `type` in the name were filtered out in PowerShell version 2.x or earlier** ([#1205](https://github.com/puppetlabs/bolt/issues/1205))

  PowerShell tasks executed on targets with PowerShell version 2.x or earlier can now use task parameters with the string `type` in the name \(though a parameter simply named `type` is still incompatible\). PowerShell version 3.x or higher does not have this limitation.

## 1.30.0

### Deprecations and removals

* **WARNING**: Ubuntu 14.04 support will be dropped in the near future. Users can install Bolt from the Ubuntu 16.04 package.

### New features

* **Allow users to configure `apply_prep` plan function** ([#1123](https://github.com/puppetlabs/bolt/issues/1123))

  Users can now configure how the Puppet agent gets installed when a plan calls the `apply_prep` function. Users can configure two plugins:

  * `install_agent`, which maintains previous `apply_prep` behavior and is the default
  * `task`, which allows users to either use the `puppet_agent::install` task with non-default parameters, or use their own task.

* **Add CHANGELOG.md** ([#1138](https://github.com/puppetlabs/bolt/issues/1138))

  Bolt now tracks release notes about new features, bug fixes, and deprecation warnings in a `CHANGELOG.md` file in the root of the repo. This file is updated per pull request. As the CHANGELOG file, I'd argue it's the best file in the whole repo.

### Bug fixes

* **`task show` and `plan show` modulepaths used incorrect file path separator** ([#1183](https://github.com/puppetlabs/bolt/issues/1183))

  The modulepath displayed by `bolt task show` and `bolt plan show` now uses an OS-correct file path separator.

* **bolt-inventory-pdb was not installed on path** ([#1172](https://github.com/puppetlabs/bolt/issues/1172))

  During Bolt installation, the `bolt-inventory-pdb` tool is now installed on the user's path.

* **Task helpers did not print errors** ([puppetlabs/puppetlabs-ruby_task_helper#5](https://github.com/puppetlabs/puppetlabs-ruby_task_helper/pull/5) and [puppetlabs/puppetlabs-python_task_helper#](https://github.com/puppetlabs/puppetlabs-python_task_helper/pull/8))

  The Ruby task helper and Python task helper now wrap error results in `{ _error: < error >}` and correctly display errors.

## 1.29.1

### Bug fixes

* **Tasks with input method `stdin` hung with the `--tty` option** ([#1129](https://github.com/puppetlabs/bolt/issues/1129))

  Tasks no longer hang over the SSH transport when the input method is `stdin`, the `--tty` option is set, and the `--run-as` option is unset.

* **Docker transport was incompatible with the Windows Bolt controller** ([#1060](https://github.com/puppetlabs/bolt/issues/1060))

  When running on Windows, the Docker transport can now execute actions on Linux containers.

## 1.29.0

### New features

* **Remote state files for Terraform inventory plugin**

  The Terraform plugin for inventory configuration now supports both local and remote state files. ([BOLT-1469](https://tickets.puppet.com/browse/BOLT-1469))

* **Reorganized command reference documentation**

  The command reference documentation now shows a list of options available for each command, instead of having separate sections for commands and options. ([BOLT-1422](https://tickets.puppet.com/browse/BOLT-1422))

### Bug fixes

* **Using `--sudo-password` without `--run-as` raised a warning**

  CLI commands that contain `--sudo-password` but not `--run-as` now run as expected without any warnings. ([BOLT-1514](https://tickets.puppet.com/browse/BOLT-1514))

## 1.28.0

### New features

* **YAML plans automatically call apply_prep before executing a resources step**

  Bolt automatically calls `apply_prep` on all target nodes before running any resources step in a YAML plan. ([BOLT-1451](https://tickets.puppet.com/browse/BOLT-1451))

* **Bolt images are published to Docker Hub**

  We now publish Bolt container images to the [Puppet Docker Hub](https://hub.docker.com/r/puppet/puppet-bolt) when releasing new versions. ([BOLT-1407](https://tickets.puppet.com/browse/BOLT-1407))

* **AWS plugin has a new location for configuring information**

  You now configure the AWS plugin in the configuration file's `plugin` section instead of its `aws` section. ([BOLT-1501](https://tickets.puppet.com/browse/BOLT-1501))

* **Use Vault KV secrets engine to populate inventory fields**

  You can now populate inventory configuration fields (such as passwords) by looking up secrets from a Vault KV engine. ([BOLT-1424](https://tickets.puppet.com/browse/BOLT-1424))

* **Users are alerted to analytics policies**

  When Bolt first runs, it warns users about collecting and sending analytics and gives instructions for turning analytics collection off. ([BOLT-1487](https://tickets.puppet.com/browse/BOLT-1487))

* **Improved documentation for converting plans from YAML to the Puppet language**

  Bolt documentation explains what structures within a YAML plan can't fully convert into a Puppet language plan. ([BOLT-1286](https://tickets.puppet.com/browse/BOLT-1286))

### Bug fixes

* **Bolt actions hung over SSH when `ProxyCommand` is set in OpenSSH config**

  A new `disconnect-timeout` configuration option for the SSH transport ensures that SSH connections are terminated. ([BOLT-1423](https://tickets.puppet.com/browse/BOLT-1423))

## 1.27.1

### Bug fixes

* **Calling `get_targets` in manifest blocks with inventory version 2 caused an exception**

  `get_targets` now returns a new `Target` object within a manifest block with inventory version 2. When you pass the argument `all` with inventory v2, `get_targets` always returns an empty array. ([BOLT-1492](https://tickets.puppet.com/browse/BOLT-1492))

* **Bolt ignored script arguments that contain "="**

  Bolt now properly recognizes script arguments that contain "=". For example, `bolt script run myscript.sh foo a=b c=d -n mynode` recognizes and uses all three arguments. ([BOLT-1412](https://tickets.puppet.com/browse/BOLT-1412))

## 1.27.0

### New features

* **Use WinRM with Kerberos**

  You can now use Kerberos to authenticate WinRM connections from a Linux host node. This feature is experimental. ([BOLT-126](https://tickets.puppet.com/browse/BOLT-126))

* **New analytics about Boltdir usage**

  Bolt now reports analytics about whether it is using a Boltdir in the default location, a Boltdir in a user-specified location, or a bare `bolt.yaml` without a Boltdir. ([BOLT-1315](https://tickets.puppet.com/browse/BOLT-1315))

* **AWS inventory discovery integration**

  You can now dynamically load AWS EC2 instances as Bolt targets in the inventory. ([BOLT-1328](https://tickets.puppet.com/browse/BOLT-1328))

* **New analytics for inventory plugins**

  Bolt now sends an analytics event when it uses the built-in inventory plugins. ([BOLT-1410](https://tickets.puppet.com/browse/BOLT-1410))

### Bug fixes

* **Bolt debug output showed task and script arguments as Ruby hashes, not JSON**

  Bolt debug output now prints task and script arguments as JSON instead of Ruby hashes. ([BOLT-1456](https://tickets.puppet.com/browse/BOLT-1456))

* **`out::message` didn't print when `format=json`**

  The `out::message` standard plan function now prints messages as expected even when it is configured to use JSON. ([BOLT-1455](https://tickets.puppet.com/browse/BOLT-1455))

## 1.26.0

### New features

* **Options for PCP transport now configurable in `bolt.yaml`**

  The `job-poll-timeout` and `job-poll-interview` options for the PCP transport are now configurable in `bolt.yaml`. ([BOLT-1425](https://tickets.puppet.com/browse/BOLT-1425))

* **Task plugin improvements**

  The `task` plugin now enables you to run a task to discover targets or look up configuration information in the version 2 inventory file. ([BOLT-1408](https://tickets.puppet.com/browse/BOLT-1408))

* **Ability to see nodes in an inventory group**

  You can now see what nodes a Bolt command acts on using the `bolt inventory show` subcommand. Pass a targeting option, such as `-n node1,node2`, `-n groupname`, `-q query`, `--rerun`, and other targeting options to specify which nodes to list. ([BOLT-1398](https://tickets.puppet.com/browse/BOLT-1398))

* **Support for an apply step**

  YAML plans now support applying Puppet resources with a `resources` step. ([BOLT-1222](https://tickets.puppet.com/browse/BOLT-1222))

### Bug fixes

* **Modulepath now handles folder names in uppercase characters on Windows**

  Bolt now prints a warning stating that it is case sensitive when the specified path is not found but another path is found with different capitalization. For example, if the actual path is `C:\User\Administrator\modules` but the user specifies `C:\user\administrator\modules`, a warning states that the specified path was not used and that the correct path is `C:\User\Administrator\modules`. ([BOLT-1318](https://tickets.puppet.com/browse/BOLT-1318))

## 1.25.0

### Bug fixes

* **`out::message` didn't work inside `without_default_logging`**

  The `out::message` standard library plan function now works within a `without_default_logging` block. ([BOLT-1406](https://tickets.puppet.com/browse/BOLT-1406))

* **Task action stub parameter method incorrectly merged options and arguments**

  When a task action stub expectation fails, the expected parameters are now properly displayed. ([BOLT-1399](https://tickets.puppet.com/browse/BOLT-1399))

### Deprecations and removals

* **lookups removed from target_lookups**

  We have deprecated the target-lookups key in the experimental inventory file v2. To address this change, migrate any target-lookups entries to targets and move the plugin key in each entry to _plugin.

## 1.24.0

### New features

* **Help text only lists options for a given command**

  Help text now only shows options for the specified subcommand and action. Previously, all options were displayed in the help text, even if those options did not apply to the specified subcommand and action. ([BOLT-1342](https://tickets.puppet.com/browse/BOLT-1342))

* **Packages for Fedora 30**

  Bolt packages are now available for Fedora 30. ([BOLT-1302](https://tickets.puppet.com/browse/BOLT-1302))

* **Adds support for embedding eyaml data in the inventory**

  This change adds a hiera-eyaml compatible pkcs7 plugin and support for embedding eyaml data in the inventory. ([BOLT-1270](https://tickets.puppet.com/browse/BOLT-1270))

* **Allow `$nodes` as positional arg for `run_plan`**

  This change allows the `run_plan` function to be invoked with `$nodes` as the second positional argument, so that it can be used the same way `run_task` is used. ([BOLT-1197](https://tickets.puppet.com/browse/BOLT-1197))

## 1.23.0

### New features

* **`catch_errors` function**

  The new plan function, `catch_errors`, accepts a list of types of errors to catch and a block of code to run where, if it errors, the plan continues executing. ([BOLT-1316](https://tickets.puppet.com/browse/BOLT-1316))

* **Forge `baseurl` setting in `puppetfile` config**

  The `puppetfile` config section now supports a Forge subsection that you can use to set an alternate Forge location from which to download modules. ([BOLT-1376](https://tickets.puppet.com/browse/BOLT-1376))

### Bug fixes

* **The `wait_until_available` function returned incorrect results using orchestrator**

  When using the PCP transport, the plan function `wait_until_available` now returns error results only for targets that can't be reached. ([BOLT-1382](https://tickets.puppet.com/browse/BOLT-1382))

* **PowerShell tasks on localhost didn't use correct default `PS_ARGS`**

  PowerShell scripts and tasks run over the local transport on Windows hosts no longer load profiles and are run with the `Bypass` execution policy to maintain parity with the WinRM transport. ([BOLT-1358](https://tickets.puppet.com/browse/BOLT-1358))

## 1.22.0

### New features

* **Proxy configuration**

  You can now specify an HTTP proxy for `bolt puppetfile install` in `bolt.yaml`, for example:
  ```
  puppetfile:
    proxy: https://proxy.example.com
  ```

* **Support for version 4 Terraform state files**

  Target-lookups using the Terraform plugin are now compatible with the version 4 Terraform state files generated by Terraform version 0.12.x. ([BOLT-1341](https://tickets.puppet.com/browse/BOLT-1341))

* **Prompt for sensitive data from inventory v2**

  A new `prompt` plugin in inventory v2 allows setting configuration values via a prompt. ([BOLT-1269](https://tickets.puppet.com/browse/BOLT-1269))

## 1.21.0

### New features

* **Set custom exec commands for Docker transport**

  New configuration options, `shell-command` and `tty`, for the Docker transport allow setting custom Docker exec commands.

* **Check existence and readability of files**

  New functions, `file::exists` and `file::readable`, test whether a given file exists and is readable, respectively. ([BOLT-1338](https://tickets.puppet.com/browse/BOLT-1338))

* **Output a message**

  The new `out::message` function can be used to print a message to the user during a plan. ([BOLT-1325](https://tickets.puppet.com/browse/BOLT-1325))

* **Return a filtered ResultSet with a ResultSet**

  A new `filter_set` function in the `ResultSet` data type filters a `ResultSet` with a lambda to return a `ResultSet` object. ([BOLT-1337](https://tickets.puppet.com/browse/BOLT-1337))

* **Improved error handling for unreadable private keys**

  A more specific warning is now surfaced when an SSH private key can't be read from Bolt configuration. ([BOLT-1297](https://tickets.puppet.com/browse/BOLT-1297))

* **Look up PuppetDB facts in inventory v2**

  The PuppetDB plugin can now be used to look up configuration values from PuppetDB facts for the `name`, `uri`, and `config` inventory options for each target. ([BOLT-1264](https://tickets.puppet.com/browse/BOLT-1264))

### Deprecations and removals

* **Configuration location ~/.puppetlab/bolt.yaml**

  When the Boltdir was added as the local default configuration directory, the previous directory, `~/.puppetlab/bolt.yaml`, was deprecated in favor of `~/.puppetlabs/bolt/bolt.yaml`. For more information on the current default directory for configfile, inventoryfile and modules, see Configuring Bolt. ([BOLT-503](https://tickets.puppet.com/browse/BOLT-503))

## 1.20.0

### New features

* **Terraform plugin in inventory v2**

  A new plugin in inventory v2 loads Terraform state and map resource properties to target parameters. This plugin enables using a Terraform project to dynamically determine the targets to use when running Bolt. ([BOLT-1265](https://tickets.puppet.com/browse/BOLT-1265))

* **Type info available in plans**

  A new `to_data` method is available for plan result objects that provides a hash representation of the object. ([BOLT-1223](https://tickets.puppet.com/browse/BOLT-1223))

* **Improved logging for apply**

  The Bolt `apply` command and the `apply` function from plans now show log messages for changes and failures that happened while applying Puppet code. ([BOLT-901](https://tickets.puppet.com/browse/BOLT-901))

### Bug fixes

* **Inventory was loaded for commands that didn't use it**

  Inventory was loaded even for commands that don't use targets, such as `bolt task show`. An error in the inventory could subsequently cause the command to fail. ([BOLT-1268](https://tickets.puppet.com/browse/BOLT-1268))

* **YAML plan converter wrapped single-line evaluation steps**

  The `bolt plan convert` command wrapped single-line evaluation steps in a `with` statement unnecessarily. ([BOLT-1299](https://tickets.puppet.com/browse/BOLT-1299))

## 1.19.0

### New features

* **Convert YAML plans to Puppet plans**

  You can now convert YAML plans to Puppet plans with the `bolt plan convert` command. ([BOLT-1195](https://tickets.puppet.com/browse/BOLT-1195))

* **Improved error handling for missing commands**

  A clear error message is now shown when no object is specified on the command line, for example `bolt command run --nodes <NODE_NAME>`. ([BOLT-1243](https://tickets.puppet.com/browse/BOLT-1243))

## 1.18.0

### New features

* **Inventory file version 2**

  An updated version of the inventory file, version 2, is now available for experimentation and testing. In addition to several syntax changes, this version enables setting a human readable name for nodes and dynamically populating groups from PuppetDB queries. This version of the inventory file is still in development and might experience breaking changes in future releases. ([BOLT-1232](https://tickets.puppet.com/browse/BOLT-1232))

* **YAML plan validation**

  YAML plan validation now alerts on syntax errors before plan execution. ([BOLT-1194](https://tickets.puppet.com/browse/BOLT-1194))

### Bug fixes

* **File upload stalled with local transport using run-as**

  The `bolt file upload` command stalled when using local the local transport if the destination file existed. ([BOLT-1262](https://tickets.puppet.com/browse/BOLT-1262))

* **Rerun file wasn't generated without an existing project directory**

  If no Bolt project directory existed, a `.rerun.json` file wasn't created, preventing you from rerunning failed commands. Bolt now creates a default project directory when one doesn't exist so it can generate `.rerun.json` files as expected. ([BOLT-1263](https://tickets.puppet.com/browse/BOLT-1263))

## 1.17.0

### New features

* **Rerun failed commands**

  Bolt now stores information about the last failed run in a `.rerun.json` file in the Bolt project directory. You can use this record to target nodes for the next run using `--retry failure` instead of `--nodes`.

  For repositories that contain a Bolt project directory, add `$boltdir/.last_failure.json` to `.gitignore` files.

  Stored information may include passwords, so if you save passwords in URIs, set `save-failures: false` in your Bolt config file to avoid writing passwords to the `.rerun.json` file. ([BOLT-843](https://tickets.puppet.com/browse/BOLT-843))

### Bug fixes

* **SELinux management didn't work on localhost**

  Bolt now ships with components similar to the Puppet agent to avoid discrepancies between using a puppet-agent to apply Puppet code locally versus using the Bolt puppet-agent. ([BOLT-1244](https://tickets.puppet.com/browse/BOLT-1244))

## 1.16.0

### New features

* **Packaged hiera-eyaml Gem**

  Bolt packages now include the hiera-eyaml Gem. ([BOLT-1026](https://tickets.puppet.com/browse/BOLT-1026))

* **Local transport options for `run-as`, `run-as-command`, and `sudo-password`**

  The local transport now accepts the `run-as`, `run-as-command,` and `sudo-password` options on non-Windows nodes. These options escalate the system user (who ran Bolt) to the specified user, and behave like the same options using the SSH transport. `\_run_as` can also be configured for individual plan function calls for the local transport. ([BOLT-1052](https://tickets.puppet.com/browse/BOLT-1052))

* **Localhost target applies the puppet-agent feature**

  When the target hostname is `localhost`, the puppet-agent feature is automatically added to the target, because the Puppet agent installed with Bolt is present on the local system. This functionality is available on all transports, not just the local transport. ([BOLT-1200](https://tickets.puppet.com/browse/BOLT-1200))

* **Tasks use the Bolt Ruby interpreter only for localhost**

  Bolt sets its own installed Ruby as the default interpreter for all `*.rb` scripts running on localhost. Previously, this default was used on all commands run over the local transport; it's now used when the hostname is `localhost` regardless of the transport. ([BOLT-1205](https://tickets.puppet.com/browse/BOLT-1205))

* **Fact indicates whether Bolt is compiling a catalog**

  If Bolt is compiling a catalog, `$facts['bolt']` is set to true, allowing you to determine whether modules are being used from a Bolt catalog. ([BOLT-1199](https://tickets.puppet.com/browse/BOLT-1199))

### Bug fixes

* **Linux implementation of the service and package tasks returned incorrect results**

  The PowerShell and Bash implementations for the service and package tasks are more robust and provide output more consistent with the Ruby implementation. (BOLT-1103, BOLT-1104)

## 1.15.0

### New features

* **YAML plans**

  You can now write plans in the YAML language. YAML plans run a list of steps in order, which allows you to define simple workflows. Steps can contain embedded Puppet code expressions to add logic where necessary. For more details about YAML plans, see Writing plans in YAML. For an example of a YAML plan in use, see the Puppet blog. ([BOLT-1150](https://tickets.puppet.com/browse/BOLT-1150))

  This version also adds analytics data collection about the number of steps and the return type of YAML plans. ([BOLT-1193](https://tickets.puppet.com/browse/BOLT-1193))

* **Support for Red Hat Enterprise Linux 8**

  A Bolt package is now available for RHEL 8. ([BOLT-1204](https://tickets.puppet.com/browse/BOLT-1204))

* **Improved load time**

  Bolt startup is now more efficient. ([BOLT-1119](https://tickets.puppet.com/browse/BOLT-1119))

* **Details about Result and ResultSet objects**

  The Result and ResultSet objects now include information in the JSON output about the action that generated the result. ([BOLT-1125](https://tickets.puppet.com/browse/BOLT-1125))

* **Inventory warning about unexepected keys**

  An informative warning message is now logged when invalid group or node configuration keys are detected in the inventoryfile. ([BOLT-1017](https://tickets.puppet.com/browse/BOLT-1017))

* **BoltSpec::Run support for uploading files to remote systems**

  BoltSpec::Run now supports the upload_file action. ([BOLT-953](https://tickets.puppet.com/browse/BOLT-953))

### Bug fixes

* **Remote tasks could run on non-remote targets**

  Remote tasks can now be run only on remote targets ([BOLT-1203](https://tickets.puppet.com/browse/BOLT-1203))

* **known_hosts weren't parsed correctly**

  Previously, when a valid hostname entry was present in known_hosts and the host-key-check SSH configuration option was set, host key validation could fail when a valid IP address was not included in the known_hosts entry. This behavior was inconsistent with system SSH where the IP address is not required. Host key checking has been updated to match system SSH. ([BOLT-495](https://tickets.puppet.com/browse/BOLT-495))

* **Plan variables were visible to sub-plans**

  Variables defined in scope in a plan were visible to sub-plans called with run_plan. ([BOLT-1190](https://tickets.puppet.com/browse/BOLT-1190))

## 1.14.0

### New features

* **Support for Puppet device modules in a manifest block**

  You can now apply Puppet code on targets that can't run a Puppet agent using the remote transport via a proxy. This is an experimental feature and might change in future minor (y) releases. ([BOLT-645](https://tickets.puppet.com/browse/BOLT-645))

* **Validation and error handling for invalid PCP tokens**

  The PCP transport token-file configuration option now includes validation and a more helpful error message. ([BOLT-1076](https://tickets.puppet.com/browse/BOLT-1076))

## 1.13.1

### Bug fixes

* **The \_run_as option was clobbered by configuration**

  The run-as configuration option took precedence over the \_run_as parameter when calling run_* functions in a plan. The \_run_as parameter now has a higher priority than config or CLI. ([BOLT-1050](https://tickets.puppet.com/browse/BOLT-1050))

* **Tasks with certain configuration options failed when using stdin**

  When both interpreters and run-as were configured, tasks that required parameters to be passed over stdin failed. ([BOLT-1155](https://tickets.puppet.com/browse/BOLT-1155))

## 1.13.0

### New features

* **SMB file transfer on Windows**

  When transferring files to a Windows host, you can now optionally use the SMB protocol to reduce transfer time. You must have either administrative rights to use an administrative share, like `\host\C$`, or use UNC style paths to access existing shares, like `\host\share`. You can use SMB file transfers only over HTTP, not HTTPS, and SMB3, which supports encryption, is not yet supported. ([BOLT-153](https://tickets.puppet.com/browse/BOLT-153))

* **Interpreter configuration option**

  An interpreters configuration option enables setting the interpreter that is used to execute a task based on file extension. This options lets you override the shebang defined in the task source code with the path to the executable on the remote system. ([BOLT-146](https://tickets.puppet.com/browse/BOLT-146))

* **Improved error handling**

  Clearer error messages now alert you when you use plan functions not meant to be called in manifest blocks. ([BOLT-1131](https://tickets.puppet.com/browse/BOLT-1131))

### Bug fixes

* **Ruby task helper symbolized only top-level parameter keys**

  Previously the ruby_task_helperTaskHelper.run method symbolized only-top level parameter keys. Now nested keys are also symbolized. ([BOLT-1053](https://tickets.puppet.com/browse/BOLT-1053))

## 1.12.0

### New features

* **Updated project directory structure**

  Within your project directory, we now recommend using a directory called site-modules, instead of the more ambiguously named site, to contain any modules not intended to be managed with a Puppetfile. Both site-modules and site are included on the default modulepath to maintain backward compatibility. ([BOLT-1108](https://tickets.puppet.com/browse/BOLT-1108))

* **bolt puppetfile show-modules command**

  A new bolt puppetfile show-modules command lists the modules, and their versions, installed in the current Boltdir. ([BOLT-1118](https://tickets.puppet.com/browse/BOLT-1118))

* **BoltSpec::Run helpers accept options consistently**

  All BoltSpec::Run helpers now require the params or arguments argument to be passed. ([BOLT-1057](https://tickets.puppet.com/browse/BOLT-1057))

### Bug fixes

* **String segments in commands had to be triple-quoted in PowerShell**

  When running Bolt in PowerShell with commands to be run on *nix nodes, string segments that could be interpreted by PowerShell needed to be triple-quoted. ([BOLT-159](https://tickets.puppet.com/browse/BOLT-159))

## 1.11.0

### New features

* **bolt task show displays module path**

  Task and plan list output now includes the module path to help you better understand why a task or plan is not included. ([BOLT-1027](https://tickets.puppet.com/browse/BOLT-1027))

* **PowerShell scripts over the PCP transport**

  You can now run PowerShell scripts on Windows targets over the PCP transport. ([BOLT-830](https://tickets.puppet.com/browse/BOLT-830))

* **RSA keys with OpenSSH format**

  RSA keys stored in the OpenSSH format can now be used for authentication with the SSH transport. ([BOLT-1124](https://tickets.puppet.com/browse/BOLT-1124))

* **Support for new platforms**

  Bolt packages are now available for Fedora 28 and 29 ([BOLT-978](https://tickets.puppet.com/browse/BOLT-978)), and macOS 10.14 Mojave ([BOLT-1040](https://tickets.puppet.com/browse/BOLT-1040))

### Bug fixes

* **Unsecured download of the puppet_agent::install task**

  The bash implementation of the puppet_agent::install task now downloads packages over HTTPS instead of HTTP. This fix ensures the download is authenticated and secures against a man-in-the-middle attack.

## 1.10.0

### New features

* **Hyphens allowed in aliases and group names**

  Node aliases and group names in the Bolt inventory can now contain hyphens. ([BOLT-1022](https://tickets.puppet.com/browse/BOLT-1022))

### Bug fixes

* **Unsecured download of the puppet_agent::install_powershell task**

  The PowerShell implementation of the puppet_agent::install task now downloads Windows .msi files using HTTPS instead of HTTP. This fix ensures the download is authenticated and secures against a man-in-the-middle attack.

## 1.9.0

### New features

* **Improved out-of-the-box tasks**

  The package and service tasks now select task implementation based on available target features while their platform-specific implementations are private. ([BOLT-1049](https://tickets.puppet.com/browse/BOLT-1049))

* **Respect multiple PuppetDB server_urls**

  Bolt now tries to connect to all configured PuppetDBserver_urls before failing. ([BOLT-938](https://tickets.puppet.com/browse/BOLT-938))

#### Bug fixes

* **Bolt crashed if PuppetDB configuration was invalid**

  If an invalid puppetdb.conf file is detected, Bolt now issues a warning instead of crashing ([BOLT-756](https://tickets.puppet.com/browse/BOLT-756))
* **Local transport returned incorrect exit status**

  Local transport now correctly returns an exit code instead of the stat of the process status as an integer. ([BOLT-1074](https://tickets.puppet.com/browse/BOLT-1074))

## 1.8.1

### Bug fixes

* **Standard library functions weren't packaged in 1.8.0**

  Version 1.8.0 didn't include new standard library functions as intended. This release now includes standard library functions in the gem and packages. ([BOLT-1065](https://tickets.puppet.com/browse/BOLT-1065))

## 1.8.0

### New features

* **Standard library functions**

  Bolt now includes several standard library functions useful for writing plans, including:
  * ctrl::sleep
  * ctrl::do_until
  * file::read
  * file::write
  * system::env

  See Plan execution functions and standard libraries for details. ([BOLT-1054](https://tickets.puppet.com/browse/BOLT-1054))

### Bug fixes

* **puppet_agent::install task didn't match on Red Hat**

  The puppet_agent::install task now uses updates in the facts task to resolve Red Hat operating system facts and to download the correct puppet-agent package. ([BOLT-997](https://tickets.puppet.com/browse/BOLT-997))

## 1.7.0

### New features

* **Configure proxy SSH connections through jump hosts**

  You can now configure proxy SSH connections through jump hosts from the inventory file with the proxyjump SSH configuration option. ([BOLT-1039](https://tickets.puppet.com/browse/BOLT-1039))

* **Query resource states from a plan**

  You can now query resource states from a plan with the get_resources function. ([BOLT-1035](https://tickets.puppet.com/browse/BOLT-1035))

* **Specify an array of directories in modulepath**

  You can now specify an array of directories for the modulepath setting in bolt.yaml, rather than just a string. This change enables using a single bolt.yaml on both *nix and Windows clients. ([BOLT-817](https://tickets.puppet.com/browse/BOLT-817))

* **Save keystrokes on modulepath, inventoryfile, and verbose**

  You can now use shortened command options for modulepath (-m), inventoryfile (-i), and verbose (-v). ([BOLT-1047](https://tickets.puppet.com/browse/BOLT-1047))

### Bug fixes

* **Select module content missing from puppet-bolt package**

  Previous releases of the puppet-bolt package omitted the python_task_helper and ruby_task_helper modules. These are now included. ([BOLT-1036](https://tickets.puppet.com/browse/BOLT-1036))

## 1.6.0

### New features

* **Remote tasks**

  You can now run tasks on a proxy target that remotely interacts with the real target, as defined by the run-on option. Remote tasks are useful for targets like network devices that have limited shell environments, or cloud services driven only by HTTP APIs. Connection information for non-server targets, like HTTP endpoints, can be stored in inventory. ([BOLT-791](https://tickets.puppet.com/browse/BOLT-791))

* **reboot module plan**

  Bolt now ships with the reboot module, and that module now provides a plan that reboots targets and waits for them to become available. ([BOLT-459](https://tickets.puppet.com/browse/BOLT-459))

* **Local transport on Windows**

  The local transport option is now supported on Windows. ([BOLT-608](https://tickets.puppet.com/browse/BOLT-608))

* **bolt_shim module contents marked as sensitive**

  The bolt_shim module that enables using Bolt with PE now marks file content as sensitive, preventing it from being logged or stored in a database. ([BOLT-815](https://tickets.puppet.com/browse/BOLT-815))

#### Bug fixes

* **wait_until_available function didn't work with Docker transport**

  We merged the Docker transport and wait_until_available function in the same release, and they didn't play nicely together. ([BOLT-1018](https://tickets.puppet.com/browse/BOLT-1018))

* **Python task helper didn't generate appropriate errors**

  The Python task helper included with Bolt didn't produce an error if an exception was thrown in a task implemented with the helper. ([BOLT-1021](https://tickets.puppet.com/browse/BOLT-1021))

## 1.5.0

### New features

* **Node aliases**

  You can now specify aliases for nodes in your inventory and then use the aliases to refer to specific nodes. ([BOLT-510](https://tickets.puppet.com/browse/BOLT-510))

* **Run apply with PE orchestrator without installing puppet_agent module**

  Bolt no longer requires installing the puppet_agent module in PE in order to run apply actions with the PE orchestrator. ([BOLT-940](https://tickets.puppet.com/browse/BOLT-940))

## 1.4.0

### New features

* **Bolt apply with orchestrator**

  A new puppetlabs-apply_helper module enables using Boltapply with orchestrator. For details, see the module README. ([BOLT-941](https://tickets.puppet.com/browse/BOLT-941))

* **Add targets to a group**

  A new add_to_group function allows you to add targets to an inventory group during plan execution. ([BOLT-942](https://tickets.puppet.com/browse/BOLT-942))

* **Additional plan test helpers**

  The BoltSpec::Plans library now supports unit testing plans that use the _run_as parameter, apply, run_command, run_script, and upload_file. ([BOLT-984](https://tickets.puppet.com/browse/BOLT-984))

* **Data collection about applied catalogs**

  If analytics data collection is enabled, we now collect randomized info about the number of statements in a manifest block, and how many resources that produces for each target. ([BOLT-644](https://tickets.puppet.com/browse/BOLT-644))

## 1.3.0

### New features

* **Docker transport for running commands on containers**

  A new Docker transport option enables running commands on container instances with the Docker API. The Docker transport is experimental because the capabilities and role of the Docker API might change.([BOLT-962](https://tickets.puppet.com/browse/BOLT-962))

* **Wait until all target nodes accept connections**

  A new wait_until_available function waits until all targets are accepting connections, or triggers an error if the command times out. ([BOLT-956](https://tickets.puppet.com/browse/BOLT-956))

### Bug fixes

* **Plans with no return value weren't marked complete in PE**

  Bolt now correctly reports plan completion to PE for plans that don't return a value. Previously, a plan that didn't return a value incorrectly logged that the plan didn't complete. ([BOLT-959](https://tickets.puppet.com/browse/BOLT-959))
* **Some functions weren't available in the BoltSpec::Plans library**

  The BoltSpec::Plans library now supports plans that use without_default_logging and wait_until_available, and includes a setup helper that ensures tasks are found and that notice works. ([BOLT-971](https://tickets.puppet.com/browse/BOLT-971))

## 1.2.0

### New features

* **Apply Puppet manifest code with bolt apply command**

  The command bolt apply has been added to apply Puppet manifest code on targets without wrapping them in an apply() block in a plan. Note: This command is in development and subject to change. ([BOLT-858](https://tickets.puppet.com/browse/BOLT-858))

* **Python and Ruby helper libraries for tasks**

  Two new libraries have been added to help you write tasks in Ruby and Python:

    * https://github.com/puppetlabs/puppetlabs-ruby_task_helper
    * https://github.com/puppetlabs/puppetlabs-python_task_helper
  Use these libraries to parse task input, catch errors, and produce task output. For details, see Task Helpers. ([BOLT-906](https://tickets.puppet.com/browse/BOLT-906) and [BOLT-907](https://tickets.puppet.com/browse/BOLT-907))

* **Redacted passwords for printed target objects**

  When the Target object in a Bolt plan is printed, it includes only the host, user, port, and protocol used. The values for password and sudo-password are redacted. ([BOLT-944](https://tickets.puppet.com/browse/BOLT-944))

### Bug fixes

* **Task implementation not located relative to other files in installdir**

  When you use tasks that include shared code, the task executable is located alongside shared code at _installdir/MODULE/tasks/TASK. ([BOLT-931](https://tickets.puppet.com/browse/BOLT-931))

## 1.1.0

### New features

* **Share code between tasks**

  Bolt includes the ability to share code between tasks. A task can include a list of files that it requires, from any module, that it copies over and makes available via a _installdir parameter. This feature is also supported in Puppet Enterprise 2019.0. For more information see, Sharing task code. ([BOLT-755](https://tickets.puppet.com/browse/BOLT-755))

* **Upgraded WinRM gem dependencies**

  The following gem dependencies have been upgraded to fix the connection between OMI server on Linux and the WinRM transport:
    * winrm 2.3.0
    * winrm-fs 1.3.1
    * json-schema 2.8.1
  ([BOLT-929](https://tickets.puppet.com/browse/BOLT-929))

* **Mark internal tasks as private**

  In the task metadata, you can mark internal tasks as private and prevent them from appearing in task list UIs. ([BOLT-734](https://tickets.puppet.com/browse/BOLT-734))

* **Upload directories via plans**

  The bolt file upload command and upload_file action now upload directories. For use over the PCP transport these commands require puppetlabs-bolt_shim 0.2.0 or later. ([BOLT-191](https://tickets.puppet.com/browse/BOLT-191))

* **Support for public-key signature system ed25519**

  The ed25519 key type is now supported out-of-the-box in Bolt packages. ([BOLT-380](https://tickets.puppet.com/browse/BOLT-380))

### Bug fixes

* **Error when puppet_agent task not run as root**

  The puppet_agent task now checks that it is run as root. When run as another user, it prints and fails with a helpful message. ([BOLT-878](https://tickets.puppet.com/browse/BOLT-878))

* **Bolt suppresses errors from transport**

  Previously, Bolt suppressed some exception errors thrown by transports. For example, when the ed25519 gem was not present for an Net::SSH process, the NotImplementedError for ed25519 keys would not appear. These errors are now identified and displayed. ([BOLT-922](https://tickets.puppet.com/browse/BOLT-922))

## 1.0.0

### Bug fixes

* **Loading bolt/executor is "breaking" gettext setup in spec tests**

  When Bolt is used as a library, it no longer loads code from r10k unless you explicitly require 'bolt/cli'.([BOLT-914](https://tickets.puppet.com/browse/BOLT-914))

* **Deprecated functions in stdlib result in Evaluation Error**

  Manifest blocks will now allow use of deprecated functions from stdlib, and language features governed by the 'strict' setting in Puppet. ([BOLT-900](https://tickets.puppet.com/browse/BOLT-900))

* **Bolt apply does not provide `clientcert` fact**

  apply_prep has been updated to collect agent facts as listed in Puppet agent facts. ([BOLT-898](https://tickets.puppet.com/browse/BOLT-898))

* **`C:\Program Files\Puppet Labs\Bolt\bin\bolt.bat` is non-functional**

  When moving to Ruby 2.5, the .bat scripts in Bolt packaging reverted to hard-coded paths that were not accurate. As a result Bolt would be unusable outside of PowerShell. The .bat scripts have been fixed so they work from cmd.exe as well. ([BOLT-886](https://tickets.puppet.com/browse/BOLT-886))
