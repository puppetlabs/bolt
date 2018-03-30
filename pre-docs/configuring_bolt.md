
# Configuring Bolt

Create a config file to store and automate the CLI flags you use every time you run Bolt.

To configure Bolt, create a `~/.puppetlabs/bolt.yml` file with global options at
the top level of the file. Configure transport specific options for each
transport. If a config option is set in the config file and passed with the
corresponding command-line flag, the flag takes precedence.

- Bolt configuration options
  Your Bolt config file can contain global and transport options.
- Configuring Bolt to use orchestrator
  Configure Bolt to use the orchestrator API and perform actions on PE-managed nodes.
