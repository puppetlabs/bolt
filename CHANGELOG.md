# Changelog

## Bolt 3.9.0 (2021-05-24)

### New features

* **Support run-as for container transports when running on \*nix**
  ([#2806](https://github.com/puppetlabs/bolt/issues/2806))

  The Docker, LXD, and Podman transports now support `run-as`
  configuration and related configuration options when running on *nix
  systems. `run-as` is not supported for any Windows systems or the
  PowerShell shell over SSH.

### Bug fixes

* **Upload project plugin files to correct directory when running an
  apply**
  ([#2832](https://github.com/puppetlabs/bolt/issues/2832))

  Project plugin files are now uploaded to the correct directory when
  running an apply. Previously, if a project used a `Boltdir` or had a
  directory name that did not match the project's configured name, apply
  blocks could not correctly reference files in the project using Puppet
  file syntax (`puppet:///modules/<project name>/<file name>`).

* **Correctly set `DOCKER_HOST` environment variable when connecting
  to remote Docker hosts**
  ([#2813](https://github.com/puppetlabs/bolt/pull/2813))

  Bolt now correctly sets the `DOCKER_HOST` environment variable when
  the `docker.service-url` configuration is set. Previously, this
  environment variable was not set correctly, preventing the transport
  from connecting to remote Docker hosts.

  _Contributed by [Mic Kaczmarczik](https://github.com/mpkut)_

## Bolt 3.8.1 (2021-05-17)

### Bug fixes

* **Support _run_as passed to apply_prep()**
  ([#2808](https://github.com/puppetlabs/bolt/pull/2808))

  Bolt now respects the `_run_as` metaparameter when passed to the
  `apply_prep()` plan function. This is the only supported metaparameter, and
  takes highest precedence per the [Bolt configuration
  precedence](https://puppet.com/docs/bolt/latest/configuring_bolt.html#configuration-precedence)

* **Don't stacktrace if welcome message file can't be written**
  ([#2814](https://github.com/puppetlabs/bolt/pull/2814))

  Previously, Bolt would stacktrace if it failed to make the directory to store
  the welcome message file in, which relies on tilde `~` expansion. Bolt now
  falls back to a system-level path, and then omits the welcome message entirely
  if the system-level path also fails to be created or written to.

* **Do not error in `file::*` plan functions when `future` is not configured**
  ([#2828](https://github.com/puppetlabs/bolt/pull/2828))

  The `file::exists`, `file::read`, and `file::readable` plan functions no
  longer error when invoked outside of an apply block when `future` is not
  configured.

### Documentation

* **JSON output documentation**
  ([#2773](https://github.com/puppetlabs/bolt/issues/2773))

  The format for JSON output for each of Bolt's commands is [now
  documented](https://puppet.com/docs/bolt/latest/json_output_reference.md).

## Bolt 3.8.0 (2021-05-03)

### New features

* **Facts diff task accepts `exclude` parameter**
  ([#2804](https://github.com/puppetlabs/bolt/pull/2804))

  The `puppet_agent::facts_diff` task now accepts an `exclude` parameter
  to filter output based on a provided regex.

* **`lookup` command to look up values with Hiera**
  ([#2499](https://github.com/puppetlabs/bolt/issues/2499))

  The new `bolt lookup` and `Invoke-BoltLookup` commands can be used to
  look up values with Hiera.

* **Load files from specified Puppet paths**
  ([#2731](https://github.com/puppetlabs/bolt/issues/2731))

  If the project-level `future.file_paths` configuration is enabled,
  Puppet files can be loaded using the new loading syntax. For more
  information see https://pup.pt/bolt-loading-files.

### Removals

* **Puppet5 collection no longer available for `puppet_agent::install`
  task**
  ([#2804](https://github.com/puppetlabs/bolt/pull/2804))

  Now that this collection is unavailable to download from, it's not a
  valid parameter to the `puppet_agent::install` task.

## Bolt 3.7.1 (2021-04-26)

### New features

* **Developer Update: Script loading changes**

  There's a new Developer Update in town, [read it
  here](https://puppet.com/docs/bolt/latest/developer_updates.html).

### Bug fixes

* **Allow Docker connections using full ID as the host**

  The Bolt Docker transport now successfully connects to containers
  when the full SHA 256 container ID string is provided as a name or
  URL. Previously, Bolt could only connect when the 12 character
  shortened form of the ID string was used.

* **Fixed incorrect param in Get-BoltTask text** ([#2795](https://github.com/puppetlabs/bolt/issues/2795))

  Fixed the 'Additional Information' section of the help text for the Get-BoltTask cmdlet having an
  incorrect parameter for the task name

  _Contributed by [Malivil](https://github.com/Malivil)_

## Bolt 3.7.0 (2021-04-13)

### New features

* **Default to showing all targets with `bolt inventory show`**
  ([#2747](https://github.com/puppetlabs/bolt/issues/2747))

  The `bolt inventory show` and `Get-BoltInventory` commands now default
  ot showing all targets in the inventory if a targetting option
  (`--targets`, `--query`, `--rerun`) are not provided.

* **Improved group information output**
  ([#2766](https://github.com/puppetlabs/bolt/pull/2766))

  The `bolt group show` and `Get-BoltGroup` commands now display `human`
  output in a similar format to other `show` commands. The `json` output
  now includes the path to the inventory file that the groups are loaded
  from.

* **`puppetdb_command` plan function**
  ([#2771](https://github.com/puppetlabs/bolt/issues/2771))

  The `puppetdb_command` plan function can be used to invoke commands in
  PuppetDB. Currently, only the `replace_facts` command is officially
  tested and supported, though other commands might work as well.

  _This feature is experimental and subject to change._

### Bug fixes

* **Do not error when using metaparameters in YAML plans**
  ([#2777](https://github.com/puppetlabs/bolt/issues/2777))

  Bolt no longer errors for YAML plans that include a plan or task step
  that includes an additional option (e.g. `_catch_errors`) under the
  `parameters` key.

* **Output correct inventory source with `inventory show`**
  ([#2766](https://github.com/puppetlabs/bolt/pull/2766))

  The `bolt inventory show` and `Get-BoltInventory` commands now output
  the correct source of inventory when using the `BOLT_INVENTORY`
  environment variable. Previously, Bolt would output the path to the
  default inventory file.

## Bolt 3.6.1 (2021-04-07)

### Bug fixes

* **Ensure all messages print, even after thread finishes**
  ([#2770](https://github.com/puppetlabs/bolt/pull/2770))

  Bolt now ensures that all messages from a command or script are
  printed back to the user. Previously, some messages would be lost
  if they were read after the thread finished executing or when Bolt had
  been prompted for a sudo password.

## Bolt 3.6.0 (2021-04-06)

### New features

* **Improved inventory output**
  ([#2751](https://github.com/puppetlabs/bolt/pull/2751))

  The `bolt inventory show` and `Get-BoltInventory` command now display
  `human` output in the same format as other `show` commands.

* **Improved plan and task information output**
  ([#2754](https://github.com/puppetlabs/bolt/pull/2754))

  The `bolt plan|task show <name>` and `Get-Bolt(Plan|Task) -Name
  <name>` commands now display `human` output in a similar format to
  other `show` commands.

* **Podman transport**
  ([#2456](https://github.com/puppetlabs/bolt/issues/2456))

  The Podman transport connects to local running Podman containers,
  useful for testing scenarios or debugging.

* **Disable analytics in system, user, and project config files**
  ([#2759](https://github.com/puppetlabs/bolt/issues/2759))

  The new `analytics` configuration option can be used to disable data
  collection in Bolt and is supported in both `bolt-defaults.yaml` and
  `bolt-project.yaml`. Disabling data collection cannot be overridden by
  enabling it in another configuration file.

### Bug fixes

* **Do not stack trace when missing project configuration file**
  ([#2756](https://github.com/puppetlabs/bolt/issues/2756))

  Bolt no longer stack traces when installing modules if the project
  does not have a `bolt-project.yaml` configuration file.

## Bolt 3.5.0 (2021-03-29)

### New features

* **Test plans that use `run_task_with()` plan function in BoltSpec**
  ([#2692](https://github.com/puppetlabs/bolt/issues/2692))

  Plans that use the `run_task_with()` plan function can now be tested
  with BoltSpec.

* **`run_container()` plan function**
  ([#2614](https://github.com/puppetlabs/bolt/issues/2614))

  Bolt now ships with a `run_container()` Puppet plan function that will
  run a container and return its output.

* **Update bundled modules**
  ([#2748](https://github.com/puppetlabs/bolt/pull/2748))

  The following bundled modules have been updated to their latest
  versions:

  - [aws_inventory 0.7.0](https://forge.puppet.com/puppetlabs/aws_inventory/0.7.0/changelog)
  - [gcloud_inventory 0.3.0](https://forge.puppet.com/puppetlabs/gcloud_inventory/0.3.0/changelog)

### Bug fixes

* **Do not warn on top level `plugin_hooks` config**
  ([#2742](https://github.com/puppetlabs/bolt/pull/2742))

  Bolt no longer warns that `plugin_hooks` are an unknown option when configured
  in inventory file.

* **Allow `version` key in inventory files**
  ([#2746](https://github.com/puppetlabs/bolt/pull/2746))

  Bolt now recognizes the `version` configuration in an inventory file
  and doesn't raise a warning that the key is unknown.

### Deprecations

* **Deprecate dotted fact names**
  ([#2737](https://github.com/puppetlabs/bolt/issues/2737))

  Dotted fact names (e.g. `foo.bar`) are now deprecated. Bolt issues a
  deprecation warning if it detects a target is loaded with these facts
  or has them added during a plan run.

## Bolt 3.4.0 (2021-03-23)

### New features

* **Display merged stdout and stderr output for commands and scripts**
  ([#2653](https://github.com/puppetlabs/bolt/issues/2653))

  The `bolt command|script run` commands and `Invoke-BoltCommand|Script`
  cmdlets now display merged output from stdout and stderr in the CLI.
  This merged output is also available to the `Result` object in plans
  and in the JSON output format under the `merged_output` key.

* **Convert YAML plans by name**
  ([#2712](https://github.com/puppetlabs/bolt/pull/2712))

  The `bolt plan convert` and `Convert-BoltPlan` commands now accept the
  name of a YAML plan to convert instead of just a path to a YAML plan.

* **Add default value for `prompt` plan function**
  ([#2704](https://github.com/puppetlabs/bolt/issues/2704))

  The `prompt` plan function has a new `default` option which can be
  used to return a default value when a user does not provide input
  or when stdin is not a tty.

* **LXD transport supports remote hosts**
  ([#2669](https://github.com/puppetlabs/bolt/issues/2669))

  The LXD transport includes a new `remote` option to configure
  connections to remote LXD servers.

* **Add welcome message when users first run Bolt**
  ([#2711](https://github.com/puppetlabs/bolt/pull/2711))

  Bolt now prints a welcome message when users first run Bolt if they run
  `bolt`, `bolt --help`, or `bolt help`.

* **`prompt::menu` plan function**
  ([#2714](https://github.com/puppetlabs/bolt/pull/2714))

  The new `prompt::menu` plan function can be used to prompt the user to
  select an option from a menu of options.

* **Upgrade bundled modules**
  ([#2734](https://github.com/puppetlabs/bolt/pull/2734))

  The following bundled modules have been updated to their latest
  versions:

  - [puppet_agent 4.5.0](https://forge.puppet.com/puppetlabs/puppet_agent/4.5.0)
  - [puppet_conf 1.1.0](https://forge.puppet.com/puppetlabs/puppet_conf/1.1.0)
  - [reboot 4.0.2](https://forge.puppet.com/puppetlabs/reboot/4.0.2)

### Bug fixes

* **Ensure `env_vars` is a hash in commands and scripts**
  ([#2689](https://github.com/puppetlabs/bolt/issues/2689))

  Bolt now ensures that the `env_vars` option passed to commands and
  scripts in plans is a hash and will raise a helpful error message
  otherwise.

* **Convert `env_vars` hash values to JSON**
  ([#2689](https://github.com/puppetlabs/bolt/issues/2689))

  Bolt now converts hash values for an environment variable passed to a
  command or script to JSON. Previously, a hash value would be passed
  with Ruby-style syntax.

* **Don't stacktrace when showing tasks that include untyped parameters**
  ([#2719](https://github.com/puppetlabs/bolt/issues/2719))

  Bolt will now correctly show task details for tasks that include
  parameters that do not specify a type, instead of stacktracing.

* **Do not error when showing 'noop' task info**
  ([#2722](https://github.com/puppetlabs/bolt/pull/2722))

  Bolt no longer errors when printing task information for a task that
  supports running in no-operation mode.

* **Handle malformed `_error` values in task results in Orchestrator**
  ([#2723](https://github.com/puppetlabs/bolt/pull/2723))

  Bolt now handles `_error` from task results in the Orchestrator
  transport when the value of the key is not a hash, does not include the
  `details` key, or the `details` key is not a hash. Previously Bolt would
  error if any of these conditions was true.

## Bolt 3.3.0 (2021-03-15)

### New features

* **Add LXD transport**
  ([#2311](https://github.com/puppetlabs/bolt/issues/2311))

  Bolt now includes a new LXD transport to use when connecting with containers
  managed with LXD. See the [transport configuration
  reference](https://puppet.com/docs/bolt/latest/bolt_transports_reference.html#lxd)
  for configuration options. _This feature is experimental and might change
  between minor versions._ 

  _Contributed by [Coleman McFarland](https://github.com/dontlaugh)_

* **Stream output from targets**
  ([#102](https://github.com/puppetlabs/bolt/issues/102))

  You can now stream output from a target as actions are running using the
  `stream` configuration option or the `--stream` command-line option. For more
  information, see [the
  documentation](https://puppet.com/docs/bolt/latest/experimental_features.html#streaming-output).
  _This feature is experimental and might change between minor versions._

* **Support metaparameters as top-level keys in YAML plan steps**
  ([#2629](https://github.com/puppetlabs/bolt/issues/2629))

  YAML plan steps now support metaparameters as top-level keys. For
  example, the `script` step supports an `env_vars` key which accepts a
  hash of environment variables to set on the target when running the
  script.

* **Show plan descriptions in plan list**
  ([#2678](https://github.com/puppetlabs/bolt/pull/2678))

  Plan descriptions now appear in `bolt plan show` and `Get-BoltPlan`
  output.

* **Support Puppet paths when running scripts from the CLI**
  ([#2652](https://github.com/puppetlabs/bolt/issues/2652))

  You can now use Puppet paths (`<MODULE NAME>/<FILE NAME>`) to specify
  the path to a script when running `bolt script run` or
  `Invoke-BoltScript`.

* **Add `pwsh_params` option to `run_script` plan function**
  ([#2651](https://github.com/puppetlabs/bolt/issues/2651))

  The `run_script` plan function now accepts a `pwsh_params` option
  which can be used to pass named parameters to a PowerShell script.

* **Upgrade bundled modules to latest versions**

  Several of Bolt's bundled modules have been upgraded to their latest
  versions. Some modules have been upgraded to new major versions, which
  are not compatible with Puppet 5. Bolt officially dropped support for
  Puppet 5 in Bolt 3.0.

  The following modules have been upgraded to new major versions:

  - [puppetlabs-package 2.0.0](https://forge.puppet.com/puppetlabs/package)
  - [puppetlabs-puppet_conf 1.0.0](https://forge.puppet.com/puppetlabs/puppet_conf)
  - [puppetlabs-scheduled_task 3.0.0](https://forge.puppet.com/puppetlabs/scheduled_task)
  - [puppetlabs-service 2.0.0](https://forge.puppet.com/puppetlabs/service)
  - [puppetlabs-stdlib 7.0.0](https://forge.puppet.com/puppetlabs/stdlib)
  - [puppetlabs-reboot 4.0.0](https://forge.puppet.com/puppetlabs/reboot)

  The following module has been upgraded to the latest version and is
  still compatible with Puppet 5:

  - [puppetlabs-augeas_core 1.1.2](https://forge.puppetcom/puppetlabs/augeas_core)

* **New analytics about plan function file source**
  ([#2687](https://github.com/puppetlabs/bolt/pull/2687))

  Bolt now reports whether a file path is an absolute path or a Puppet file path
  for the `run_script`, `file::read`, and `upload_file` plan functions.

### Bug fixes

* **Handle plan parameter tags without descriptions**
  ([#2672](https://github.com/puppetlabs/bolt/issues/2672))

  Bolt no longer errors if a plan includes a Puppet strings `@param` tag
  that does not have a description.

* **Run YAML plan `plan` steps with `targets` key**
  ([#2677](https://github.com/puppetlabs/bolt/pull/2677))

  YAML plans that have a `plan` step with a top-level `targets` key now
  pass the targets to the plan.

* **Test YAML plans with BoltSpec**
  ([#2682](https://github.com/puppetlabs/bolt/pull/2682))

  YAML plans can now be tested with BoltSpec.

* **Convert YAML plans with a `null` eval step**
  ([#2677](https://github.com/puppetlabs/bolt/pull/2677))

  YAML plans that include a `null` eval step no longer raise an error
  when converted to a Puppet language plan.

* **Correctly read SSL key contents in `http_request` task**
  ([#2693](https://github.com/puppetlabs/bolt/pull/2693))

  The `http_request` now correctly reads key contents from the path passed to
  the `key` parameter. Previously, the task used the file path itself as the key
  contents.

* **Support `run-as` configuration when downloading files**
  ([#2679](https://github.com/puppetlabs/bolt/issues/2679))

  The `run-as` configuration for the SSH transport is now supported when
  downloading files.

* **Do not send task parameters over stdin when using a tty**
  ([#2680](https://github.com/puppetlabs/bolt/issues/2680))

  Tasks with a `stdin` input method that are run on targets with `tty:
  true` configuration no longer return the task's parameters as part of
  the task output. Previously, Bolt was sending these parameters to the
  task twice, causing them to be printed to standard out (stdout) and
  returned in the task output.

## Bolt 3.2.0

_This version of Bolt was not released._

## Bolt 3.1.0 (2021-03-01)

### New features

* **Add Bolt Task directory to PSModulePath**
  ([#2633](https://github.com/puppetlabs/bolt/pull/2633))

  Add the bolt task target directory to the PSModulePath to allow Bolt tasks to
  ship powershell modules that can be automatically imported

* **Ship with `puppetlabs/powershell_task_helper` module**
  ([#2639](https://github.com/puppetlabs/bolt/issues/2639))

  Bolt now ships with the `puppetlabs/powershell_task_helper` module, which
  includes helpers for writing tasks in PowerShell.

* **Added `config_data` helper to `BoltSpec` library**
  ([#2615](https://github.com/puppetlabs/bolt/issues/2615))

  The `BoltSpec` library includes a new `config_data` helper which can be used
  to set Bolt configuration in your plan unit tests.

### Bug fixes

* **Support Puppet file syntax for files in a Bolt project**
  ([#2504](https://github.com/puppetlabs/bolt/issues/2504))

  Bolt now supports Puppet file syntax (`puppet:///modules/<MODULE>/<FILE>`) in
  apply blocks for files in a Bolt projec. Previously, apply blocks would not
  compile if using this syntax for files in a Bolt project.

* **Serialize Sensitive task output for `Result.to_data` method**
  ([#2633](https://github.com/puppetlabs/bolt/pull/2663))

  Previously, the `to_data` method on a `Result` object did not transform
  `Sensitive` task output. Now, the `to_data` method serializes the output by
  calling the `to_s` method on `Sensitive` output, which will simply print a
  "value redacted" message.

* **Improve error messages for `bolt script` in PowerShell**
  ([#2659](https://github.com/puppetlabs/bolt/issues/2659))

  Errors raised from running scripts in PowerShell on targets with an execution
  policy of `Restricted` or `AllSigned` now include clearer messages.

* **Expose inventory to `BoltSpec` stubs and mocks**
  ([#2615](https://github.com/puppetlabs/bolt/issues/2615))

  Stubs and mocks that use the `return_from_targets` modifier now have access to
  Bolt's inventory. Previously, the inventory was not exposed to these stubs and
  mocks, resulting in 'Undefined method' errors.

## Bolt 3.0.1 (2021-02-16)

### Bug fixes

* **Install Puppetfile without `modules` configured**

  Bolt now correctly installs a Puppetfile with `bolt module install
  --no-resolve` and `Install-BoltModule -NoResolve` even if the
  `modules` key is not configured or is an empty array.

* **Fix PowerShell Cmdlet Version detection** ([#2636](https://github.com/puppetlabs/bolt/pull/2636))

  PowerShell users can now run `Get-BoltVersion` to list the Bolt version. This, and `bolt
  --version` should both load more quickly.

## Bolt 3.0.0 (2021-02-03)

### New features

* **Ship with Puppet 7**
  ([#2547](https://github.com/puppetlabs/bolt/issues/2547))

  The Bolt gem and Bolt packages now ship with Puppet 7.

* **Use `bolt.bat` for execution on Windows**
  ([#2551](https://github.com/puppetlabs/bolt/issues/2551))

   This removes the `bolt` PowerShell function and instead relies on a new
   `bolt.bat` file that is included in Bolt packages.

* **Update default modulepath**
  ([#2549](https://github.com/puppetlabs/bolt/issues/2549))

  Bolt's default modulepath is now `['modules']` instead of `['modules', 'site',
  'site-modules']`. Bolt will also automatically append the project's
  `.modules/` directory to all modulepaths, whether a project uses the default
  modulepath or a configured modulepath.

* **Improve bolt powershell task error message**
  ([#2509](https://github.com/puppetlabs/bolt/issues/2509))

  Format the exception powershell type tasks throw to make it easier for a user
  to read the error message.

* **Local transport's `bundled-ruby` option defaults to true**
  ([#2552](https://github.com/puppetlabs/bolt/issues/2552))

  The local transport's `bundled-ruby` configuration option, which determines
  whether to use the Ruby bundled with Bolt packages for local targets, now
  defaults to 'true' instead of 'false'. The option can still be configured as
  before.

* **Ship with puppetlabs/stdlib 6.6.0**
  ([#2606](https://github.com/puppetlabs/bolt/pull/2606))

  Bolt packages now ship with the latest version of the puppetlabs/stdlib
  module.

### Bug fixes

* **Include plan name in `missing_plan_parameter` warnings**
  ([#2588](https://github.com/puppetlabs/bolt/issues/2588))

  The `missing_plan_parameter` warning now includes the name of the plan
  that the message was logged for.

### Removals

* **Remove support for the `bolt.yaml` configuration file**
  ([#2557](https://github.com/puppetlabs/bolt/issues/2557))

  The `bolt.yaml` configuration file is no longer supported by Bolt. Use
  `bolt-project.yaml` and `bolt-defaults.yaml` instead.

* **Remove support for Debian 8**
  ([#2556](https://github.com/puppetlabs/bolt/issues/2556))

  Bolt no longer builds or tests packages for the Debian 8 platform.

* **Remove support for puppet-agent < 6.0.0**
  ([#2422](https://github.com/puppetlabs/bolt/issues/2422))

  Bolt no longer supports puppet-agent versions earlier than 6.0.0.
  While applying Puppet code to targets with earlier versions of the
  puppet-agent package installed may still succeed, Bolt no longer
  guarantees compatibility.

* **Remove support for PowerShell 2.0**
  ([#2561](https://github.com/puppetlabs/bolt/issues/2561))

  Bolt no longer supports PowerShell 2.0 on the controller or on
  targets. While running commands and tasks in PowerShell 2.0 may
  still succeed, Bolt no longer guarantees compatibility.

* **Remove deprecated command-line options**
  ([#2559](https://github.com/puppetlabs/bolt/issues/2559))

  The `--boltdir`, `--configfile`, `--debug`, `--description`, and
  `--puppetfile` command-line options have been removed.

* **Remove deprecated configuration options**
  ([#2553](https://github.com/puppetlabs/bolt/issues/2553))

  The `apply_settings`, `inventoryfile`, `plugin_hooks`, and
  `puppetfile` configuration options have been removed.

* **Remove `notice` log level**
  ([#2560](https://github.com/puppetlabs/bolt/issues/2560))

  Bolt no longer accepts `notice` as a log level, via the command line
  or configuration. Use `info` instead.

* **Remove `bolt puppetfile` subcommand**
  ([#2558](https://github.com/puppetlabs/bolt/issues/2558))

  Removes the `bolt puppetfile *` and `*-BoltPuppetfile` subcommands. Use
  the `bolt module *` and `*-BoltModule` subcommands instead.

* **Remove support for `private-key`, `public-key` parameters in pkcs7 plugin**
  ([#2555](https://github.com/puppetlabs/bolt/issues/2555))

  Support for the `private-key` and `public-key` parameters in the pkcs7
  plugin has been removed. Use the `private_key` and `public_key`
  parameters instead.

* **Remove `source` and `target` YAML plan step keys**
  ([#2554](https://github.com/puppetlabs/bolt/issues/2554))

  Support for the `source` and `target` keys in YAML plans has been
  removed. Use `upload` and `targets` instead.

* **Remove `aggregate::nodes` plan**
  ([#2565](https://github.com/puppetlabs/bolt/issues/2565))

  Bolt no longer ships with the `aggregate::nodes` plan. Use the
  `aggregate::targets` plan instead.

## Bolt 2.44.0 (2021-01-27)

### New features

* **Hide private plans from `bolt plan show` and `Get-BoltPlan`**
  ([#1549](https://github.com/puppetlabs/bolt/issues/1549))

  Users can now set the top-level `private` key in YAML plans, or the `@private`
  Puppet string, to mark a plan as private.

* **Add `read-timeout` configuration option for PCP transport**
  ([#2518](https://github.com/puppetlabs/bolt/issues/2518))

  Users can now configure a `read-timeout` for HTTP requests to the
  Orchestrator, which defines how long to wait for a response before raising a
  Timeout error.

* **Support additional Puppet settings in `apply-settings`**
  ([#2516](https://github.com/puppetlabs/bolt/issues/2516))

  The `log_level`, `trace`, and `evaltrace` Puppet settings can now be
  configured under the `apply-settings` configuration option. These settings
  will be applied when executing an apply block.

* **Add `resolve` key for Forge and git module specifications**
  ([#2522](https://github.com/puppetlabs/bolt/issues/2522))

  Forge and git module specifications in `bolt-project.yaml` now support a
  `resolve` key. When setting `resolve: false`, Bolt will skip dependency
  resolution for the module, allowing users to include modules with broken
  metadata or modules hosted in a repository other than a public GitHub
  repository in their project configuration.

* **Bolt modules usable with Puppet 7**

  Modules owned by the Bolt team now have a maximum Puppet version of 8, so are
  usable with Puppet 7 on the Bolt controller.

* **Suppress warnings with `disable-warnings` config option**
  ([#2542](https://github.com/puppetlabs/bolt/issues/2542))

  The `disable-warnings` configuration option accepts an array of warning IDs
  that are used to suppress warnings in both the CLI and log files. This
  configuration option is supported in both `bolt-project.yaml` and
  `bolt-defaults.yaml`.

### Bug fixes

* **Only spin while executing `run_*` plan functions**
  ([#2511](https://github.com/puppetlabs/bolt/issues/2511))

  Bolt will now only print the spinner while executing `run_*`, `file_upload`,
  `file_download`, and`wait_until_available` plan functions. It also now spins
  while running those functions equivalent commandline commands. This prevents
  the spinner from spinning while prompting for output from a plan.

* **Correctly shadow fact/variable collisions in apply blocks**
  ([#2111](https://github.com/puppetlabs/bolt/issues/2111))

  Bolt now correctly shadows target and plan variables that collide with facts
  of the same name when running apply blocks.

* **Don't continue executing parallel block when prompting**
  ([#2543](https://github.com/puppetlabs/bolt/issues/2543))

  Bolt will now pause printing messages from parallel blocks when prompting the
  user for input, to avoid confusing printing to the screen.

## Bolt 2.42.0 (2021-01-11)

### New features

* **Support `module-install` config when resolving modules**
  ([#2478](https://github.com/puppetlabs/bolt/issues/2478))

  The `bolt module add|install` commands and `Add|Install-BoltModule`
  cmdlets now support the `module-install` config option when resolving
  module dependencies.

* **Updated bundled modules to latest version**
  ([#2514](https://github.com/puppetlabs/bolt/issues/2514))

  The following bundled modules have been updated to their latest
  versions:

  - [facts 1.3.0](https://forge.puppet.com/puppetlabs/facts/1.3.0)
  - [package 1.4.0](https://forge.puppet.com/puppetlabs/package/1.4.0)
  - [puppet_agent 4.3.0](https://forge.puppet.com/puppetlabs/puppet_agent/4.3.0)
  - [puppet_conf 0.8.0](https://forge.puppet.com/puppetlabs/puppet_conf/0.8.0)
  - [reboot 3.1.0](https://forge.puppet.com/puppetlabs/reboot/3.1.0)
  - [scheduled_task 2.3.1](https://forge.puppet.com/puppetlabs/scheduled_task/2.3.1)
  - [service 1.4.0](https://forge.puppet.com/puppetlabs/service/1.4.0)

* **Support for project-level plugins**
  ([#2517](https://github.com/puppetlabs/bolt/issues/2517))

  Bolt now supports project-level plugins. Similar to module plugins,
  project-level plugins are implemented as tasks that use specific hooks
  and are referred to using the name of the project.

### Bug fixes

* **Allow entire inventory to be specified with a plugin**
  ([#2475](https://github.com/puppetlabs/bolt/issues/2475))

  Inventory files can now be specified with a plugin. For example, the
  following inventory file is now valid:

  ```yaml
  ---
  _plugin: yaml
  filepath: /path/to/inventory_partial.yaml
  ```

* **Delete transport config keys that resolved to `nil`**
  ([#2512](https://github.com/puppetlabs/bolt/pull/2512))

  Previously, if a plugin reference resolved a transport config key to `nil`
  Bolt would still include that key in the target's transport config. This
  change ensures that `nil`-resolved transport config keys are deleted during
  inventory parsing.

* **Don't stacktrace when converting YAML plans with errors**
  ([#2515](https://github.com/puppetlabs/bolt/pull/2515))

  Bolt will now error cleanly instead of stacktracing when users try to
  convert a YAML plan that has type or syntax errors.

### Deprecations

* **Deprecate `puppetfile` in favor of `module-install`**
  ([#2361](https://github.com/puppetlabs/bolt/issues/2361))

  The `puppetfile` configuration option has been deprecated in favor of
  `module-install` and will be removed in Bolt 3.0. Users should update
  their projects to use the module management feature, which uses the
  `module-install` option.

* **Deprecate `puppetfile` commands**
  ([#2361](https://github.com/puppetlabs/bolt/issues/2361))

  The `bolt puppetfile *` commands and `*-BoltPuppetfile` cmdlets have
  been deprecated and will be removed in Bolt 3.0. Users should update
  their projects to use the module management feature, which uses the
  `bolt module *` commands and `*-BoltModule` cmdlets.

## Bolt 2.40.2 (2020-12-18)

### Bug fixes

* **Only print spinner when stdout is a TTY** ([#2500](https://github.com/puppletabs/bolt/issues/2500))

  We now only print the spinner when the STDOUT stream is a TTY.

* **Do not add `localhost` target to the `all` group by default in
  PowerShell**
  ([#2505](https://github.com/puppetlabs/bolt/issues/2505))

  Bolt no longer adds the `localhost` target to the `all` group by
  default. Previously, when running Bolt in PowerShell, the `localhost`
  target would be added to the `all` group unintentionally.

## Bolt 2.40.1 (2020-12-16)

### Bug fixes

* **Fix bug warning about keys under 'remote' transport**
  ([#2477](https://github.com/puppetlabs/bolt/issues/2477))

  Bolt now will not warn when keys are configured for the `remote`
  transport in inventory.

* **Support plugins for suboptions under options that allow plugins**
  ([#2483](https://github.com/puppetlabs/bolt/pull/2483))

  All suboptions for config options that support plugins once again
  support plugins. For example, the `key-data` suboption for the
  `private-key` option can use plugins again.

* **Load the correct data for plugin invocations**
  ([#2487](https://github.com/puppetlabs/bolt/pull/2487))

  Bolt now correctly loads data for the plugin invocation based on the
  plugin data, not just cache `ttl`. Previously, any plugins with the
  same cache configuration would collide in the cache data and overwrite
  each other, causing the wrong data to be loaded.

## Bolt 2.38.0 (2020-12-14)

### New features

* **`bundled-ruby` local transport config option to enable local defaults**
  ([#2400](https://github.com/puppetlabs/bolt/issues/2400))

  Set `bundled-ruby` in the local transport config to enable or disable
  the default config currently used for the `localhost` target.

* **`module-install` configuration option**
  ([#2303](https://github.com/puppetlabs/bolt/issues/2303))

  Bolt now supports a `module-install` configuration option in
  `bolt-project.yaml` and `bolt-defaults.yaml`. This option is used to
  configure proxies and an alternate forge when installing modules using
  the `bolt module add|install` commands or `Add|Install-BoltModule`
  cmdlets.

  _This option is not currently supported when resolving module
  dependencies._

* **Improved inventory validation**
  ([#2413](https://github.com/puppetlabs/bolt/issues/2413))

  Bolt now validates inventory against Bolt's inventory schema and
  indicates where errors are found.

* **CLI spinner for long running operations**
  ([#2432](https://github.com/puppetlabs/bolt/pull/2432))

  Bolt now has a spinner printed to the CLI for long-running operations,
  so that users know the Bolt process has not hung. Disable the spinner
  by setting `spinner: false` in any Bolt configuration file.

* **JSON schema for YAML plans**
  ([#2046](https://github.com/puppetlabs/bolt/issues/2046))

  Bolt now offers a JSON schema for validating YAML plans.

### Bug fixes

* **Windows local transport returns correct exit codes and accepts pipes**
  ([#2299](https://github.com/puppetlabs/bolt/issues/2299))

  When running commands over the local transport on Windows machines,
  Bolt now returns the exit code returned by the command as opposed to
  just 0 or 1. It also accepts pipes as part of the command.

* **Accept plugins in `puppetdb` config**
  ([#2461](https://github.com/puppetlabs/bolt/issues/2461))

  Fixes a regression to once again allow plugins to be used for defining
  the values of the `puppetdb` config.

  _Contributed by [Nick Maludy](https://github.com/nmaludy)_

* **Only warn that project content won't be loaded if there's project content**
  ([#2438](https://github.com/puppetlabs/bolt/pull/2468))

  Bolt will now only warn that project content won't be loaded if the
  proejct directory has a `tasks/`, `plans/`, or `files/` directory that
  may contain content.

* **Allow caching for PuppetDB plugin**
  ([#2469](https://github.com/puppetlabs/bolt/pull/2469))

  Previously, our configuration validation would raise an error if users
  supplied `_cache` to the PuppetDB plugin. Cache is now configurable
  for the plugin.

* **`http_request` task converts header names to strings**
  ([#4](https://github.com/puppetlabs/puppetlabs-http_request/pull/4)

  Headers set under the `headers` parameter are now converted to strings before
  making a request. Previously, headers were passed to the request as symbols.

  _Contributed by [barskern](https://github.com/barskern)_

## Bolt 2.37.0 (2020-12-07)

### New features

* **Plugin caching**
  ([#2383](https://github.com/puppetlabs/bolt/pull/2383))

  Bolt plugins can now be configured to cache their results. Users can either
  configure a default cache time-to-live for all plugins, or configure each
  plugin's TTL individually. See [the documentation](https://pup.pt/bolt-cache)
  for more information.

  _This feature is considered experimental._

### Bug fixes

* **Support `notice` log level**
  ([#2410](https://github.com/puppetlabs/bolt/pull/2410))

  Log levels can now be set to `notice`. Previously, Bolt would raise an
  error saying that `notice` was not a supported log level.

### Deprecations

* **Deprecate Powershell 2 support**
  ([#2365](https://github.com/puppetlabs/bolt/issues/2365))

  Support for Powershell 2 on both Bolt targets and controllers is
  deprecated, and will be dropped in Bolt 3.0.

* **Deprecate bolt.yaml**
  ([#2000](https://github.com/puppetlabs/issues/2000))

  The `bolt.yaml` configuration file is now deprecated, both at
  project-level and user/system-level.

* **Deprecate `notice` log level**
  ([#2410](https://github.com/puppetlabs/bolt/pull/2410))

  The `notice` log level is deprecated and will be removed in Bolt 3.0.
  Use the `info` log level instead.

## Bolt 2.36.0 (2020-11-30)

### New features

* **`bolt plan new` and `New-BoltPlan` commands no longer experimental**

  The `bolt plan new` and `New-BoltPlan` commands are no longer
  considered experimental.

* **Module management workflow no longer experimental**

  The module management workflow is no longer considered experimental. For more
  information, see the [modules
  overview](https://puppet.com/docs/bolt/latest/modules.html) in the Bolt
  documentation.

* **Configure `modules` with `bolt project init`**
  ([#2110](https://github.com/puppetlabs/bolt/issues/2210))

  The `bolt project init` command will now configure the `modules` key
  in the `bolt-project.yaml` file, enabling the `bolt module` command.

* **Create `inventory.yaml` file when creating new projects**
  ([#2364](https://github.com/puppetlabs/bolt/issues/2364))

  The `bolt project init` and `New-BoltProject` commands now create an
  `inventory.yaml` file in the new project.

* **Log plugin task output at `trace` level**
  ([#2336](https://github.com/puppetlabs/bolt/issues/2336))

  Plugin task output is now logged at `trace` level.

* **Improved config validation**
  ([#2337](https://github.com/puppetlabs/bolt/issues/2337))

  Bolt now validates config files against Bolt's schemas and indicates
  which config file an error is found in.

* **Warn about unknown configuration options**
  ([#2376](https://github.com/puppetlabs/bolt/issues/2376))

  Bolt now issues a warning when it detects an unknown configuration
  option. The warning will indicate where the configuration option is
  located.

* **Added `value()` function to `ApplyResult` datatype**
  ([#2370](https://github.com/puppetlabs/bolt/issues/2370))

  The `ApplyResult` datatype has a new `value()` function that returns a
  hash that includes the Puppet report from an apply under the `report`
  key.

### Bug fixes

* **Targets without a uri can now use `apply()` and `get_resources()`**
  ([#2346](https://github.com/puppetlabs/bolt/issues/2346))

  Previously, if a target had a `host` set instead of a `uri` it would
  error when trying to set the Puppet certname to the target's URI. We now
  use the target's `name` instead of the `uri` as the Puppet certname when
  compiling catalogs.

* **Allow loading SSH Config through net-ssh when using native-ssh to fail**
  ([#2289](https://github.com/puppetlabs/bolt/issues/2289)

  As skipping loading SSH config through the net-ssh gem is not
  feasible, we allow loading the ssh config to fail and fall back
  to the inventory file settings or the logged in user.

  _Contributed by [Robert Führicht](https://github.com/fuero)_

* **Ship `puppet_agent` manifests directory**
  ([#2368](https://github.com/puppetlabs/bolt/issues/2368))

  Bolt now includes the `puppet_agent` module manifests directory and
  it's classes in the Bolt gem and packages.

### Deprecations

* **Deprecate `--boltdir`, `--configfile`, `--puppetfile`, and `--description`
  command-line options**
  ([#2362](https://github.com/puppetlabs/bolt/issues/2362))

  We are planning to remove the `--boltdir`, `--configfile`,
  `--puppetfile`, and `--description` command line flags in the next major
  version of Bolt. This adds deprecation warnings that are printed when
  users specify any of these flags.

* **Deprecate `inventoryfile` configuration option**
  ([#2363](https://github.com/puppetlabs/bolt/issues/2363))

  The `inventoryfile` configuration option has been deprecated and will
  be removed in Bolt 3.0. Users should move contents from non-default
  inventory files to the `inventory.yaml` file in a Bolt project, or can
  use the `--inventoryfile` command-line option to load a non-default
  inventory file.

* **Deprecate `plugin_hooks` in favor of `plugin-hooks`**
  ([#2358](https://github.com/puppetlabs/bolt/issues/2358))

  The `plugin_hooks` configuration option has been deprecated in favor
  of `plugin-hooks`.

* **Deprecate `apply_settings` in favor of `apply-settings`**
  ([#2357](https://github.com/puppetlabs/bolt/issues/2357))

  The `apply_settings` configuration option has been deprecated in favor
  of `apply-settings`.

## Bolt 2.35.0 (2020-11-16)

### New features

* **Set default ports for PuppetDB and Orchestrator**
  ([#2304](https://github.com/puppetlabs/bolt/issues/2304))

  Bolt now sets the ports for PuppetDB `server_urls` and Orchestrator
  `service-url` to 8081 and 8143 respectively if the port is not set in config.

* **Filter project plans and tasks with glob patterns**
  ([#2180](https://github.com/puppetlabs/bolt/issues/2180))

  The `plans` and `tasks` options in `bolt-project.yaml` now support glob
  patterns in addition to plan and task names. Plans and tasks that match a glob
  pattern will appear in `bolt plan|task show` and `Get-Bolt(Plan|Task)` output.

* **Execute plan functions in parallel with `parallelize` plan function**
  ([#2190](https://github.com/puppetlabs/bolt/pull/2190))

  The new `parallelize` plan function can be used to execute part of a plan in
  parallel. It accepts an array of inputs and a block, executes the block on
  each input, and returns a list of results. This function can be used to
  continue executing part of a plan across multiple targets without waiting on
  results to finish for each target.

  _This feature is experimental._

### Bug fixes

* **Error with invalid YAML plan step type**
  ([#2309](https://github.com/puppetlabs/bolt/issues/2309))

  Bolt now errors if a YAML plan step is not a hash. Previously, YAML plans
  would execute even if a plan step was not a hash.

## Bolt 2.34.0 (2020-11-10)

### New features

* **Create new Puppet language plans with `--pp` flag**
  ([#2327](https://github.com/puppetlabs/bolt/pull/2327))

  Bolt can now create new Puppet language plans using the `bolt plan new` command
  with the `--pp` flag or the `New-BoltPlan` PowerShell cmdlet with the `-Pp`
  parameter.

* **Show PowerShell cmdlets in output when running in PowerShell**
  ([#2326](https://github.com/puppetlabs/bolt/pull/2326))

  Bolt output that includes commands will now show PowerShell cmdlets instead of
  \*nix shell commands when running in PowerShell.

### Bug fixes

* **Fix complicated quoting in PowerShell Cmdlets**
  ([#2272](https://github.com/puppetlabs/bolt/issues/2272))

  When using the Powershell cmdlets module, Bolt no longer wraps each command in
  single quotes allowing users to successfully use more complicated quoting
  patterns.

* **Don't log task output from plugins**
  ([#2329](https://github.com/puppetlabs/bolt/pull/2329))

  Bolt no longer logs the output from plugin tasks, to avoid printing
  sensitive information to logs.

## Bolt 2.33.2 (2020-11-04)

### Bug fixes

* **Fix module name validation for Forge and Git module specifications**
  ([#2314](https://github.com/puppetlabs/bolt/issues/2314))

  Forge and Git module specifications now correctly validate the
  module's name and permit uppercase letters in the owner segment of the
  module name. Previously, if the owner segment of a module name
  included uppercase letters, Bolt would raise an error.

## Bolt 2.33.1 (2020-11-02)

### New features

* **Updated bundled modules to latest version**

  The following bundled modules have been updated to their latest
  versions:

  - [cron_core 1.0.5](https://forge.puppet.com/puppetlabs/cron_core/changelog)
  - [puppet_agent 4.2.0](https://forge.puppet.com/puppetlabs/puppet_agent/changelog)
  - [sshkeys_core 2.2.0](https://forge.puppet.com/puppetlabs/sshkeys_core/changelog)
  - [zfs_core 1.2.0](https://forge.puppet.com/puppetlabs/zfs_core/changelog)

* **Include file and line number in YAML plan code evaluation errors**
  ([#2278](https://github.com/puppetlabs/bolt/issues/2278))

  Errors raised when evaluating code in a YAML plan now include the path
  to the YAML plan and the line number that the error occurred on in the
  plan.

* **File and line number included in plan function errors**
  ([#2057](https://github.com/puppetlabs/bolt/issues/2057))

  If the plan functions `run_command`, `run_script`, or `run_task` fail
  they will now include the file and line number in the `details` key of
  the Result object. This information will also be printed when run with
  info level logging or higher.

### Bug fixes

* **Safely delete tmpdir used to configure Puppet for PAL**
  ([#2245](https://github.com/puppetlabs/bolt/issues/2245))

  Bolt now safely deletes the tmpdir used to configure Puppet when using
  PAL. Previously, if the tmpdir was deleted during a Bolt run before
  Bolt deleted the directory itself, an error with a stacktrace would be
  raised.

* **Do not override SSL variables in PowerShell module**
  ([#2171](https://github.com/puppetlabs/bolt/issues/2171))

  The PowerShell module no longer overrides the `SSL_CERT_FILE` and
  `SSL_CERT_DIR` environment variables if they are already set.

### Removals

* **Folded scalar values in YAML plans no longer evaluated**
  ([#2306](https://github.com/puppetlabs/bolt/pull/2306))

  Folded scalar values in YAML plans are no longer evaluated and are
  instead treated as string literals.

## Bolt 2.32.0 (2020-10-26)

### New features

* **Add `json_endpoint` parameter to `http_request` task**
  ([#2](https://github.com/puppetlabs/puppetlabs-http_request/issues/2))

  The `http_request` task now accepts a `json_endpoint` parameter. When set to
  `true`, the task will convert the request body to JSON, set the `Content-Type`
  header to `application/json`, and parse the response body as JSON.

* **Git module support for module management feature**
  ([#2187](https://github.com/puppetlabs/bolt/issues/2187))

  Git modules can now be specified in `bolt-project.yaml` and used with
  the module management feature. Only GitHub modules are supported.

### Bug fixes

* **Fix 'method not found' error when showing inventory**
  ([#2269](https://github.com/puppetlabs/bolt/pull/2269))

  Previously, when running `bolt inventory show` or `Get-BoltInventory` with a
  configured inventory path and the human format a 'method not found' error was
  raised. This now correctly prints the targets in the inventory.

* **Handle printing preformatted Puppet errors with `out::message`**
  ([#2241](https://github.com/puppetlabs/bolt/issues/2241))

  The `out::message` plan function now correctly prints preformatted
  Puppet errors. Previously, printing preformatted Puppet errors would
  result in a 'stack level too deep' error.

## Bolt 2.31.0 (2020-10-19)

### New features

* **Improved output for `bolt inventory show` and `Get-BoltInventory`**
  ([#2205](https://github.com/puppetlabs/bolt/issues/2205))

  The `bolt inventory show` command and `Get-BoltInventory` cmdlet now show if a
  target was not found in inventory. Output also includes the path to the loaded
  inventory file and the number of inventory targets and adhoc targets.

* **Print changes made to Puppetfile when adding modules**
  ([#2230](https://github.com/puppetlabs/bolt/issues/2230))

  The `bolt module add` command and `Add-BoltModule` cmdlet now display
  a message describing changes made to the Puppetfile, including modules
  that have been added, removed, upgraded, or downgraded.

* **Update bundled modules to latest versions**

  The following bundled modules have been updated to their latest
  versions:

  - [facts 1.1.0](https://forge.puppet.com/puppetlabs/facts)
  - [augeas_core 1.1.1](https://forge.puppet.com/puppetlabs/augeas_core)
  - [scheduled_task 2.2.1](https://forge.puppet.com/puppetlabs/scheduled_task)
  - [sshkeys_core 2.1.0](https://forge.puppet.com/puppetlabs/sshkeys_core)
  - [zfs_core 1.1.0](https://forge.puppet.com/puppetlabs/zfs_core)
  - [cron_core 1.0.4](https://forge.puppet.com/puppetlabs/cron_core)
  - [yumrepo_core 1.0.7](https://forge.puppet.com/puppetlabs/yumrepo_core)
  - [package 1.3.0](https://forge.puppet.com/puppetlabs/package)
  - [stdlib 6.5.0](https://forge.puppet.com/puppetlabs/stdlib)

### Bug fixes

* **Log when default inventory file cannot be loaded**
  ([#2207](https://github.com/puppetlabs/bolt/issues/2207))

  Bolt now logs that it tried but failed to load the default inventory
  file when the default inventory file does not exist. Previously, Bolt
  would log that it loaded the default inventory file, even when it was
  unable to do so.

* **Add moduledir directive to generated Puppetfile**
  ([#2246](https://github.com/puppetlabs/bolt/pull/2246))

  Puppetfiles generated using the `bolt module install` command and
  `Install-BoltModule` cmdlet did not include the `moduledir` directive.

## Bolt 2.30.0 (2020-09-30)

### New features

* **Manage project dependencies with `bolt module` subcommand**
  ([#2082](https://github.com/puppetlabs/bolt/issues/2082),
  [#2083](https://github.com/puppetlabs/bolt/issues/2083),
  [#2131](https://github.com/puppetlabs/bolt/issues/2131),
  [#2134](https://github.com/puppetlabs/bolt/issues/2134),
  [#2135](https://github.com/puppetlabs/bolt/issues/2135),
  [#2182](https://github.com/puppetlabs/bolt/issues/2182),
  [#2184](https://github.com/puppetlabs/bolt/issues/2184))

  The new `bolt module` subcommand and `modules` key in project configuration
  can be used to manage a project's module dependencies, including resolving
  dependencies and version ranges. To learn more about managing a project's
  module dependencies with Bolt, see [the
  documentation](https://pup.pt/bolt-modules). To read about why we added this
  feature, see the [developer
  updates](https://puppet.com/docs/bolt/latest/developer_updates.html).

  _This feature is experimental._

* **HTTP request task**
  ([#2103](https://github.com/puppetlabs/bolt/issues/2103))

  Bolt now ships with the `http_request` module, which includes the
  `http_request` task for making HTTP requests.

### Bug fixes

* **Show missing module dependencies when resolving modules**
  ([#2224](https://github.com/puppetlabs/bolt/pull/2224))

  Bolt now correctly displays the names of missing module dependencies when
  resolving modules errors. Previously, if a module dependency was missing, Bolt
  did not display the name of the missing module.

* **Invalid YAML plans now fail gracefully**
  ([#2197](https://github.com/puppetlabs/bolt/issues/2197))

  Previously, if a YAML plan had a syntax error Bolt would stacktrace due to an
  assumption about what methods the resulting error had. It now fails gracefully
  with the line of the error.

## Bolt 2.29.0 (2020-09-21)

### New features

* **Read command from a file or `stdin` using `bolt command run`**
  ([#2125](https://github.com/puppetlabs/bolt/issues/2125))

  The `bolt command run` command can now read a command from a file or
  `stdin`.

### Bug fixes

* **Reliably initialize logger with Bolt log levels**
  ([#2188](https://github.com/puppetlabs/bolt/issues/2188))

  Bolt now checks whether the logger includes all of Bolt's log levels
  if the logger has already been initialized.

## Bolt 2.28.0 (2020-09-16)

### New features

* **Define Hiera data to be looked up outside apply blocks under plan_hierarchy key** ([#1835](https://github.com/puppetlabs/bolt/issues/1835))

  Previously, Bolt used the same Hiera hierarchy for lookups inside and
  outside apply blocks. Interpolations are only supported in apply blocks,
  so if a hierarchy included interpolations the user could not look up
  data outside an apply block. Users can now define a separate, statically
  configured hierarchy in their Hiera config to be used outside apply
  blocks.

### Bug fixes

* **Fix warning when running from a gem install**

    Bolt again properly detects when it's being run from a gem install
    and emits a warning.

* **Fix error 'no method found trace' error when running BoltSpec**

    There was one place where we didn't properly initialize the Bolt logger, causing a stacktrace
    in some BoltSpec uses. We now properly initialize the Bolt logger.

## Bolt 2.27.0 (2020-09-08)

### New features

* **Bolt will now warn if a project has the same name as a module**
     ([#2108](https://github.com/puppetlabs/bolt/issues/2108))

    Any module with the same name as the Bolt project will be ignored,
    and Bolt will now issue a warning to indicate that.

### Bug fixes

* **Ensure task error objects have correct format**
  ([#2112](https://github.com/puppetlabs/bolt/issues/2112))

  Bolt now ensures that error objects returned from a task have the
  correct format and include a `msg` key. Bolt will also automatically
  add `kind` and `details` keys if they are absent from the object, with
  default values of `bolt/error` and `{}`.

* **Handle project file writing errors more gracefully** ([#2116](https://github.com/puppetlabs/bolt/issues/2116))

  Bolt will now warn and continue executing when it fails to write files
  to the active project. Additionally, any user-specified file data that
  fails to be written to will error.

* **Prevent data for the wrong target being used when compiling `apply()` blocks**
     ([#2156](https://github.com/puppetlabs/bolt/issues/2156))

    Previously, a race condition allowed `apply()` blocks to use data
    for the wrong target during compilation. This could cause targets to
    apply incorrect or invalid catalogs.

## Bolt 2.26.0 (2020-08-31)

### New features

* **Allow task output to be treated as sensitive**
  ([#2086](https://github.com/puppetlabs/bolt/issues/2086))

  Tasks can now return a `_sensitive` key in their output which can
  contain an arbitrary value which will be treated as sensitive by
  Bolt. This means that it won't be printed to the console or logged at
  any log level, and plans will need to use `unwrap()` to get the value.

* **Disable log files by setting them to `disable`**
  ([#2120](https://github.com/puppetlabs/bolt/issues/2120))

  Log files can now be disabled if they were set at a previous level
  of the hierarchy. This also allows the default `bolt-debug.log` file
  to be disabled.

* **Packages for Fedora 32**
  ([#2042](https://github.com/puppetlabs/bolt/issues/2042))

  Bolt packages are now available for Fedora 32.

## Bolt 2.25.0 (2020-08-26)

### New features

* **Add `puppet_agent::run` plan to run the agent**
  ([#2022](https://github.com/puppetlabs/bolt/issues/2022))

  The `puppet_agent::run` plan will run the agent if it's available and returns
  a `ResultSet` including agents that failed and the results from runs that
  succeeded.

### Bug fixes

* **Correctly handle array parameters in PowerShell**
  ([#2118](https://github.com/puppetlabs/bolt/pull/2118))

   Changes the switch statement in the `Get-BoltCommandline` function to an
   `if/else` statement to properly handle parameters that are arrays that are
   not supposed to be unwrapped.

* **Initialize logger in `BoltSpec::Run`**
  ([#2117](https://github.com/puppetlabs/bolt/issues/2117))

  Bolt now initializes the logger when using `BoltSpec::Run` methods.
  Previously, the logger was not initialized with Bolt's custom log
  levels, causing `BoltSpec::Run` to raise an error when it encountered
  a message being logged to one of these custom levels.

## Bolt 2.24.1 (2020-08-24)

### Bug fixes

* **Don't fail if bolt-debug.log can't be created**
  ([#2115](https://github.com/puppetlabs/bolt/issues/2115))

  This fixes a bug introduced in Bolt 2.24.0 where Bolt would fail
  when trying to create the `bolt-debug.log` file if the Bolt project
  didn't exist.

## Bolt 2.24.0 (2020-08-24)

### New features

* **PowerShell validation for `-LogLevel`, `-Rerun`, and `-Filter`**
  ([#2090](https://github.com/puppetlabs/bolt/pull/2090))

  Add PowerShell parameter validation for `-LogLevel`, `-Rerun`, and `-Filter`.

* **Write a default log file**
  ([#2068](https://github.com/puppetlabs/bolt/issues/2068))

  Bolt will now log activity at `debug` level to `bolt-debug.log` in the project
  directory. This log will be truncated each time Bolt runs.

* **View information about Bolt concepts and features from the CLI**
  ([#2078](https://github.com/puppetlabs/bolt/issues/2078))

  Bolt can now display information about various Bolt features and concepts with
  the new CLI command `bolt guide` and PowerShell command `Get-Help
  about_bolt_*`.

* **`bolt project migrate` now updates project files**
  ([#2081](https://github.com/puppetlabs/bolt/issues/2081))

  The `bolt project migrate` command will now update `bolt.yaml` to
  `bolt-project.yaml` and move transport configuration to `inventory.yaml`.
  Modified files are backed up to a `.bolt-bak` directory in the project
  directory.

* **Plan conversion maintains plan and parameter descriptions**
  ([#2039](https://github.com/puppetlabs/bolt/issues/2039))

  Converting a YAML plan to a Puppet plan will now preserve plan and
  parameter descriptions, so that `plan show` output is the same for the
  YAML plan as the converted Puppet plan.

### Bug fixes

* **Fix PowerShell `-Version` parameter**
  ([#2090](https://github.com/puppetlabs/bolt/pull/2090))

  The PowerShell `-Version` parameter now looks at the `RememberedInstallDir`
  property for Bolt's version file location.

* **Show YAML plan parameters without default values as required**
  ([#2095](https://github.com/puppetlabs/bolt/pull/2095))

  Bolt was displaying YAML plan parameters without default values as
  optional in `bolt plan show` output. Now, Bolt will show a parameter
  without a default value as required.

## Bolt 2.23.0 (2020-08-17)

### New features

* **Print objects using `out::message()` plan function**
  ([#2012](https://github.com/puppetlabs/bolt/issues/2012))

  Users can now print any valid data type using the plan function
  `out::message()`.

* **`bolt project init` and `New-BoltProject` now create `bolt-project.yaml`**
  ([#2003](https://github.com/puppetlabs/bolt/issues/2003))

  `bolt project init` and `New-BoltProject` now create a `bolt-project.yaml`
  file instead of `bolt.yaml`. The commands now accept a project name instead
  of a path to the project directory.

* **Set interval for repeating block in `ctrl::do_until` plan function**
  ([#2072](https://github.com/puppetlabs/bolt/issues/2072))

  The `ctrl::do_until` plan function now accepts an `interval` option.
  This option accepts a numeric value that specifies the number of
  seconds to wait before repeating the block.

### Bug fixes

* **Include `modules/` in displayed modulepath if it's in the user-configured
  modulepath**

  Bolt now includes `<bolt-installation-directory>/modules` in the displayed
  modulepath if the user has the path as a component of their configured
  modulepath. If installed as a package on *nix, bolt-installation-directory
  would be `/opt/puppetlabs/bolt/lib/ruby/gems/2.5.0/gems/bolt-x.y.z/`.

* **Do not error when analytics configuration file is empty**

  Empty analytics configuration files would cause Bolt to raise a
  `NoMethodError`. Now, if an analytics configuration file is empty,
  Bolt will instead rewrite the file.

* **Correctly pass objects to YAML plan message step**

  Bolt was incorrectly passing objects used in the YAML plan `message`
  step, resulting in an error. Any objects used in YAML plan `message`
  steps are now correctly passed and printed to the console.

## Bolt 2.22.0 (2020-08-10)

### New features

* **Use `-Name` parameters in PowerShell task and plan cmdlets**
  ([#2049](https://github.com/puppetlabs/bolt/issues/2049))

  The `Get|Invoke-BoltTask` and `Get|Invoke-BoltPlan` cmdlets now use
  a `-Name` parameter instead of `-Task` and `-Plan` to specify the
  name of a task or plan.

* **Create new project-level YAML plans with `bolt plan new`**
  ([#2004](https://github.com/puppetlabs/bolt/issues/2004))

  Users can now quickly get started with writing a new project-level
  YAML plan using the `bolt plan new` command. The command accepts a
  single argument, the name of the plan to be generated, and creates the
  necessary directories and file in the project's `plans` directory.

  > **Note:** This feature is experimental and is subject to change.

### Bug fixes

* **Do not modify order of plan variables in catalog compilation**
  ([#2025](https://github.com/puppetlabs/bolt/issues/2025))

  Bolt will no longer error during catalog compilation when a plan
  variable shares the same name as a target variable. Previously, Bolt
  would modify the order plan variables were listed in a catalog if they
  shared the name of a target variable, causing catalog compilation to
  fail when deserializing variables.

* **Fix parameter description parsing in PowerShell module**
  ([#2049](https://github.com/puppetlabs/bolt/issues/2049))

  Removes encoding HTML special characters from the parameter description
  fields in the PowerShell module.

* **Reject multi-line project names**
  ([#2061](https://github.com/puppetlabs/bolt/pull/2061))

  Previously, Bolt would accept a multi-line string as a project name,
  causing multiple errors. Bolt will now reject multi-line strings as
  project names.

## Bolt 2.21.0 (2020-08-03)

### New features

* **Specify remote environment variables using `--env-var`**
  ([#1980](https://github.com/puppetlabs/bolt/issue/1980))

  Users can now set environment variables on targets when running
  commands and scripts using the `--env-var` CLI option.

* **Add `secure_env_vars` plan**
  ([#1980](https://github.com/puppetlabs/bolt/issues/1980))

  The new builtin Bolt plan `secure_env_vars` reads JSON from a  special
  environment variable, `BOLT_ENV_VARS`, and passes that hash to either
  `run_command` or `run_script`.

* **YAML plan `message` step**
  ([#2038](https://github.com/puppetlabs/bolt/issues/2038))

  YAML plans now support a `message` step that prints a message.

* **Service task now supports `enable` and `disable` when available**
  ([puppetlabs-service#151](https://github.com/puppetlabs/puppetlabs-service/pull/151))

  The builtin Bolt `service` task now supports `enable` and `disable`
  actions for agentless targets if the actions are available on the target.

* **New `dir::children` plan function**
  ([#2047](https://github.com/puppetlabs/bolt/pull/2047))

  The new plan function `dir::children` returns an array containing all of
  the filenames in the given directory, similar to Ruby's `Dir.children()`.

### Bug fixes

* **Gracefully handle WinRM connection loss**
  ([#1982](https://github.com/puppetlabs/bolt/issues/1982))

  Bolt will now detect WinRM connection loss and return an error
  rather than printing a stacktrace and deadlocking.

* **Handle existing file errors when downloading files**
  ([#2054](https://github.com/puppetlabs/bolt/pull/2054))

  Bolt now handles existing file errors raised when creating the
  destination directory for file downloads. Previously, if a file
  already existed somewhere on the destination directory path, Bolt
  would raise an error with a full backtrace.

## Bolt 2.20.0 (2020-07-27)

### New features

* **Added `bolt file download` CLI command**
  ([#1868](https://github.com/puppetlabs/bolt/issues/1868))

  Users can now download files and directories from targets to the local
  system using the `bolt file download` CLI command. This command
  accepts a path to the file or directory to download from the targets
  and a path to a destination directory on the local system. The
  destination directory is expanded relative to the project downloads
  directory, `<project>/downloads/`.

* **Add `download_file` plan function**
  ([#1868](https://github.com/puppetlabs/bolt/issues/1868))

  The `download_file` plan function can be used to download a file or
  directory from a list of targets to a destination directory on the
  local system. The result returned from this function includes the path
  to the downloaded file on the local system.

* **Add YAML plan download step**
  ([#1868](https://github.com/puppetlabs/bolt/issues/1868))

  YAML plans now support a download step which can be used to download a
  file or directory from a list of targets to a destination directory on
  the local system.

* **Add `allow_download` and `expect_download` stubs to BoltSpec**
  ([#1868](https://github.com/puppetlabs/bolt/issues/1868))

  Users can use the `allow_download` and `expect_download` stubs to test
  plans that contain calls to `download_file`.

* **Ship Bolt with PowerShell cmdlets on Windows**
  ([#1895](https://github.com/puppetlabs/bolt/issues/1895))

  Bolt now ships with PowerShell cmdlets on Windows. All Bolt commands are
  mapped to PowerShell cmdlets following approved verb-noun conventions.
  Unix-like CLI options are also mapped to equivalent PowerShell names
  (i.e. `--targets` becomes `-targets`).

  The PowerShell cmdlets are autogenerated from Bolt's source code, ensuring
  both command-level and parameter-level help is available in the PowerShell
  help system.

  Bolt commands are mapped to the following cmdlets:

  | Bolt | PowerShell |
  | --- | --- |
  | `bolt apply`  | `Invoke-BoltApply` |
  | `bolt command run` | `Invoke-BoltCommand` |
  | `bolt file download` | `Receive-BoltFile` |
  | `bolt file upload` | `Send-BoltFile` |
  | `bolt group show` | `Get-BoltGroup` |
  | `bolt inventory show` | `Get-BoltInventory` |
  | `bolt plan convert` | `Convert-BoltPlan` |
  | `bolt plan run` | `Invoke-BoltPlan` |
  | `bolt plan show` | `Get-BoltPlan` |
  | `bolt project init` | `New-BoltProject` |
  | `bolt project migrate` | `Update-BoltProject` |
  | `bolt puppetfile generate-types` | `Register-BoltPuppetfileTypes` |
  | `bolt puppetfile install` | `Install-BoltPuppetfile` |
  | `bolt puppetfile show-modules` | `Get-BoltPuppetfileModules` |
  | `bolt script run` | `Invoke-BoltScript` |
  | `bolt secret createkeys` | `New-BoltSecretKey` |
  | `bolt secret decrypt` | `Unprotect-BoltSecret` |
  | `bolt secret encrypt` | `Protect-BoltSecret` |
  | `bolt task run` | `Invoke-BoltTask` |
  | `bolt task show` | `Get-BoltTask` |

* **Configure connection and read timeout length in PuppetDB client**
  ([#1994](https://github.com/puppetlabs/bolt/issues/1994))

  Users can now configure the connection and read timeout length for the
  PuppetDB client with the `connect_timeout` and `read_timeout`
  options under the `puppetdb` config option.

* **Environment preservation permission no longer required when using run-as**
  ([#1993](https://github.com/puppetlabs/bolt/issues/1993))

  Bolt no longer passes the `-E` flag to sudo when building commands
  using 'run-as', which allows users who do not have permission to use the
  flag to use Bolt.

### Bug fixes

* **Do not re-rescue errors raised before config is loaded**
  ([#2005](https://github.com/puppetlabs/bolt/pull/2005))

  Errors raised before Bolt's configuration was loaded were raising a
  second, ambiguous `NoMethodError`. Bolt now correctly handles errors
  raised before configuration is loaded and will no longer trigger
  additional errors.

### Deprecations

* **Deprecate `source` key for YAML plan upload step**
  ([#1868](https://github.com/puppetlabs/bolt/issues/1868))

  The `source` key used in YAML plan upload steps has been deprecated in
  favor of a less ambiguous `upload` key.

## Bolt 2.19.0 (2020-07-20)

### New features

* **Support rainbow format on Windows 10**
  ([#1983](https://github.com/puppetlabs/bolt/pull/1983))

  The `rainbow` format is now supported on Windows 10.

### Bug fixes

* **Do not fail for tasks referring to project-level files**
    ([#1984](https://github.com/puppetlabs/bolt/issues/1984))

    Tasks with a `files` key that refers to files that exist at the
    project level will now load properly rather than throwing an error.

## Bolt 2.18.0 (2020-07-13)

### New features

* **Specify module plugins to sync during apply and apply prep**
  ([#1934](https://github.com/puppetlabs/bolt/issues/1934))

  The `apply_prep` and `apply` plan functions now accept a `_required_modules`
  option that allows plan authors to specify a list of module plugins to
  sync to targets. When the `_required_modules` option is not set, all module
  plugins will be synced.

  _Contributed by [Bert Hajee](https://github.com/hajee)_

* **Use `native-ssh` config option to enable native SSH**
  ([#1938](https://github.com/puppetlabs/issues/1938))

  Use the new `native-ssh` SSH transport configuration option or
  `--native-ssh` CLI option to opt-in to the experimental native SSH.
  The SSH transport configuration option `ssh-command` no longer enables
  native SSH.

* **Support configuring log files in `bolt-defaults.yaml`**
  ([#1968](https://github.com/puppetlabs/bolt/pull/1968))

  The system-wide and user-level default configuration file,
  `bolt-defaults.yaml`, now supports configuring log files using the
  `log` option.

* **Do not load projects from world-writable directories**
  ([#1894](https://github.com/puppetlabs/bolt/issues/1894))

  Bolt now raises an error when attempting to load a project from a
  world-writable directory on Unix-like systems. Users who wish to
  override this behavior and run a project from a world-writable
  directory should can set the `BOLT_PROJECT` environment variable
  to the project directory path.

### Bug fixes

* **Validate `inventory-config` option in `bolt-defaults.yaml`**
  ([#1963](https://github.com/puppetlabs/bolt/pull/1963))

  Bolt now checks that the `inventory-config` option in a
  `bolt-defaults.yaml` file is a hash and is not a plugin reference
  before merging configuration files. Previously, setting this value to
  a hash or plugin reference would raise an unhelpful error.

* **Don't load default project for every Bolt invocation**
  ([#1917](https://github.com/puppetlabs/bolt/issues/1917))

  Bolt will no longer load the default project at `~/.puppetlabs/bolt`
  for every Bolt invocation. Exceptions raised during project loading
  are now handled correctly and will not show a backtrace.

* **Correctly detect puppet agent install path on Windows**
  ([#1967](https://github.com/puppetlabs/bolt/issues/1967))

  Bolt now correctly detects the Puppet Agent install path on Windows during
  the initialization steps in a WinRM connection.

## Bolt 2.17.0 (2020-07-07)

### New features

* **Set environment variables for commands and scripts**
  ([#1899](https://github.com/puppetlabs/bolt/issues/1899))

  The `run_command()` and `run_script()` plan functions now support an
  `_env_vars` argument which accepts a Hash of environment variable
  declarations to set when running the command/script.

* **Add location of plan failures in error messages**
  ([#1923](https://github.com/puppetlabs/bolt/issues/1923))

  Errors raised by plan failures now include the location of the plan
  failure, including the filepath, line, and column.

* **Add `--log-level` CLI option**
  ([#1920](https://github.com/puppetlabs/bolt/issues/1920))

  The new `--log-level` CLI option can be used to override the console's
  log level. It accepts the following log levels: `debug`, `info`,
  `notice`, `warn`, `error`, `fatal`, `any`.

### Bug fixes

* **Load projects with an embedded Boltdir when specified on the CLI**
  ([#1953](https://github.com/puppetlabs/bolt/pull/1953))

  Bolt now looks for a `Boltdir` in the directory specified by `--project`
  or `--boltdir` and uses it as the project directory if it is present.
  Otherwise, the specified directory is used as the project directory.

* **Support plugin references in JSON schemas**
  ([#1900](https://github.com/puppetlabs/bolt/issues/1900))

  The JSON schemas no longer mark plugin references as invalid values
  when the option can accept a plugin reference. Previously, the schemas
  would mark any plugin reference as an invalid value.

## Bolt 2.16.0 (2020-06-29)

### New features

* **Add `--project` as an alias for the `--boltdir` CLI flag**
  ([#1931](https://github.com/puppetlabs/bolt/issues/1931))

  The new CLI flag `--project` can be used in place of `--boltdir`.

### Bug fixes

* **`localhost` default config is now target-level instead of group-level**
  ([#1904](https://github.com/puppetlabs/bolt/issues/1904))

  Previously, the 'localhost' special default config was merged at the
  group-level, meaning that group-level config in the inventory would
  override it. The config is now target-level and must be overridden at
  the target-level in inventory.

* **Output plan events when using `rainbow` format**
  ([#1926](https://github.com/puppetlabs/bolt/pull/1926))

  Plan events are now printed when using the `rainbow` output format

* **Fix use of spaces in powershell `mkdir` method**
  ([#1927](https://github.com/puppetlabs/bolt/issues/1927))

  Fixes the powershell `mkdir` command to correctly handle paths with spaces
  in them. When passed to the command line, paths have to be quoted, the
  previous code did not handle this. This uses double quotes instead of single
  quotes to allow string interpolation to happen when it is finally passed to
  PowerShell.

* **Upload files with the correct name when destination is a directory**
  ([#1928](https://github.com/puppetlabs/bolt/issues/1928))

  Files uploaded to directories will now retain the name of the original
  source file rather than changing their name to the same name as the
  destination directory. This also fixes the case where the destination
  was `.`

### Deprecations

* **Project names must be explicitly specified**
  ([#1871](https://github.com/puppetlabs/bolt/issues/1871))

  Proejct names must now be specified in `bolt-project.yaml` in order
  for project-level content to be loaded, rather than the name being
  inferred by the name of the project directory.

## Bolt 2.15.0 (2020-06-22)

### New features

* **Add rainbow output format**
  ([#1911](https://github.com/puppetlabs/bolt/pull/1911))

  The new format option `rainbow` prints success messages in rainbow colors.
  This option is not available on Windows.

* **Add `bolt-defaults.yaml` configuration file**
  ([#1845](https://github.com/puppetlabs/bolt/issues/1845))

  Bolt now supports a new `bolt-defaults.yaml` configuration file in the
  [system-wide and user-level
  directories](https://puppet.com/docs/bolt/latest/configuring_bolt.html).
  This configuration file is intended to replace the `bolt.yaml`
  configuration file in the system-wide and user-level directories in
  a future version of Bolt. If a `bolt-defaults.yaml` file exists
  alongside a `bolt.yaml` file, Bolt will ignore the `bolt.yaml` file.

### Bug fixes

* **Log error for unhandled catalog compilation errors** ([#1881](https://github.com/puppetlabs/bolt/issues/1881))

  We now log whatever is on STDERR when catalog compilation fails in a
  way that isn't already handled, and raise an ApplyError.

* **Fix uninitialized constant error for `bolt secret createkeys`**

  Running `bolt secret createkeys` should now succeed, where previously
  it threw an uninitialized constant error.

### Deprecations

* **System-wide and user-level `bolt.yaml` is deprecated**
  ([#1845](https://github.com/puppetlabs/bolt/issues/1845))

  The [system-wide and
  user-level](https://puppet.com/docs/bolt/latest/configuring_bolt.html)
  `bolt.yaml` files have been deprecated in favor of
  `bolt-defaults.yaml`.

## Bolt 2.14.0 (2020-06-15)

### New features

* **Load config from bolt-project.yaml**
  ([#1842](https://github.com/puppetlabs/bolt/issues/1842))

  Bolt configuration options, excluding transport config, can now be
  loaded from `bolt-project.yaml`. If both `bolt-project.yaml` and
  `bolt.yaml` are present in the project and `bolt-project.yaml` has
  bolt config keys (e.g. `format`), `bolt.yaml` will be ignored.

* **Specify preferred algorithms for SSH transport connections**
  ([#1862](https://github.com/puppetlabs/bolt/issues/1862))

  Users can now specify a list of preferred algorithms to use when
  establishing connections with targets using the SSH transport with the
  `encryption-algorithms`, `host-key-algorithms`, `kex-algorithms`, and
  `mac-algorithms` config options. Each option accepts an array of
  algorithms and overrides the default list of preferred algorithms.
  You can read more about these options in the [Bolt configuration
  reference](https://puppet.com/docs/bolt/latest/bolt_configuration_reference.html#ssh).

* **Add resource plan function to find a `ResourceInstance` on a target**
  ([#1874](https://github.com/puppetlabs/bolt/issues/1874))

  This adds a `resource` plan function that can be used to find a
  `ResourceInstance` on a Target object by type and title.

### Bug fixes

* **Improve low ulimit warning**
  ([#1870](https://github.com/puppetlabs/bolt/issues/1870))

  Users running Bolt with a low ulimit should only be warned if the
  number of targets they're running against may cause file limit issues.

* **Raise correct error when passing unknown plan parameters**
  ([#1886](https://github.com/puppetlabs/bolt/pull/1886))

  Bolt was raising an obscure error when a plan received an unknown
  parameter. It now raises the correct error indicating that the
  parameter is unknown.

* **Return correct exit code when running commands in powershell** 
  ([#1846](https://github.com/puppetlabs/bolt/issues/1846))

  Bolt will now display the correct exit code when running commands in
  powershell that exit with code > 1.

* **Empty apply blocks now error correctly**
  ([#1880](https://github.com/puppetlabs/bolt/issues/1880))

  This raises an appropriate error when an apply block is empty, instead
  of an undefined method error.

## Bolt 2.13.0 (2020-06-08)

### New features

* **Use task parameter default when specified parameter is `Undef`**
  ([#1847](https://github.com/puppetlabs/issues/1847))

  Task parameters that are specified with a value of `Undef` will now
  use the default parameter value if one is defined in the task's
  metadata.

* **Accept `resource_type` key in resource data hash for `set_resources`
  plan function**
  ([#1872](https://github.com/puppetlabs/bolt/issues/1872))

  The `set_resources` function now accepts resource data hashes that
  have a `resource_type` key instead of a `type` key. This allows users
  to set resources directly from reports from an apply block, which set
  a resource's type under the `resource_type` key.

* **Added `[]` function to the `ResourceInstance` data type**
  ([#1873](https://github.com/puppetlabs/bolt/issues/1873))

  The `[]` function can be used to directly access the `state` hash for
  a `ResourceInstance` object and return the specified attribute.

### Bug fixes

* **Project-level content can now be used in apply blocks**
  ([#1836](https://github.com/puppetlabs/bolt/issues/1836))

  Project-level classes and defines can now be used in `apply` blocks
  and `bolt apply`.

* **Correct `ResourceInstance.add_event` return type**
  ([#1869](https://github.com/puppetlabs/bolt/pull/1869))

  Previously, the `add_event` function had a typo that prevented it from
  successfully returning. It now correctly expects an
  `Array[Hash[String[1], Data]]]`.

## Bolt 2.12.0 (2020-06-01)

### New features

* **Support `--hiera-config` option when using `bolt apply`**
  ([#1839](https://github.com/puppetlabs/bolt/pull/1839))

  The `--hiera-config` option can now be used with the `bolt apply`
  command to specify the path to a Hiera configuration file.

* **Warn when applying manifests that only contain definitions**
  ([#1785](https://github.com/puppetlabs/bolt/issues/1785))

  Applying a manifest that only contains definitions with the `bolt
  apply` command will now display a warning that no changes will be
  applied to the targets.

* **Analytics configuration loaded from user-level config directory**
  ([#1843](https://github.com/puppetlabs/bolt/issues/1843))

  Analytics configuration is now written to and loaded from
  `~/.puppetlabs/etc/bolt/analytics.yaml` by default. Bolt will fall
  back to loading analytics config from
  `~/.puppetlabs/bolt/analytics.yaml` when the file does not exist in
  the user-level config directory.

* **Use `Sensitive` plan parameters with `bolt plan run`**
  ([#1790](https://github.com/puppetlabs/bolt/issues/1790))

  Plans now support parameters with the `Sensitive` wrapper type when
  run with the `bolt plan run` command. Parameters marked as `Sensitive`
  will be automatically wrapped with the `Sensitive` wrapper type upon
  plan startup.

### Bug fixes

* **Fall back to system-wide config path if homedir expansion fails**
  ([#1829](https://github.com/puppetlabs/bolt/pull/1829))

  Bolt now falls back to `/etc/puppetlabs/bolt` as the default project
  directory if expanding the homedir fails.

## Bolt 2.11.1 (2020-05-28)

### Bug fixes

* **Do not attempt to use `Etc::SC_OPEN_MAX` when it is not defined**
  ([1858](https://github.com/puppetlabs/bolt/pull/1858))

  When the `SC_OPEN_MAX` constant is not defined (for example when running under
  JRuby) do not attempt to use it to determine default concurrency.

## Bolt 2.11.0 (2020-05-27)

### New features

* **Lower default concurrency when ulimit is low**
  ([#1789](https://github.com/puppetlabs/bolt/issues/1789))

  Concurrency defaults to 1/3 the ulimit if ulimit is below 300, and
  warns if lowered concurrency is used.

* **Type aliases are available in apply blocks**
  ([#1828](https://github.com/puppetlabs/bolt/pull/1828))

  Users can now use type aliases defined on their modulepath inside
  apply blocks.

### Bug fixes

* **Add Puppet data types to plugin tarball**
  ([BOLT-1549](https://tickets.puppetlabs.com/browse/BOLT-1549))

  Puppet types are now added to the plugin tarball when running an apply block.

  _Contributed by [Bert Hajee](https://github.com/hajee)_

* **Add `PuppetObject` interface to Bolt data types**
  ([#1836](https://github.com/puppetlabs/bolt/issues/1836))

  Bolt data types would sometimes not be deserialized correctly when
  using `apply` blocks in plans. All Bolt data types now implement the
  `PuppetObject` interface so they can be deserialized correctly.

## Bolt 2.10.0 (2020-05-18)

### New features

* **Use plugins to set PuppetDB config**
  ([#1771](https://github.com/puppetlabs/bolt/issues/1795))

    Plugin references can now be used to set configuration options for
    the PuppetDB client used by Bolt, in the `puppetdb` section of the
    config.

* **Packages for Ubuntu 20.04 now available**
  ([#1782](https://github.com/puppetlabs/bolt/issues/1782))

  Bolt packages are now available for Ubuntu 20.04.

* **Added `ResourceInstance` data type**
  ([#1781](https://github.com/puppetlabs/bolt/issues/1781))

  The new `ResourceInstance` data type is available for use in plans and
  can be used to store the observed state, desired state, and events for
  a target's resource.

* **Added `set_resources` plan function**
  ([#1781](https://github.com/puppetlabs/bolt/issues/1781))

  The `set_resources` plan function can be used to set
  `ResourceInstance`s on a `Target`.

* **Added `resources` function to `Target` data type**
  ([#1781](https://github.com/puppetlabs/bolt/issues/1781))

  `Target` objects have a new `resources` function that can be used to
  return a map of `ResourceInstance`s for the target.

* **Specify a local project directory with a `bolt-project.yaml` file**
  ([#1816](https://github.com/puppetlabs/bolt/issues/1816))

  Directories containing a `bolt-project.yaml` file are now considered
  a [local project
  directory](https://puppet.com/docs/bolt/latest/bolt_project_directories.html#local-project-directory).

* **Allow users to shell out to SSH**
  ([#1780](https://github.com/puppetlabs/bolt/issues/1780))

  Users can now specify an SSH command, which Bolt will shell out to
  when using the SSH transport. This allows users to run SSH as if it were
  run locally without worrying about Ruby library feature support.

### Bug fixes

* **Expand filepaths passed on the CLI relative to the current working directory**
  ([#1791](https://github.com/puppetlabs/bolt/pull/1791))

  Config options `hiera-config` and `private-key` are now expanded relative
  to the directory Bolt was run from when specified on the CLI, inline
  with other CLI options.

### Deprecations

* **Project configuration file changed to `bolt-project.yaml`**
  ([#1816](https://github.com/puppetlabs/bolt/issues/1816))

  The project configuration file name `project.yaml` has been deprecated
  in favor of a more-specific `bolt-project.yaml`. Bolt will no longer
  load project configuration from a `project.yaml` file.

## Bolt 2.9.0 (2020-05-11)

### New features

* **Warn when Bolt is installed as a gem**
  ([#1779](https://github.com/puppetlabs/bolt/issues/1779))

  Bolt now issues a warning when it detects that it may have been
  installed as a gem. This warning can be disabled by setting the
  `BOLT_GEM` environment to `false`.

  To install Bolt reliably and with all of its dependencies, it should
  be [installed as a
  package](https://puppet.com/docs/bolt/latest/bolt_installing.html).

* **Added JSON schemas for validating Bolt configuration files**
  ([#1795](https://github.com/puppetlabs/bolt/issues/1795))

  JSON schemas are now available for validating `bolt.yaml`,
  `inventory.yaml`, and `project.yaml` files.

### Bug fixes

* **Task output that contains invalid UTF-8 is now rejected**
  ([#1759](https://github.com/puppetlabs/bolt/issues/1759))

  Tasks are defined as returning UTF-8, but Bolt didn't handle the
  non-UTF-8 case explicitly, leading to messy error messages and stack
  traces. The error should now be clear and meaningful.

* **Non-UTF-8 characters in command and script output are removed before printing**
  ([#1759](https://github.com/puppetlabs/bolt/issues/1759))

  Commands and scripts are allowed to return UTF-8, but Bolt would error
  when trying to print those results or return them as JSON. Now,
  accessing fields of the result from a Puppet plan will return the
  values unmodified, but invalid characters will be replaced by their
  hex-escaped equivalents when printing the result or converting it to
  JSON.

* **Improved support for non-UTF-8 character encodings**
  ([#1759](https://github.com/puppetlabs/bolt/issues/1759))

  Commands run from a target where the default character encoding is
  non-UTF-8 will now return proper results when using the WinRM
  transport.

* **Fix `bolt plan show <plan>` for project-level plans**
  ([#1799](https://github.com/puppetlabs/bolt/pull/1799))

  This command was throwing errors due to a type mismatch that is now
  resolved.

* **Make an `ApplyResult` a valid `PlanResult`**
  ([#1807](#1807))

  Plans may now return `ApplyResult`s outside of a `ResultSet`.

## Bolt 2.8.0 (2020-05-05)

### New features

* **Support project-level Puppet content**
  ([#1267](https://github.com/puppetlabs/bolt/issues/1267))

  Users can now load Puppet content from the root of the Bolt project directory,
  such as `<boltdir>/tasks`. Users must opt-in to this experimental feature by 
  creating a `project.yaml` in their project directory. **This feature is
  experimental.**

* **Project authors can whitelist `bolt * show` output**
  ([#1756](https://github.com/puppetlabs/bolt/issues/1756))

  Project authors can now whitelist individual `bolt [plan|task] show`
  content in `project.yaml` using the `tasks` and `plans` settings.

* **Added `run_task_with` plan function**
  ([#1673](https://github.com/puppetlabs/bolt/issues/1673))

  The new plan function `run_task_with` lets you run tasks on a set of
  targets with target-specific parameters. It accepts a lambda that
  returns a `Hash` of parameters for a particular target.

* **`pkcs7` plugin converted to module-based plugin**
  ([#1736](https://github.com/puppetlabs/bolt/issues/1736))

  The `pkcs7` plugin has been converted to a module-based plugin and
  includes the `pkcs7::secret_encrypt`, `pkcs7::secret_decrypt`, and
  `pkcs7::secret_createkeys` tasks.

* **Require `--force` option to overwrite existing keys**
  ([#1738](https://github.com/puppetlabs/bolt/issues/1738))

  The `bolt secret createkeys` command now accepts an optional `--force`
  option to force secret plugins to overwrite existing keys. The default
  `pkcs7` secret plugin will now error when attempting to overwrite
  existing keys without the `--force` option set.

* **Support default task parameters in plugins**
  ([#1754](https://github.com/puppetlabs/bolt/issues/1754))

  Bolt now merges default task parameters for a plugin with parameters
  set in a `bolt.yaml` and `inventory.yaml` file.

* **Add `--hiera-config` option for `bolt plan run` command**
  ([#1403](https://github.com/puppetlabs/bolt/issues/1403))

  The `bolt plan run` command now supports a `--hiera-config` option
  that accepts an absolute or relative path to a Hiera config file.

* **Support `lookup` plan function outside of apply blocks**
  ([#1403](https://github.com/puppetlabs/bolt/issues/1403))

  Plans can now use the `lookup` plan function outside of apply blocks
  to look up data with Hiera. The `lookup` function will use the Hiera
  config file specified in the Bolt config. Interpolations are not
  available outside of apply blocks and will cause a plan to error.

### Bug fixes

* **Target objects of the same name are now identical** 
  ([#1773](https://github.com/puppetlabs/bolt/issues/1773))

  Target objects will now be considered identical in all cases if they
  have the same name. This allows uniq to operate on arrays of Targets
  as well as Targets to be used as Hash keys.

* **Fixed 'broken pipe' errors with SSH and local transports**
  ([#1769](https://github.com/puppetlabs/bolt/issues/1769))

  The SSH and local transports could experience broken pipes when
  using run-as while running a task that accepted input on stdin but
  didn't read it.

* **Set `gcloud_inventory::resolve_reference` task to private**
  ([#1783](https://github.com/puppetlabs/bolt/pull/1783))

  The `gcloud_inventory::resolve_reference` task has been set to private
  and will no longer appear when using `bolt task show`.

### Deprecations

* **`private-key` and `public-key` options for `pkcs7` plugin have been
  deprecated**
  ([#1736](https://github.com/puppetlabs/bolt/issues/1736))

  The `pkcs7` plugin now accepts `private_key` and `public_key` options.
  Support for the `private-key` and `public-key` options will be removed
  in a future release of Bolt.

## Bolt 2.7.0 (2020-04-27)

### New features

* **Mock out sub-plans in BoltSpec testing**
  ([#1630](https://github.com/puppetlabs/bolt/issues/1630))

  New stubs `allow_plan` and `expect_plan` are available in BoltSpec::Plans for
  mocking out `run_plan` functions during Bolt spec testing. New flags `execute_any_plan` 
  (default) and `execute_no_plan` are avilable to control the behavior of sub-plan executions.
  The new stubs `allow_plan` and `expect_plan` work with all of the existing action
  modifiers except for `with_targets` and `return_for_targets`.

  _Contributed by [Nick Maludy](https://github.com/nmaludy)_

* **Experimental support for interacting with Windows hosts via PowerShell over SSH**
  ([#813](https://github.com/puppetlabs/bolt/issues/813))

  The `login-shell: powershell` config setting can be set on a target to
  connect over SSH while running commands and tasks via PowerShell instead
  of Bash. This feature requires OpenSSH >= 7.9 on the target.

* **Print group membership for targets when running `bolt inventory show --detail`**
  ([#1701](https://github.com/puppetlabs/bolt/pull/1701))

  The `bolt inventory show --detail` command now lists a target's group membership.

  _Contributed by [Nick Maludy](https://github.com/nmaludy)_

* **`--no-cleanup` option to leave behind temporary files**
  ([#1729](https://github.com/puppetlabs/bolt/issues/1729))

  The `--no-cleanup` flag or `cleanup: false` transport option can now
  be set to instruct Bolt not to clean up on a target after it's
  finished. This is useful for debugging what Bolt is doing on a system.

* **Add `prompt` plan function**
  ([#1755](https://github.com/puppetlabs/bolt/issues/1755))

  The new `prompt` plan function lets you pause plan execution and
  prompt the user for input.

* **OpenSSH config option StrictHostKeyChecking now honored**
  ([#1758](https://github.com/puppetlabs/bolt/pull/1758))

  Setting `StrictHostKeyChecking` in your ssh config will now be loaded
  and merged with config along with other OpenSSH settings

* **Support for ed25519 SSH keys**
  ([#1758](https://github.com/puppetlabs/bolt/pull/1758))

  Key exchange algorithm curve25519sha256 is now supported

* **New `optional` and `default` keys for the `env_var` plugin**
  ([#1768](https://github.com/puppetlabs/bolt/issues/1768))

  The `env_var` plugin accepts two new optional keys. The `default` key
  allows you to set a default value that the plugin should return when
  the environment variable is not set, while the `option` key allows the
  plugin to return `nil` when the environment variable is not set instead
  of erroring.

### Bug fixes

* **Target facts with the same name as a plan or Target variable should
  not raise an error** ([#1725](https://github.com/puppetlabs/bolt/issues/1725))

  Previously, defining a fact with the same name as
  another variable would cause a redefinition error in the apply block,
  where now referencing the variable will refer to the fact value.

## Bolt 2.6.0 (2020-04-20)

### New features

* **Google Cloud inventory plugin**
  ([#1707](https://github.com/puppetlabs/bolt/issues/1707))

  Bolt now includes a [`gcloud_inventory`
  plugin](https://forge.puppet.com/puppetlabs/gcloud_inventory) to
  generate inventory from Google Cloud compute engine instances.

* **Commands run over local transport on Windows use powershell**
  ([#1708](https://github.com/puppetlabs/bolt/pull/1708))

  Previously, the local transport on Windows would exec commands
  directly, meaning powershell constructs couldn't be used. These
  commands are now always executed through powershell, so powershell
  commands and script snippets can be run.

* **Commands and tasks on Windows now consistently return \r\n**
  ([#1708](https://github.com/puppetlabs/bolt/pull/1708))

  The local transport on Windows was returning \n while WinRM returned
  \r\n. They are now consistent and always use \r\n.

### Deprecations

* **YAML plan step parameter `target` deprecated in favor of `targets`**
([#1722](https://github.com/puppetlabs/bolt/issues/1722))

  The `target` parameter for YAML plan steps has been deprecated in
  favor of `targets` and will be removed in a future release of Bolt.


## Bolt 2.5.0 (2020-04-13)

### New features

* **Add Boltspec helper to load Bolt constructs**
  ([#1688](https://github.com/puppetlabs/bolt/issues/1688))

  A new helper function `in_bolt_context` can be used to wrap code that
  references Bolt constructs, such as the Boltlib::TargetSpec datatype.

* **Added `transport` and `transport_config` functions to `Target` data
  type** ([#1686](https://github.com/puppetlabs/bolt/issues/1686))

  The `Target` data type now supports a `transport` function, which
  returns the transport used to connect to the target, and a
  `transport_config` function, which returns a hash of merged
  configuration for the target's transport.

### Bug fixes

* **`Bolt::Util.deep_clone` can now clone frozen objects**
  ([#1696](https://github.com/puppetlabs/bolt/pulls/1696))

  The `Bolt::Util.deep_clone` method can now clone frozen objects,
  preserving the 'frozen' attribute

* **Fix bug in Bolt::Result where nil actions threw an exception**
  ([#1714](https://github.com/puppetlabs/bolt/issues/1714),
  [#1724](https://github.com/puppetlabs/bolt/issues/1724))

  Returning from a plan with results of `run_task()` on a remote transport
  that returned `nil`, threw an exception. Returning from a plan with results 
  of `wait_until_available()`, threw an exception.

  _Contributed by [Nick Maludy](https://github.com/nmaludy)_

* **Fix a bug passing arguments to local shell transport**
  ([#1713](https://github.com/puppetlabs/bolt/1713))

  Local shell transport could miss some bytes when writing non-ASCII characters
  to stdin.

* **Don't fail when the `run-as` user's home directory doesn't exist**
  ([#1702](https://github.com/puppetlabs/bolt/pull/1702))

  When running commands with `run-as` set, Bolt will try to `cd` to the
  new user's home directory before running the command. If that fails
  because the directory doesn't exist, it will now run the command from
  wherever it currently is rather than aborting.

* **Don't rely on sudo to preserve environment variables**
  ([#1702](https://github.com/puppetlabs/bolt/pull/1702))

  Bolt previously set environment variables when invoking `sudo` and
  relied on it to preserve them when running the task executable. That
  behavior isn't reliable for all configurations, so now environment
  variables are set directly when running the underlying executable.

## Bolt 2.4.0 (2020-04-06)

### New features

* **Populate all target attributes in the `puppetdb` plugin's `target_mapping`** 
  ([#1689](https://github.com/puppetlabs/bolt/pull/1689))

  Previously, the `target_mapping` field only supported populating a target's `uri`,
  `name` and `config` values. All of a target's attributes can now be specified in
  the `target_mapping` field, including `facts`, `vars`, `features`, and `alias`.

  _Contributed by [Nick Maludy](https://github.com/nmaludy)_

## Bolt 2.3.1 (2020-03-30)

### Bug fixes

* **Validate that a specified Hiera config file exists**
([#1692](https://github.com/puppetlabs/bolt/pull/1692))

  Bolt was not properly validating that a Hiera config file specified
  with the `hiera-config` option in a `bolt.yaml` existed.

## Bolt 2.3.0 (2020-03-23)

### New features

* **Enable basic-auth-only option for WinRM when using SSL**
([#1658](https://github.com/puppetlabs/bolt/pulls/1658))

  Users can now use WinRM Basic authentication when SSL is configured.

* **Add debugging statements to task errors**
([#1647](https://github.com/puppetlabs/bolt/issues/1647))

  The `ruby_task_helper` and `python_task_helper` modules include new
  `debug` and `debug_statements` helper methods for adding debugging
  statements to task errors.

* **Initialize a Bolt project with modules and their dependencies**
([#1574](https://github.com/puppetlabs/bolt/issues/1574))

  The `bolt project init` command has a new `--modules` option that
  accepts a comma-separated list of modules to install when initializing
  a project. Modules and their dependencies are fully resolved, saved to
  a `Puppetfile` in the project directory, and then automatically
  installed with `bolt puppetfile install`.

### Bug fixes

* **Handle cases where loading hardcoded homedir paths fail**
([#1671](https://github.com/puppetlabs/bolt/issues/1671))

  Bolt's user level config and analytics config paths are hardcoded and
  include `~`, which errors out when getlogin fails to return a user. We
  now skip loading user level config if loading the file fails, and
  disable analytics if loading the analytics config fails.

## Bolt 2.2.0 (2020-03-10)

### New features

* **Support plugins in `bolt.yaml` transport configuration** ([#1591](https://github.com/puppetlabs/bolt/issues/1591))

  Plugins can now be used to configure transports in a `bolt.yaml` file. Bolt will also provide more helpful
  error messages when a plugin is used in an unsupported location.

## Bolt 2.1.0 (2020-03-02)

### New features

* **New `write_file` plan function** ([#1597](https://github.com/puppetlabs/bolt/issues/1597))

  The new plan function, `write_file`, allows you to write content to a file on the given targets.

* **Add `--puppetfile` option for `puppetfile install` command** ([#1612](https://github.com/puppetlabs/bolt/issues/1612))

  The `puppetfile install` command now supports a `--puppetfile` option that accepts a relative or absolute path
  to a Puppetfile.

* **Update reboot plan parameter `nodes` to `targets`** ([puppetlabs-reboot#223](https://github.com/puppetlabs/puppetlabs-reboot/pull/223))

  Users who explicitly set the `nodes` parameter will need to update the parameter name to
  `targets`. Calling the `reboot` plan with `-t` or `run_plan('reboot', $mytargets)` behaves the same
  as before and does not require an update.

* **Package Bolt for MacOS 10.15** ([#1445](https://github.com/puppetlabs/bolt/issues/1445))

  Bolt packages are now available for MacOS 10.15.

### Bug fixes

* **Fixed performance regression with large inventory files** ([#1627](https://github.com/puppetlabs/bolt/pull/1627))

  Large inventory groups were taking a long time to validate and should now be faster.

* **Modifications to an inventory when using `run_plan` are validated correctly** ([#1627](https://github.com/puppetlabs/bolt/pull/1627))

  When using `run_plan(..., _catch_errors => true)` and making invalid modifications to the inventory, errors would
  be caught but the modifications would still be made to the inventory. Modifications to the inventory are now
  validated prior to applying them to the inventory.

## Bolt 2.0.1 (2020-02-25)

### Deprecations and removals

* **WARNING**: Starting with this release, new Bolt packages are not available for macOS 10.11, 10.12,
  10.13, and Fedora 28, 29.

### Bug fixes

* **Fixed a performance regression with large inventory files** ([#1625](https://github.com/puppetlabs/bolt/pull/1625))

  Large inventory groups were taking a long time to load and should now be faster.

* **`project migrate` command correctly migrates version 1 inventory files** ([#1623](https://github.com/puppetlabs/bolt/issues/1623))

  The `project migrate` command now correctly replaces all `nodes` keys in an inventory file with `targets`. 
  Previously, only the first group in an array of groups was having its `nodes` key replaced.

## Bolt 2.0.0 (2020-02-19)

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

## Bolt 1.49.0 (2020-02-10)

### New features

* **Add Kerberos support for SSH transport**

  Users can now authenticate with Kerberos when using the SSH transport.

### Bug fixes

* **Remove apply result hash from human output** ([#1585](https://github.com/puppetlabs/bolt/issues/1585))

  Apply result hashes will no longer be displayed when using human output. Instead, a metrics message
  will be shown.

## Bolt 1.48.0 (2020-02-03)

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

## Bolt 1.47.0 (2020-01-27)

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

## Bolt 1.45.0 (2020-01-13)

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

## Bolt 1.44.0 (2020-01-09)

### New features

* **New `file::join` plan function** ([#837](https://github.com/puppetlabs/bolt/issues/837))

  The new plan function, `file::join`, allows you to join file paths using the separator `/`.

### Bug fixes

* **The ssh configuration option `key-data` was not compatible with the `future` flag** ([#1504](https://github.com/puppetlabs/bolt/issues/1504))

  Bolt no longer attempts to expand a `private-key` configuration `Hash` when `key-data` is being used in conjunction with the `future` setting.

## Bolt 1.43.0 (2019-12-18)

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

## Bolt 1.42.0 (2019-12-09)

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

## Bolt 1.41.0 (2019-12-03)

### New features

* **Added `target_mapping` field in `terraform` and `aws_inventory` inventory plugins** ([#1404](https://github.com/puppetlabs/bolt/issues/1404))

  The `terraform` and `aws_inventory` inventory plugins have a new `target_mapping` field which accepts a hash of target configuration options and the lookup values to populate them with.

* **Ruby helper library for inventory plugins** ([#1404](https://github.com/puppetlabs/bolt/issues/1404))

    A new library has been added to help write inventory plugins in Ruby:

    * https://github.com/puppetlabs/puppetlabs-ruby_plugin_helper

    Use this library to map lookup values to a target's configuration options in a `resolve_references` task.
    
## Bolt 1.40.0 (2019-12-02)

### New features

* **`bolt plan show` displays plan and parameter descriptions** ([#1442](https://github.com/puppetlabs/bolt/pull/1442))

  `bolt plan show` now uses Puppet Strings to parse plan documentation and show plan and parameter descriptions as well as parameter defaults.

* **New `remove_from_group` plan function** ([#1418](https://github.com/puppetlabs/bolt/issues/1418))

  The new plan function, `remove_from_group`, allows you to remove a target from an inventory group during plan execution.

* **Added `target_mapping` field in `puppetdb` inventory plugin** ([#1408](https://github.com/puppetlabs/bolt/pull/1408))

  The `puppetdb` inventory plugin has a new `target_mapping` field which accepts a hash of target configuration options and the facts to populate them with.

## Bolt 1.39.0 (2019-11-22)

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

## Bolt 1.38.0 (2019-11-15)

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

## Bolt 1.37.0 (2019-11-08)

### New features

* **New `resolve_references` plan function** ([#1365](https://github.com/puppetlabs/bolt/issues/1365))

  The new plan function, `resolve_references`, accepts a hash of structured data and returns a hash of structured data with all plugin references resolved.

### Bug fixes

* **Allow optional `--password` and `--sudo-password` parameters** ([#1269](https://github.com/puppetlabs/bolt/issues/1269))

  Optional parameters for `--password` and `--sudo-password` were prematurely removed. The previous behavior of prompting for a password when an argument is not specified for `--password` or `--sudo-password` has been added back. Arguments will be required in a future version.

## Bolt 1.36.0 (2019-11-07)

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

## 1.35.0 (2019-10-25)

### Deprecation

* **Replace `install_agent` plugin with `puppet_agent` module** ([#1294](https://github.com/puppetlabs/bolt/issues/1294))

  The `puppetlabs-puppet_agent` module now provides the same functionality as the `install_agent` plugin did previously. The `install_agent` plugin has been removed and the `puppet_agent` module is now the default plugin for the `puppet_library` hook. If you do not use the bundled `puppet_agent` module you will need to update to version `2.2.1` of the module. If you reference the `install_agent` plugin you will need to now reference `puppet_agent` instead.

### New features

* **Support `limit` option for `do_until` function** ([#1270](https://github.com/puppetlabs/bolt/issues/1270))

  The `do_until` function now supports a `limit` option that prevents it from iterating infinitely.

* **Improve parameter passing for module plugins** ([#1322](https://github.com/puppetlabs/bolt/issues/1322))

  In the absence of a `config` section in `bolt_plugin.json`, Bolt will validate any configuration options in `bolt.yaml` against the schema for each task of the plugin’s hook. Bolt passes the values to the task at runtime and merges them with options set in `inventory.yaml`.

## 1.34.0 (2019-10-17)

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

## 1.33.0 (2019-10-10)

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

## 1.32.0 (2019-10-04)

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

## 1.31.1 (2020-09-27)

### Bug fixes

* **Spurious plan failures and warnings on startup**

  Eliminated a race condition with the analytics client that could cause Bolt operations to fail or extraneous warnings to appear during startup.

## 1.31.0 (2019-09-26)

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


## 1.30.1 (2019-09-19)

### Deprecations and removals

* **WARNING**: Starting with this release the puppetlabs apt repo for trusty (Ubuntu 1404) no longer contains new puppet-bolt packages.

### Bug fixes

* **`apply` blocks would ignore the `_run_as` argument passed to
their containing plan** ([#1167](https://github.com/puppetlabs/bolt/issues/1167))

  Apply blocks in sub-plans now honor the parent plan's `_run_as` argument.

* **Task parameters with `type` in the name were filtered out in PowerShell version 2.x or earlier** ([#1205](https://github.com/puppetlabs/bolt/issues/1205))

  PowerShell tasks executed on targets with PowerShell version 2.x or earlier can now use task parameters with the string `type` in the name \(though a parameter simply named `type` is still incompatible\). PowerShell version 3.x or higher does not have this limitation.

## 1.30.0 (2019-09-05)

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

## 1.29.1 (2019-08-22)

### Bug fixes

* **Tasks with input method `stdin` hung with the `--tty` option** ([#1129](https://github.com/puppetlabs/bolt/issues/1129))

  Tasks no longer hang over the SSH transport when the input method is `stdin`, the `--tty` option is set, and the `--run-as` option is unset.

* **Docker transport was incompatible with the Windows Bolt controller** ([#1060](https://github.com/puppetlabs/bolt/issues/1060))

  When running on Windows, the Docker transport can now execute actions on Linux containers.

## 1.29.0 (2019-08-15)

### New features

* **Remote state files for Terraform inventory plugin**

  The Terraform plugin for inventory configuration now supports both local and remote state files. ([BOLT-1469](https://tickets.puppet.com/browse/BOLT-1469))

* **Reorganized command reference documentation**

  The command reference documentation now shows a list of options available for each command, instead of having separate sections for commands and options. ([BOLT-1422](https://tickets.puppet.com/browse/BOLT-1422))

### Bug fixes

* **Using `--sudo-password` without `--run-as` raised a warning**

  CLI commands that contain `--sudo-password` but not `--run-as` now run as expected without any warnings. ([BOLT-1514](https://tickets.puppet.com/browse/BOLT-1514))

## 1.28.0 (2019-08-08)

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

## 1.27.1 (2019-08-01)

### Bug fixes

* **Calling `get_targets` in manifest blocks with inventory version 2 caused an exception**

  `get_targets` now returns a new `Target` object within a manifest block with inventory version 2. When you pass the argument `all` with inventory v2, `get_targets` always returns an empty array. ([BOLT-1492](https://tickets.puppet.com/browse/BOLT-1492))

* **Bolt ignored script arguments that contain "="**

  Bolt now properly recognizes script arguments that contain "=". For example, `bolt script run myscript.sh foo a=b c=d -n mynode` recognizes and uses all three arguments. ([BOLT-1412](https://tickets.puppet.com/browse/BOLT-1412))

## 1.27.0 (2019-07-25)

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

## 1.26.0 (2019-07-10)

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

## 1.25.0 (2019-06-28)

### Bug fixes

* **`out::message` didn't work inside `without_default_logging`**

  The `out::message` standard library plan function now works within a `without_default_logging` block. ([BOLT-1406](https://tickets.puppet.com/browse/BOLT-1406))

* **Task action stub parameter method incorrectly merged options and arguments**

  When a task action stub expectation fails, the expected parameters are now properly displayed. ([BOLT-1399](https://tickets.puppet.com/browse/BOLT-1399))

### Deprecations and removals

* **lookups removed from target_lookups**

  We have deprecated the target-lookups key in the experimental inventory file v2. To address this change, migrate any target-lookups entries to targets and move the plugin key in each entry to _plugin.

## 1.24.0 (2019-06-21)

### New features

* **Help text only lists options for a given command**

  Help text now only shows options for the specified subcommand and action. Previously, all options were displayed in the help text, even if those options did not apply to the specified subcommand and action. ([BOLT-1342](https://tickets.puppet.com/browse/BOLT-1342))

* **Packages for Fedora 30**

  Bolt packages are now available for Fedora 30. ([BOLT-1302](https://tickets.puppet.com/browse/BOLT-1302))

* **Adds support for embedding eyaml data in the inventory**

  This change adds a hiera-eyaml compatible pkcs7 plugin and support for embedding eyaml data in the inventory. ([BOLT-1270](https://tickets.puppet.com/browse/BOLT-1270))

* **Allow `$nodes` as positional arg for `run_plan`**

  This change allows the `run_plan` function to be invoked with `$nodes` as the second positional argument, so that it can be used the same way `run_task` is used. ([BOLT-1197](https://tickets.puppet.com/browse/BOLT-1197))

## 1.23.0 (2019-06-14)

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

## 1.22.0 (2019-06-07)

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

## 1.21.0 (2019-05-29)

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

## 1.20.0 (2019-05-16)

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

## 1.19.0 (2019-05-03)

### New features

* **Convert YAML plans to Puppet plans**

  You can now convert YAML plans to Puppet plans with the `bolt plan convert` command. ([BOLT-1195](https://tickets.puppet.com/browse/BOLT-1195))

* **Improved error handling for missing commands**

  A clear error message is now shown when no object is specified on the command line, for example `bolt command run --nodes <NODE_NAME>`. ([BOLT-1243](https://tickets.puppet.com/browse/BOLT-1243))

## 1.18.0 (2019-04-25)

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

## 1.17.0 (2019-04-19)

### New features

* **Rerun failed commands**

  Bolt now stores information about the last failed run in a `.rerun.json` file in the Bolt project directory. You can use this record to target nodes for the next run using `--retry failure` instead of `--nodes`.

  For repositories that contain a Bolt project directory, add `$boltdir/.last_failure.json` to `.gitignore` files.

  Stored information may include passwords, so if you save passwords in URIs, set `save-failures: false` in your Bolt config file to avoid writing passwords to the `.rerun.json` file. ([BOLT-843](https://tickets.puppet.com/browse/BOLT-843))

### Bug fixes

* **SELinux management didn't work on localhost**

  Bolt now ships with components similar to the Puppet agent to avoid discrepancies between using a puppet-agent to apply Puppet code locally versus using the Bolt puppet-agent. ([BOLT-1244](https://tickets.puppet.com/browse/BOLT-1244))

## 1.16.0 (2019-04-11)

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

## 1.15.0 (2019-03-29)

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

## 1.14.0 (2019-03-15)

### New features

* **Support for Puppet device modules in a manifest block**

  You can now apply Puppet code on targets that can't run a Puppet agent using the remote transport via a proxy. This is an experimental feature and might change in future minor (y) releases. ([BOLT-645](https://tickets.puppet.com/browse/BOLT-645))

* **Validation and error handling for invalid PCP tokens**

  The PCP transport token-file configuration option now includes validation and a more helpful error message. ([BOLT-1076](https://tickets.puppet.com/browse/BOLT-1076))

## 1.13.1 (2019-03-07)

### Bug fixes

* **The \_run_as option was clobbered by configuration**

  The run-as configuration option took precedence over the \_run_as parameter when calling run_* functions in a plan. The \_run_as parameter now has a higher priority than config or CLI. ([BOLT-1050](https://tickets.puppet.com/browse/BOLT-1050))

* **Tasks with certain configuration options failed when using stdin**

  When both interpreters and run-as were configured, tasks that required parameters to be passed over stdin failed. ([BOLT-1155](https://tickets.puppet.com/browse/BOLT-1155))

## 1.13.0 (2019-02-27)

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

## 1.12.0 (2019-02-21)

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

## 1.11.0 (2019-02-08)

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

## 1.10.0 (2019-01-16)

### New features

* **Hyphens allowed in aliases and group names**

  Node aliases and group names in the Bolt inventory can now contain hyphens. ([BOLT-1022](https://tickets.puppet.com/browse/BOLT-1022))

### Bug fixes

* **Unsecured download of the puppet_agent::install_powershell task**

  The PowerShell implementation of the puppet_agent::install task now downloads Windows .msi files using HTTPS instead of HTTP. This fix ensures the download is authenticated and secures against a man-in-the-middle attack.

## 1.9.0 (2019-01-10)

### New features

* **Improved out-of-the-box tasks**

  The package and service tasks now select task implementation based on available target features while their platform-specific implementations are private. ([BOLT-1049](https://tickets.puppet.com/browse/BOLT-1049))

* **Respect multiple PuppetDB server_urls**

  Bolt now tries to connect to all configured PuppetDBserver_urls before failing. ([BOLT-938](https://tickets.puppet.com/browse/BOLT-938))

### Bug fixes

* **Bolt crashed if PuppetDB configuration was invalid**

  If an invalid puppetdb.conf file is detected, Bolt now issues a warning instead of crashing ([BOLT-756](https://tickets.puppet.com/browse/BOLT-756))
* **Local transport returned incorrect exit status**

  Local transport now correctly returns an exit code instead of the stat of the process status as an integer. ([BOLT-1074](https://tickets.puppet.com/browse/BOLT-1074))

## 1.8.1 (2019-01-04)

### Bug fixes

* **Standard library functions weren't packaged in 1.8.0**

  Version 1.8.0 didn't include new standard library functions as intended. This release now includes standard library functions in the gem and packages. ([BOLT-1065](https://tickets.puppet.com/browse/BOLT-1065))

## 1.8.0 (2019-01-03)

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

## 1.7.0 (2018-12-19)

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

## 1.6.0 (2018-12-13)

### New features

* **Remote tasks**

  You can now run tasks on a proxy target that remotely interacts with the real target, as defined by the run-on option. Remote tasks are useful for targets like network devices that have limited shell environments, or cloud services driven only by HTTP APIs. Connection information for non-server targets, like HTTP endpoints, can be stored in inventory. ([BOLT-791](https://tickets.puppet.com/browse/BOLT-791))

* **reboot module plan**

  Bolt now ships with the reboot module, and that module now provides a plan that reboots targets and waits for them to become available. ([BOLT-459](https://tickets.puppet.com/browse/BOLT-459))

* **Local transport on Windows**

  The local transport option is now supported on Windows. ([BOLT-608](https://tickets.puppet.com/browse/BOLT-608))

* **bolt_shim module contents marked as sensitive**

  The bolt_shim module that enables using Bolt with PE now marks file content as sensitive, preventing it from being logged or stored in a database. ([BOLT-815](https://tickets.puppet.com/browse/BOLT-815))

### Bug fixes

* **wait_until_available function didn't work with Docker transport**

  We merged the Docker transport and wait_until_available function in the same release, and they didn't play nicely together. ([BOLT-1018](https://tickets.puppet.com/browse/BOLT-1018))

* **Python task helper didn't generate appropriate errors**

  The Python task helper included with Bolt didn't produce an error if an exception was thrown in a task implemented with the helper. ([BOLT-1021](https://tickets.puppet.com/browse/BOLT-1021))

## 1.5.0 (2018-12-06)

### New features

* **Node aliases**

  You can now specify aliases for nodes in your inventory and then use the aliases to refer to specific nodes. ([BOLT-510](https://tickets.puppet.com/browse/BOLT-510))

* **Run apply with PE orchestrator without installing puppet_agent module**

  Bolt no longer requires installing the puppet_agent module in PE in order to run apply actions with the PE orchestrator. ([BOLT-940](https://tickets.puppet.com/browse/BOLT-940))

## 1.4.0 (2018-11-30)

### New features

* **Bolt apply with orchestrator**

  A new puppetlabs-apply_helper module enables using Boltapply with orchestrator. For details, see the module README. ([BOLT-941](https://tickets.puppet.com/browse/BOLT-941))

* **Add targets to a group**

  A new add_to_group function allows you to add targets to an inventory group during plan execution. ([BOLT-942](https://tickets.puppet.com/browse/BOLT-942))

* **Additional plan test helpers**

  The BoltSpec::Plans library now supports unit testing plans that use the `_run_as` parameter, `apply`, `run_command`, `run_script`, and `upload_file`. ([BOLT-984](https://tickets.puppet.com/browse/BOLT-984))

* **Data collection about applied catalogs**

  If analytics data collection is enabled, we now collect randomized info about the number of statements in a manifest block, and how many resources that produces for each target. ([BOLT-644](https://tickets.puppet.com/browse/BOLT-644))

## 1.3.0 (2018-11-14)

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

## 1.2.0 (2018-10-30)

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

  When you use tasks that include shared code, the task executable is located alongside shared code at `_installdir/MODULE/tasks/TASK`. ([BOLT-931](https://tickets.puppet.com/browse/BOLT-931))

## 1.1.0 (2018-10-16)

### New features

* **Share code between tasks**

  Bolt includes the ability to share code between tasks. A task can include a list of files that it requires, from any module, that it copies over and makes available via a \_installdir parameter. This feature is also supported in Puppet Enterprise 2019.0. For more information see, Sharing task code. ([BOLT-755](https://tickets.puppet.com/browse/BOLT-755))

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

## 1.0.0 (2018-10-08)

### Bug fixes

* **Loading bolt/executor is "breaking" gettext setup in spec tests**

  When Bolt is used as a library, it no longer loads code from r10k unless you explicitly require 'bolt/cli'.([BOLT-914](https://tickets.puppet.com/browse/BOLT-914))

* **Deprecated functions in stdlib result in Evaluation Error**

  Manifest blocks will now allow use of deprecated functions from stdlib, and language features governed by the 'strict' setting in Puppet. ([BOLT-900](https://tickets.puppet.com/browse/BOLT-900))

* **Bolt apply does not provide `clientcert` fact**

  apply_prep has been updated to collect agent facts as listed in Puppet agent facts. ([BOLT-898](https://tickets.puppet.com/browse/BOLT-898))

* **`C:\Program Files\Puppet Labs\Bolt\bin\bolt.bat` is non-functional**

  When moving to Ruby 2.5, the .bat scripts in Bolt packaging reverted to hard-coded paths that were not accurate. As a result Bolt would be unusable outside of PowerShell. The .bat scripts have been fixed so they work from cmd.exe as well. ([BOLT-886](https://tickets.puppet.com/browse/BOLT-886))