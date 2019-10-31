# Configuring Bolt

Create a configuration file to store and automate the command-line flags you use every time you run Bolt.

Configuration for Bolt is loaded from the [Bolt project directory](bolt_project_directories.md#). The default project directory is `~/.puppetlabs/bolt/`. Configure global options (i.e. the modulepath) at the top level of `<boltdir>/bolt.yaml`, and configure transport-specific options for each transport.

Bolt config uses the following precedence, from highest precedence (cannot be overridden) to lowest:
- Target URI (i.e. ssh://user:password@hostname:port)
- [Inventory file](inventory_file.md) options
- Command line flags
- Config file options
- SSH config file options (`~/.ssh/config`, if using SSH)

-   **[Project directories](bolt_project_directories.md#)**  
 Bolt runs in the context of a project directory or a `Boltdir`. This directory contains all of the configuration, code, and data loaded by Bolt.
-   **[Bolt configuration options](bolt_configuration_options.md)**  
Your Bolt configuration file can contain global and transport options.
-   **[Using Bolt with Puppet Enterprise](bolt_configure_orchestrator.md)**  
If you're a Puppet Enterprise (PE) customer, you can configure Bolt to use the PE orchestrator and perform actions on managed nodes. Pairing PE with Bolt enables role-based access control, logging, and visual reports in the PE console.
-   **[Connecting Bolt to PuppetDB](bolt_connect_puppetdb.md)**  
Configure Bolt to connect to PuppetDB.

