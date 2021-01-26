# Configuring Bolt

Bolt has many options and features that can be configured to suit your
project's needs. In general, Bolt configuration falls into four categories:

- **Bolt behavior:** Configure how Bolt itself runs, such as the format to use
  when displaying output or how many threads to use when connecting to targets.

- **Projects:** Configure the Bolt project that you are running Bolt in, such
  as the path to an inventory file or the path to a Hiera configuration file.

- **Transports:** Configure the transports that Bolt uses to connect to
  targets, such as the path to a private key when using SSH or the port to
  connect to when using WinRM.

- **Inventory data:** Group and configure the targets that you connect to and
  run commands on with Bolt.

You can configure Bolt's options and features at a project level, a user level,
or a system-wide level. At the project level, you set Bolt configuration in the
`bolt-project.yaml` and `inventory.yaml` files. At the user and system-wide
levels, set your configuration in the `bolt-defaults.yaml` file. Unless your use
case requires setting user-specific or system-wide configurations, configure
Bolt at the project level.

| Type of Configuration | [inventory.yaml](bolt_inventory_reference.md) | [bolt-project.yaml](bolt_project_reference.md) | [bolt-defaults.yaml](bolt_defaults_reference.md) |
| --- | :-: | :-: | :-: |
| Bolt behavior  |   | ✓ | ✓ |
| Projects       |   | ✓ |   |
| Transports     | ✓ |   | ✓ |
| Inventory data | ✓ |   |   |
| **Configuration level** | [project](#project-level-configuration) | [project](#project-level-configuration) | [user](#user-level-configuration), [system-wide](#system-wide-configuration) |

## Project-level configuration

Most of the time, you'll only need to set configuration at the project level. 
You can set all configurable options in Bolt at the project level, and any options
you set within a project only apply to that project.

Bolt loads project-level configuration files from the root of your [Bolt project
directory](projects.md). If it can't find a project directory,
Bolt uses the default project directory: `~/.puppetlabs/bolt/`.

You can set project-level configuration in two files: 
- For Bolt configuration, use `bolt-project.yaml`.
- For inventory configuration, use `inventory.yaml`.

The preferred method for setting project-level configuration is to use a
combination of `bolt-project.yaml` and `inventory.yaml` files. This maintains
a clear distinction between Bolt configuration and inventory configuration.

### `bolt-project.yaml`

**Filepath:** `<PROJECT DIRECTORY>/bolt-project.yaml`

The project configuration file supports options that configure how Bolt behaves,
such as how many threads it can use when running commands on targets. You can
also use `bolt-project.yaml` to configure different components of the project,
such as a list of plans and tasks that are visible to the user. Any directory
containing a `bolt-project.yaml` file is automatically considered a [Project
directory](projects.md).

You can view a full list of the available options in [`bolt-project.yaml`
options](bolt_project_reference.md).

### `inventory.yaml`

**Filepath:** `<PROJECT DIRECTORY>/inventory.yaml`

The inventory file is a structured data file that contains groups of targets
that you can run Bolt commands on, as well as configuration for the transports
used to connect to the targets. Most projects include an inventory file.

Inventory configuration can be set at multiple levels in an inventory file
under a `config` option. You can set the following options under `config`:

- `transport`
- `docker`
- `local`
- `pcp`
- `remote`
- `ssh`
- `winrm`

You can view a full list of the available options in [`inventory.yaml`
fields](bolt_inventory_reference.md).

## User-level configuration

Use this level to set configuration that should apply to all projects for a
particular user. Options that you might set at the user-level include paths to
private keys, credentials for a plugin,
or default inventory configuration that is common to all of your projects.
You can set most configurable options in Bolt at the user level.

The preferred method for setting user-level configuration is to use a
`bolt-defaults.yaml` file. This file does not allow you to set project-specific
configuration, such as the path to an inventory file, and is less likely
to lead to errors where Bolt loads content from another project.

### `bolt-defaults.yaml`

**Filepath:** `~/.puppetlabs/etc/bolt/bolt-defaults.yaml`

The defaults configuration file supports most of Bolt's configuration options,
with the exception of options that are project-specific such as `modules` and
`modulepath`.

You can view a full list of the available options in [`bolt-defaults.yaml`
options](bolt_defaults_reference.md).

## System-wide configuration

Use this level to set configuration that applies to all users and all projects.
This might include configuration for connecting to an organization's Forge
proxy, the number of threads Bolt should use when connecting to targets, or
setting credentials for connecting to PuppetDB. You can set most configurable
Bolt options at the system level.

The preferred method for setting user-level configuration is to use a
`bolt-defaults.yaml` file. This file does not allow you to set project-specific
configuration, such as the path to an inventory file, and is less likely
to lead to errors where content from another project is loaded.

### `bolt-defaults.yaml`

**\*nix Filepath:** `/etc/puppetlabs/bolt/bolt-defaults.yaml`

**Windows Filepath:** `%PROGRAMDATA%\PuppetLabs\bolt\etc\bolt-defaults.yaml`

The defaults configuration file supports most of Bolt's configuration options,
with the exception of options that are project-specific such as `inventoryfile`
and `modulepath`.

You can view a full list of the available options in [`bolt-defaults.yaml`
options](bolt_defaults_reference.md).

## Configuration precedence

Bolt uses the following precedence when interpolating configuration settings,
from highest precedence to lowest:

  - Configuration specifications from the target's URI. For example, `ssh://user:password@hostname:port`.
  - [Plan function](plan_functions.md) options that modify configuration, such as `_run_as`.
  - [Inventory file](inventory_file_v2.md) configuration options.
  - [Command-line options](bolt_command_reference.md) that modify configuration.
  - Options from the project-level configuration file, `bolt-project.yaml`. 
  - Options from the user-level configuration file, `~/.puppetlabs/etc/bolt/bolt-defaults.yaml`.
  - Options from the system-wide configuration file, `/etc/puppetlabs/bolt/bolt-defaults.yaml`.
  - SSH configuration file options. For example, `~/.ssh/config`.

## Merge strategy

When merging configurations, Bolt's strategy is to shallow merge any options
that accept hashes and to overwrite any options that do not accept hashes. There
are two exceptions to this strategy:

- [Transport configuration](bolt_transports_reference.md) is deep-merged.

- [Plugin configuration](using_plugins.md#configuring-plugins) is shallow-merged
  for _each individual plugin_.

### Transport configuration merge strategy

Transport configuration is deep merged. 

For example, given this SSH configuration in an inventory file:

```yaml
# ~/.puppetlabs/bolt/inventory.yaml
config:
  ssh:
    user: bolt
    password: bolt
    host-key-check: false
```

And this this SSH configuration in a user configuration file:

```yaml
# ~/.puppetlabs/etc/bolt/bolt-defaults.yaml
inventory-config:
  ssh:
    user: puppet
    password: puppet
    private-key: ~/path/to/key/id_rsa
```
The merged Bolt configuration would look like this:

```yaml
ssh:
  user: bolt
  password: bolt
  host-key-check: false
  private-key: ~/path/to/key/id_rsa
```

### Plugin configuration merge strategy

The `plugins` option accepts a hash where each key is the name of a plugin and
its value is a hash of configuration options for the plugin. When merging
configurations, the configuration for individual plugins is shallow merged.

> **Note:** If a plugin is configured in one file, but is not configured in a
> file with a higher precedence, the configuration for the plugin will still be
> present in the merged configuration.

For example, given this plugin configuration in a project configuration file:

```yaml
# ~/.puppetlabs/bolt/bolt-project.yaml
plugins:
  vault:
    auth:
      method: userpass
      user: bolt
      pass: bolt
```

And this plugin configuration in a system-wide configuration file:

```yaml
# /etc/puppetlabs/bolt/bolt-defaults.yaml
plugins:
  aws_inventory:
    credentials: /etc/aws/credentials
  vault:
    server_url: http://example.com
    auth:
      method: token
      token: xxxx-xxxx-xxxx-xxxx
```

The merged Bolt configuration would look like this:

```yaml
plugins:
  aws_inventory:
    credentials: /etc/aws/credentials
  vault:
    server_url: 'http://example.com'
    auth:
      method: userpass
      user: bolt
      pass: bolt
```

📖 **Related information**

- [Bolt projects](projects.md)
- [bolt-defaults.yaml options](bolt_defaults_reference.md)
- [bolt-project.yaml options](bolt_project_reference.md)
- [inventory.yaml fields](bolt_inventory_reference.md)
- [Transport configuration options](bolt_transports_reference.md)
- For information on using configuring Bolt for Puppet Enterprise, see [Using Bolt with Puppet Enterprise](bolt_configure_orchestrator.md)
- For information on connecting Bolt to PuppetDB, see [Connecting Bolt to PuppetDB](bolt_connect_puppetdb.md)
