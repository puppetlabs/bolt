# Upgrading to Bolt 3.0

It's almost time for Bolt 3.0! This page contains a list of things you can do to prepare for the
upcoming release. We'll add to this page as we near the release and implement more of the expected
changes and deprecations, so if you're making the changes ahead of time, be sure to check in every
couple weeks to see if we've added anything else to the instructions below. For an exhaustive list
of the things we're changing, see [Changes coming in Bolt 3.0](developer_updates.md#changes-coming-in-bolt-30).

## Migrating configuration files

Bolt 3.0 introduces changes to Bolt's configuration file layout and content, including
removing `bolt.yaml` and renaming several configuration options. Here's how to transition to the new
world order.

## Automated migration

The migration command updates your project-level configuration files to use the latest Bolt best practices:

_\*nix shell command_

```shell
bolt project migrate
```

_PowerShell cmdlet_

```powershell
Update-BoltProject
```

## Manual migration

If you need user- or system-level configuration, use the following manual migration steps to 
migrate the relevant configuration files. You can also follow these steps for your project-level 
configuration files if you're not comfortable having Bolt rewrite your files.

### User- and system-level config

To migrate your system- or user-level Bolt configuration, make the following changes to the relevant `bolt.yaml` file:

1. Move any [transport configuration](bolt_transports_reference.md) to be under an
   `inventory-config` key, like so:

   ```
   inventory-config:
       ssh:
         password: hunter2!
         user: bolt
       winrm:
         password: hunter2!
         user: bolt
   ```
   Transport configuration keys are `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote`, and
   `transport`.
1. Rename the following configuration options:
    - `plugin_hooks` to `plugin-hooks`
1. Rename `apply_settings` to `apply_settings` and move the `apply_settings` configuration to
   your project directory at `<PROJECT DIRECTORY>/bolt-project.yaml`. If you'd rather use the
   default Bolt project directory, place the file in `~/.puppetlabs/bolt/`.
1. Rename the file to `bolt-defaults.yaml`.

### Project-level config

1. Move any [transport configuration](bolt_transports_reference.md) to the top-level `config` key of
   the inventory file. This should be at `<PROJECT DIRECTORY>/inventory.yaml`.

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
   Transport configuration keys are `ssh`, `winrm`, `pcp`, `local`, `docker`, `remote`, and
   `transport`.
1. Rename the following configuration options:
    - `apply_settings` to `apply-settings`
    - `plugin_hooks` to `plugin-hooks`
1. Rename the file to `bolt-project.yaml`.
