# Configuring Bolt

You can configure Bolt's options and features at a project level, a user level, or a system-wide level. 

Some options and features you can configure include:
- global options
- transports 
- plugins
- PuppetDB connections
- log files 

For a complete list of Bolt settings, see the [configuration reference](bolt_configuration_reference.md).

## Configuration files

To configure Bolt, create a Bolt configuration file named `bolt.yaml` in one of the locations listed below. If a configuration file is not located at the expected path, or the file is empty, Bolt does not load the file. 

You can place `bolt.yaml` configuration files at the following paths, from highest precedence to lowest:

- **Project**
  
  The `bolt.yaml` file in a project directory applies settings to that project specifically. Matching settings at the project level override those at the user and system-wide levels.

  `boltdir/bolt.yaml` or `<MY_PROJECT_NAME>/bolt.yaml`

  > **Note:** The project configuration file is loaded from the [Bolt project directory](bolt_project_directories.md). The default project directory is `~/.puppetlabs/bolt/`.

- **User**
  
  The `bolt.yaml` file at the user level applies settings only to that user. Matching settings at the user level are overridden by project-level settings, but take precedent over system-wide settings.  

  `~/.puppetlabs/etc/bolt/bolt.yaml`

- **System-wide**

  Settings in a system-wide config file apply to all users running Bolt, regardless of the Bolt project directory. However, matching settings at the project or user level override system-wide settings.
  
  The `bolt.yaml` file at the system-wide level applies settings only to that user.

  \*nix: `/etc/puppetlabs/bolt/bolt.yaml`

  Windows: `%PROGRAMDATA%\PuppetLabs\bolt\etc\bolt.yaml`

## Configuration precedence

Bolt uses the following precedence when interpolating configuration settings, from highest precedence to lowest:

  - Target URI (i.e. ssh://user:password@hostname:port)
  - [Inventory file](inventory_file.md) options
  - [Command line flags](bolt_command_reference.md)
  - Project configuration file
  - User configuration file
  - System-wide configuration file
  - SSH configuration file options (e.g. `~/.ssh/config`)

## Merge strategy

When merging configurations, Bolt's strategy is to shallow merge any options that accept hashes and to overwrite any options that do not accept hashes. There are two exceptions to this strategy:

- [Transport configuration](bolt_configuration_reference.md#transport-configuration-options) (e.g. `ssh`, `winrm`) is deep-merged.

- [Plugin configuration](using_plugins.md#configuring-plugins) is shallow-merged for _each individual plugin_.

### Transport configuration merge strategy

Transport configuration is deep merged. 

For example, given this SSH configuration in a project configuration file:

```yaml
ssh:
  user: bolt
  password: bolt
  host-key-check: false
```

And this this SSH configuration in a user configuration file:

```yaml
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
  ...
```

### Plugin configuration merge strategy

The `plugins` option accepts a hash where each key is the name of a plugin and its value is a hash of configuration options for the plugin. When merging configurations, the configuration for individual plugins is shallow merged.

> **Note:** If a plugin is configured in one file, but is not configured in a file with a higher precedence, the configuration for the plugin will still be present in the merged configuration.

For example, given this plugin configuration in a project configuration file:

```yaml
plugins:
  vault:
    auth:
      method: userpass
      user: bolt
      pass: bolt
```

And this plugin configuration in a system-wide configuration file:

```yaml
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

## Additional documentation

- **[Project directories](bolt_project_directories.md#)**  
  
  Bolt runs in the context of a project directory or a `Boltdir`. This directory contains all of the configuration, code, and data loaded by Bolt.

- **[Bolt configuration options](bolt_configuration_options.md)**  

  Your Bolt configuration file can contain global and transport options.

- **[Using Bolt with Puppet Enterprise](bolt_configure_orchestrator.md)**  
  
  If you're a Puppet Enterprise (PE) customer, you can configure Bolt to use the PE orchestrator and perform actions on managed targets. Pairing PE with Bolt enables role-based access control, logging, and visual reports in the PE console.

- **[Connecting Bolt to PuppetDB](bolt_connect_puppetdb.md)**  

  Configure Bolt to connect to PuppetDB.
