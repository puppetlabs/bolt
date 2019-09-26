---
author: Michelle Fredette <michelle.fredette@puppet.com\>
---

# Configuring Bolt

Create a configuration file to store and automate the command-line flags you use every time you run Bolt.

Configuration for Bolt is loaded from the [Bolt project directory](bolt_project_directories.md#). To set up a configuration file for Bolt to use outside of a project directory, create a `~/.puppetlabs/bolt/bolt.yaml` file with global options at the top level of the file. Configure transport specific options for each transport. If a config option is set in the config file and passed with the corresponding command-line flag, the flag takes precedence.

-   **[Project directories](bolt_project_directories.md#)**  
 Bolt runs in the context of a project directory or a `Boltdir`. This directory contains all of the configuration, code, and data loaded by Bolt.
-   **[Bolt configuration options](bolt_configuration_options.md)**  
Your Bolt configuration file can contain global and transport options.
-   **[Using Bolt with Puppet Enterprise](bolt_configure_orchestrator.md)**  
If you're a Puppet Enterprise \(PE\) customer, you can configure Bolt to use the PE orchestrator and perform actions on managed nodes. Pairing PE with Bolt enables role-based access control, logging, and visual reports in the PE console.
-   **[Connecting Bolt to PuppetDB](bolt_connect_puppetdb.md)**  
Configure Bolt to connect to PuppetDB.

