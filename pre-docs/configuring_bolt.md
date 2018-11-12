# Configuring Bolt

Create a configuration file to store and automate the command-line flags you use every time you run Bolt.

By default `$HOME/.puppetlabs/bolt/` is the base directory for user-supplied data such as the configuration and inventory files or the `Boltdir`. To set up a default global configuration for Bolt, create a `~/.puppetlabs/bolt/bolt.yaml` file with global options at the top level of the file. Configure transport specific options for each transport. If a config option is set in the config file and passed with the corresponding command-line flag, the flag takes precedence.

Before it uses the global directory `$HOME/.puppetlabs/bolt`, Bolt searches for `Boltdir` in the parent directories of the directory from which it was run. If found, `Boltdir` is the default location for configuration, inventory, and modules instead of the global path. When you commit a `Boltdir` to a project you can share Bolt configuration and code between users.

-   **[Bolt configuration options](bolt_configuration_options.md)**  
Your Bolt configuration file can contain global and transport options.
-   **[Configuring Bolt to use orchestrator](bolt_configure_orchestrator.md)**  
Configure Bolt to use the orchestrator API and perform actions on PE-managed nodes.
-   **[Connecting Bolt to PuppetDB](bolt_connect_puppetdb.md)**  
Configure Bolt to connect to PuppetDB.

