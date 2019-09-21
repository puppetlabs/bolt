# Configuring Bolt

Create a configuration file to store and automate the command-line flags you use every time you run Bolt.

Configuration for Bolt is loaded from the [Bolt project
directory](./bolt_project_directory.md). To set up a
configuration file for Bolt to use outside of a Bolt project directory, create a `~/.puppetlabs/bolt/bolt.yaml`
file with global options at the top level of the file. Configure transport
specific options for each transport. If a config option is set in the config
file and passed with the corresponding command-line flag, the flag takes
precedence.

-   **[Bolt configuration options](bolt_configuration_options.md)**
Your Bolt configuration file can contain global and transport options.
-   **[Configuring Bolt to use orchestrator](bolt_configure_orchestrator.md)**
Configure Bolt to use the orchestrator API and perform actions on PE-managed nodes.
-   **[Connecting Bolt to PuppetDB](bolt_connect_puppetdb.md)**
Configure Bolt to connect to PuppetDB.

