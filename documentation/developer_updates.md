# Developer updates

Find out what the Bolt team is working on and why we're making the decisions
we're making.

## November 2020

### Changes coming in Bolt 3.0

With the new year fast approaching, the team is preparing to release the next
major version of Bolt: **Bolt 3.0**! Over the next few releases you'll start
to see deprecation warnings for specific features and configuration options that
are slated for removal in Bolt 3.0. To help you prepare for the release, we've
compiled a list of expected changes and removals.

#### Changes

- **Ship with Puppet 7**

  Bolt packages will ship with Puppet 7. This change should not impact most
  users, but changes to the Puppet language may require updating your Bolt
  plans.

  To read more about the changes in Puppet 7, see the [Puppet 7 release
  notes](https://puppet.com/docs/puppet/7.0/release_notes_puppet.html#release_notes_puppet_x-0-0).

- **Ship with Ruby 2.7**

  Bolt packages will ship with Ruby 2.7 instead of Ruby 2.5.1. This change will
  not affect most users who install the Bolt package, as Bolt packages ship with
  their own Ruby. However, gem installs will require Ruby 2.7 or higher, and
  users who install gems with Bolt's Ruby may also need to update their gems.

- **New default modulepath**

  Since the introduction of the module feature in Bolt 2.30.0, Bolt has used a
  shorter, simpler default modulepath when a project enables the feature.
  Starting in Bolt 3.0, the module management feature will be enabled for all
  projects, meaning the default modulepath will also be updated.

  To read more about the new module management workflow and the updated
  modulepath, see the [modules overview](modules.md).

- **Move PowerShell module to PowerShell Gallery**

  The PuppetBolt PowerShell module will be distributed through [PowerShell
  Gallery](https://www.powershellgallery.com/).

- **Ship with `bolt.bat` file on Windows**

  Bolt packages on Windows will ship with a `bolt.bat` batch file. This will
  disable the `bolt` and `Invoke-BoltCommandLine` commands in Powershell. Users
  should instead use the built-in [PowerShell
  cmdlets](bolt_cmdlet_reference.md).

- **`apply_settings` configuration option renamed to `apply-settings`**

  Most other configuration options in Bolt use hyphens instead of underscores.

  For a full list of project configuration options, see the [bolt-project.yaml
  options](bolt_project_reference.md) reference page.

- **`plugin_hooks` configuration option renamed to `plugin-hooks`**

  Most other configuration options in Bolt use hyphens instead of underscores.

  For a full list of project configuration options, see the [bolt-project.yaml
  options](bolt_project_reference.md) reference page.

- **`puppetfile` configuration option renamed to `module-install`**

  This configuration option has a confusing name that implies the path to a
  Puppetfile. The new name more clearly indicates that it configures how modules
  are installed.

  For a full list of project configuration options, see the [bolt-project.yaml
  options](bolt_project_reference.md) reference page.

  - **`target` key for YAML plan steps renamed to `targets`**

  This key has been deprecated in favor of the `targets` key.

  For more information about writing YAML plans, see [writing YAML
  plans](writing_yaml_plans.md).

- **`source` key for YAML plan `upload` step renamed to `upload`**

  This key has been deprecated in favor of the `upload` key.

  For more information about upload YAML plan step, see [writing YAML
  plans](writing_yaml_plans.md#file-upload-step).

- **`private-key` and `public-key` parameters for pkcs7 plugin renamed to
  `private_key` and `public_key`**

  These keys have been deprecated in favor of the `private_key` and `public_key`
  parameters.

  For more information about the `pkcs7` plugin, see the [Forge
  documentation](https://forge.puppet.com/puppetlabs/pkcs7).

#### Removals

- **Packages for Debian 8 will be removed**

  Debian 8 reached end-of-life on June 30, 2020.

  For a full list of supported platforms, see [installing
  Bolt](bolt_installing.md).

- **Support for `bolt.yaml` configuration file will be removed**

  Bolt will no longer support the `bolt.yaml` configuration file. Instead, you
  should use `bolt-project.yaml` in your project and `bolt-defaults.yaml` at the
  user and system level.

  For more information about configuring your project, see [configuring
  Bolt](configuring_bolt.md).

- **`bolt puppetfile *` commands and `*-BoltPuppetfile` PowerShell cmdlets will
  be removed**

  These commands are being removed in favor of the new `bolt module *` commands
  and `*-BoltModule` PowerShell cmdlets.

  To read more about the new module management workflow and the updated
  modulepath, see the [modules overview](modules.md).

- **Support for PowerShell 2.0 will be dropped**

  PowerShell 2.0 has been deprecated since 2017 and adds unecessary complexity
  for Bolt. Bolt will no longer support running on controllers when using
  PowerShell 2.0 or when connecting to remote targets running PowerShell 2.0.

- **`--boltdir` command-line option will be removed**

  This command-line option has been deprecated in favor of `--project`.

- **`--configfile` command-line option will be removed**

  This command-line option provides little value and adds unecessary complexity
  to Bolt. Instead, use the `--project` command-line option to run Bolt from a
  specific project.

- **`--debug` command-line option will be removed**

  This command-line option has been deprecated in favor of `--log-level debug`.
  Additionally, Bolt now writes a debug log to `bolt-debug.log` by default,
  removing the need to explicitly run in debug mode for most users.

- **`--description` command-line option will be removed**

  This command-line option provides little value.

- **`inventoryfile` configuration option will be removed**

  Bolt already offers the `--inventoryfile` command-line option to use a
  non-default inventory file for a single run. However, there is little value in
  configuring a permanent non-default inventoryfile for a project.

#### Updating your project

While some of these changes will require you to manually update files, others
can be made automatically with Bolt. We'll be updating the project migrate
command to automatically update your Bolt project to use the latest features and
best practices. You can run this command now to pick up any changes that have
already been made, or wait until Bolt 3.0 is released to pick up all changes at
once.

To migrate your project, run the following command in your project directory:

_\*nix shell command_

```shell
bolt project migrate
```

_PowerShell cmdlet_

```powershell
Update-BoltProject
```

Keep in mind that this command only makes changes to a project. Changes to plans
and configuration files at the user and system level will need to be made
manually. For more information on how the `migrate` command changes your project
files, see [Migrate a Bolt project](projects.md#migrate-a-bolt-project).

### Puppet 7 Release Prep

[Puppet 7](https://puppet.com/docs/puppet/7.0/puppet_index.html) is set to be
released November 19th, 2020. While the Bolt package won't be pulling in Puppet
7 until early next year, the `puppet_agent::install` task bundled with Bolt will
pick up Puppet 7 agents by default when the packages are available. This means
that using the `apply_prep()` Bolt plan function or the install task directly
will be pulling in a major version bump for the agent. While we don't anticipate
any of the changes in the agent to affect Bolt users, if you find you need to
use the Puppet 6 agent, you can configure `apply_prep()` and the
`puppet_agent::install` task to do so.

The `puppet_agent::install` task accepts a `collections` parameter that tells
the task which collection to download the package from. This defaults to
`puppet` which maps to the latest collection, but you can set this value to
`puppet6` to pull in the latest Puppet 6 agent. You can pass this parameter on
the command line:

_\*nix shell command_
```
bolt task run puppet_agent::install -t mytargets collection='puppet6'
```

_PowerShell cmdlet_
```
Invoke-BoltTask -Name puppet_agent::install -Targets mytargets collection='puppet6'
```

Or to the `run_task()` plan function:
```
run_task('puppet_agent::install', $targets, { collection => 'puppet6' })
```

If you need the `apply_prep()` plan function to install the Puppet 6 agents
instead of Puppet 7, you can configure this by [configuring the puppet_library
plugin hook](using_plugins.md#puppet-library-plugins) in either
`bolt-project.yaml` or `bolt-defaults.yaml`:

```
plugin_hooks:
  puppet_library:
    task: puppet_agent
    collection: puppet6
```

## September 2020

### Module management in Bolt projects

We've recently finished work on a major improvement to Bolt projects: module
management! With this improvement, you no longer need to manually manage your
modules and their dependencies in a Puppetfile and can instead automate that
process with Bolt.

If you want to try it out, [create a
project](bolt_installing_modules.md#create-a-bolt-project-with-pre-installed-modules)
or migrate an existing project with the following command:

_\*nix shell command_

```shell
bolt project migrate
```

_PowerShell cmdlet_

```powershell
Update-BoltProject
```

#### Why are we making these changes?

So why did we make this change to how Bolt manages modules? Because managing a
project's modules could be a frustrating process that includes multiple steps:

- Find the module you want to add to your project
- Find all of the dependencies for that module
- Determine which version of each module is compatible with every other module
  you have installed
- Manually update your Puppetfile to include each module
- Install the Puppetfile

By offloading most of this work to Bolt, you now only need to list the modules
you care about in your project configuration. Bolt takes care of resolving a
module's dependencies and installing compatible versions. This greatly
simplifies the process of managing your project's modules:

- Find the module you want to add to your project
- Tell Bolt to install the module with all of its dependencies

With these changes, we've also updated where Bolt installs modules. You no
longer need to worry about accidentally overwriting local modules when you
install a Puppetfile, because Bolt installs modules to a special directory that
is not part of the configured modulepath.

The new module management feature is available starting with **Bolt 2.30.0**. To
try it out, [create a
project](bolt_installing_modules.md#create-a-bolt-project-with-pre-installed-modules)
or [migrate an existing project](./projects.md#migrate-a-bolt-project).

Here's a summary of what's changed:

- **Managed module installation directory:** Bolt now installs modules it
  manages into the `.modules/` directory instead of `modules/`. Avoid committing
  `.modules/` to source control. Your users can download your Bolt project and
  use the `bolt module install` *nix shell command, or `Install-BoltModule`
  cmdlet to download the required modules.
- **Non-managed module directory:** Bolt no longer uses the `site-modules/`
  directory. Store any modules that you don't want Bolt to manage in the
  `modules/` directory.
- **Module configuration:** Your `bolt-project.yaml` file contains a `modules`
  key that lists the direct module dependencies of your Bolt project. Unless you
  need to pin a module to a specific version, avoid editing the `modules` list
  directly. Instead, use the `bolt module add` command.
- **Puppetfile:** The Puppet file is now a lock file. Bolt generates a
  Puppetfile each time you modify your modules with a Bolt command. Do not edit
  the Puppetfile directly. Instead, use Bolt commands to manage your modules,
  and rely on Bolt to manage the Puppetfile. You can compare a Puppetfile to a
  [Gemfile.lock](https://bundler.io/rationale.html#checking-your-code-into-version-control)
  file in Ruby, or a
  [yarn.lock](https://classic.yarnpkg.com/en/docs/yarn-lock/) file in Yarn.
- **modulepath:** The new modulepath is `['modules']` and Bolt always appends
  `.modules` to the modulepath.
