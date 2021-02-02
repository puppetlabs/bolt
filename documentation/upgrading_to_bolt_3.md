# Upgrading to Bolt 3.0

Welcome to Bolt 3.0! This page contains a list of the most important things you
need to know if you're upgrading from an earlier version of Bolt.

For an exhaustive list of the things we've changed, see: 
- [Changes coming in Bolt 3.0](developer_updates.md#changes-coming-in-bolt-30)
- [Bolt 3.0 Changelog](https://pup.pt/bolt-3)

If you're not ready to make the leap to Bolt 3.0, you can still download the
last release in the Bolt 2 series by specifying the version (2.44.0) in your
package manager. For Homebrew, use `brew install --cask puppet-bolt@2`. You can
also download the relevant
[macOS](https://downloads.puppet.com/mac/puppet-tools/) and
[Windows](http://downloads.puppet.com/windows/puppet-tools/) installers.

## Migrating configuration files

Bolt 3.0 introduces changes to Bolt's configuration file layout and content,
including removing `bolt.yaml` and renaming several configuration options.
Here's how to transition to the new world order.

## Automated migration

The migration command updates your project-level configuration files to use the
latest Bolt best practices:

_\*nix shell command_

```shell
bolt project migrate
```

_PowerShell cmdlet_

```powershell
Update-BoltProject
```

For a more detailed explanation of what the `migrate` command does, see [Migrate
a Bolt project](projects.md#migrate-a-bolt-project).

## Manual migration

If you need user- or system-level configuration, use the following manual
migration steps to migrate the relevant configuration files. You can also follow
these steps for your project-level configuration files if you're not comfortable
having Bolt rewrite your files.

### User- and system-level configuration

To migrate your system- or user-level Bolt configuration, make the following
changes to the relevant `bolt.yaml` file:

1. Move any [transport configuration](bolt_transports_reference.md) to be under
   an `inventory-config` key, like so:

   ```
   inventory-config:
       ssh:
         password: hunter2!
         user: bolt
       winrm:
         password: hunter2!
         user: bolt
   ```
   Transport configuration keys are `ssh`, `winrm`, `pcp`, `local`, `docker`,
   `remote`, and `transport`.
1. Rename the following configuration options:
    - `plugin_hooks` to `plugin-hooks`
1. Rename `apply_settings` to `apply-settings` and move the `apply-settings`
   configuration to your project directory at `<PROJECT
   DIRECTORY>/bolt-project.yaml`. If you'd rather use the default Bolt project
   directory, place the file in `~/.puppetlabs/bolt/`.
1. Rename the file to `bolt-defaults.yaml`.

### Project-level configuration

1. Move any [transport configuration](bolt_transports_reference.md) to the
   top-level `config` key of the inventory file. This should be at `<PROJECT
   DIRECTORY>/inventory.yaml`.

   ```
    targets:
      - my target

    config:
       ssh:
         password: hunter2!
         user: bolt
       winrm:
         password: hunter2!
         user: bolt
   ```
   Transport configuration keys are `ssh`, `winrm`, `pcp`, `local`, `docker`,
   `remote`, and `transport`.
1. Rename the following configuration options:
    - `apply_settings` to `apply-settings`
    - `plugin_hooks` to `plugin-hooks`
1. Rename the file to `bolt-project.yaml`.

## Upgrading the puppet-agent package on targets

Starting in Bolt 3.0, Bolt no longer supports puppet-agent versions earlier than
6.0.0. While applying Puppet code to targets with an earlier version of the
puppet-agent package might still succeed, Bolt does not guarantee compatibility.

To upgrade the puppet-agent package version installed on a target, you can run
the `puppet_agent::install` task, which is included in Bolt packages.

- To update to the latest version of the puppet-agent package:

  _\*nix shell command_

  ```shell
  bolt task run puppet_agent::install --targets <TARGETS> version=latest
  ```

  _PowerShell cmdlet_

  ```powershell
  Invoke-BoltTask -Task puppet_agent::install -Targets <TARGETS> version=latest
  ```

- To update to a specific version of the puppet-agent package:

  ```shell
  bolt task run puppet_agent::install --targets <TARGETS> version=<VERSION> collection=<COLLECTION>
  ```

  _PowerShell cmdlet_

  ```powershell
  Invoke-BoltTask -Task puppet_agent::install -Targets <TARGETS> version=<VERSION> collection=<COLLECTION>
  ```

  For task documentation, including a list of available collections, run `bolt
  task show puppet_agent::install` or `Get-BoltTask -Name puppet_agent::install`
  in PowerShell.

### Suppress unsupported Puppet agent version warnings

When Bolt detects a puppet-agent version earlier than 6.0.0 on a target, it logs
a warning like this:

```shell
Detected unsupported Puppet agent version 5.22.0 on target my_target. Bolt supports
Puppet agent 6.0.0 and higher. [ID: unsupported_puppet]
```

If you do not want to upgrade the puppet-agent package to a supported version
and would like to stop seeing these warnings, you can configure your project to
suppress them. To suppress these warnings, configure the `disable-warnings`
option in your project configuration:

```yaml
---
name: my_project
disable-warnings:
  - unsupported_puppet
```

## Module installation and management

Bolt 2.30 introduced module dependency management and new `bolt module *`
commands and `*-BoltModule` PowerShell cmdlets, as well as a new and simplified
modulepath. Bolt 3.0 removes the deprecated `bolt puppetfile *` commands and
`*-BoltPuppetfile` PowerShell cmdlets.

To read more about the new module management workflow and the updated
modulepath, see the [Modules overview](modules.md). For information on
installing your modules, see [Installing modules](bolt_installing_modules.md).
