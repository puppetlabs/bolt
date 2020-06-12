# Configuring Bolt

You can configure Bolt's options and features at a project level, a user level,
or a system-wide level. Unless your use case requires setting user-specific or
system-wide configurations, configure Bolt at the project level. 

## Project-level configuration

Most of the time, you'll only need to set configuration at the project level. 
You can set all configurable options in Bolt at the project level, and any options
you set within a project only apply to that project. 

Bolt loads project-level configuration files from the root of your [Bolt project
directory](bolt_project_directories.md). If it can't find a project directory,
Bolt uses the default project directory: `~/.puppetlabs/bolt/`.

You can set project-level configuration in three files: 
- For Bolt configuration, use `bolt-project.yaml`.
- For inventory configuration, use `inventory.yaml`.
- You can set all configuration in a `bolt.yaml` file at the root of your
  project directory. **The project-level `bolt.yaml` file is on the path towards
  deprecation and will be removed in a future version of Bolt.** Use
  `bolt-project.yaml` and `inventory.yaml` files instead.

The preferred method for setting project-level configuration is to use a
combination of `bolt-project.yaml` and `inventory.yaml` files. This maintains
a clear distinction between Bolt configuration and inventory configuration.

### `bolt-project.yaml`

> **Note:** The `bolt-project.yaml` file is experimental and is subject to
> change. You can read more about Bolt projects in [Experimental
> features](experimental_features.md).

**Filepath:** `<project-directory>/bolt-project.yaml`

The project configuration file supports options that configure how Bolt behaves,
such as how many threads it can use when running commands on targets. You can
also use `bolt-project.yaml` to configure different components of the project,
such as a list of plans and tasks that are visible to the user. Any directory
containing a `bolt-project.yaml` file is automatically considered a [Project
directory](bolt_project_directories.md).

Project configuration files take precedence over `bolt.yaml` files. If a
project directory contains both files, Bolt will only load and read
configuration from `bolt-project.yaml`.

You can view a full list of the available options in [Bolt configuration
options](bolt_configuration_reference.md).

### `inventory.yaml`

**Filepath:** `<project-directory>/inventory.yaml`

The inventory file is a structured data file that contains groups of targets
that you can run Bolt commands on, as well as configuration for the transports
used to connect to the targets. Most projects will include an inventory file.

Inventory configuration can be set at multiple levels in an inventory file
under a `config` option. You can set the following options under `config`:

- `transport`
- `docker`
- `local`
- `pcp`
- `remote`
- `ssh`
- `winrm`

You can read more about inventory files and the available options in
[Inventory files](inventory_file_v2.md).

### `bolt.yaml`

> **Note:** The project-level `bolt.yaml` file is on the path towards
> deprecation and will be removed in a future version of Bolt. Use
> `bolt-project.yaml` and `inventory.yaml` files instead.

**Filepath:** `<project-directory>/bolt.yaml`

The Bolt configuration file can be used to set all available configuration
options, including default inventory configuration options. Any directory
containing a `bolt.yaml` file is automatically considered a [Project
directory](bolt_project_directories.md).

You can view a full list of the available options in [Bolt configuration
options](bolt_configuration_reference.md).

## User-level configuration

Use this level to set configuration that should apply to all projects for a
particular user. Options that you might set at the user-level include paths to
private keys, credentials for a plugin,
or default inventory configuration that is common to all of your projects.
You can set most configurable options in Bolt at the user level. 


You can set user-level configuration in two files:
- Use `bolt-defaults.yaml` for configuration that is
not project-specific.
- You can set all configuration in a `bolt.yaml` file. **The user-level `bolt.yaml` file is on the path towards
  deprecation and will be removed in a future version of Bolt. Use
  `bolt-defaults.yaml` instead.**

The preferred method for setting user-level configuration is to use a
`bolt-defaults.yaml` file. This file does not allow you to set project-specific
configuration, such as the path to an inventory file, and is less likely
to lead to errors where Bolt loads content from another project.

### `bolt-defaults.yaml`

**Filepath:** `~/.puppetlabs/etc/bolt/bolt-defaults.yaml`

The defaults configuration file supports most of Bolt's configuration options,
with the exception of options that are project-specific such as `inventoryfile`
and `modulepath`.

The `bolt-defaults.yaml` file takes precedence over a `bolt.yaml` file in the
same directory. If the directory contains both files, Bolt will only load and 
read configuration from `bolt-defaults.yaml`.

You can view a full list of the available options in [`bolt-defaults.yaml`
options](bolt_defaults_reference.md).

### `bolt.yaml`

> **Note:** The user-level `bolt.yaml` file is deprecated and will be removed
> in a future version of Bolt. Use a `bolt-defaults.yaml` file instead.

**Filepath:** `~/.puppetlabs/etc/bolt/bolt.yaml`

The Bolt configuration file can be used to set all available configuration
options, including project-specific configuration options.

You can view a full list of the available options in [Bolt configuration
options](bolt_configuration_reference.md).

## System-wide configuration

Use this level to set configuration that applies to all users and all projects.
This might include configuration for connecting to an organization's Forge
proxy, the number of threads Bolt should use when connecting to targets, or
setting credentials for connecting to PuppetDB. You can set most configurable
Bolt options at the system level. 

System-wide configuration can be set in two files.
- Use `bolt-defaults.yaml` for configuration that is not project-specific.
- You can set all configuration in a `bolt.yaml` file. **The system-level
  `bolt.yaml` file is on the path towards deprecation and will be removed in a
  future version of Bolt. Use `bolt-defaults.yaml` instead.** 

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

The `bolt-defaults.yaml` file takes precedence over a `bolt.yaml` file in the
same directory. If the directory contains both files, Bolt will only load and 
read configuration from `bolt-defaults.yaml`.

You can view a full list of the available options in [`bolt-defaults.yaml`
options](bolt_defaults_reference.md).

### `bolt.yaml`

> **Note:** The system-wide `bolt.yaml` file is deprecated and will be removed
> in a future version of Bolt. Use a `bolt-defaults.yaml` file instead.

**\*nix Filepath:** `/etc/puppetlabs/bolt/bolt.yaml`

**Windows Filepath:** `%PROGRAMDATA%\PuppetLabs\bolt\etc\bolt.yaml`

You can set all available configuration
options in `bolt.yaml`, including project-specific configuration options.

You can view a full list of the available options in [Bolt configuration
options](bolt_configuration_reference.md).

## Configuration precedence

Bolt uses the following precedence when interpolating configuration settings,
from highest precedence to lowest:

  - Target URI (i.e. ssh://user:password@hostname:port)
  - [Inventory file](inventory_file_v2.md) options
  - [Command line flags](bolt_command_reference.md)
  - Project-level configuration file
  - User-level configuration file
  - System-wide configuration file
  - SSH configuration file options (e.g. `~/.ssh/config`)

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

- [Project directories](bolt_project_directories.md#)
- [Bolt configuration options](bolt_configuration_reference.md)
- [bolt-defaults.yaml options](bolt_defaults_reference.md)
- [bolt-project.yaml options](bolt_project_reference.md)
- [Transport configuration options](bolt_transports_reference.md)
- For information on using configuring Bolt for Puppet Enterprise, see [Using Bolt with Puppet Enterprise](bolt_configure_orchestrator.md)
- For information on connecting Bolt to PuppetDB, see [Connecting Bolt to PuppetDB](bolt_connect_puppetdb.md)