
# Configuring Bolt

Create a config file to store and automate the CLI flags you use every time you run Bolt.

By default Bolt uses `$HOME/.puppetlabs/bolt/` as the base directory for user
supplied data like the configuration and inventory files or the `Boltdir`. To create a default global
configuration for Bolt, create a `~/.puppetlabs/bolt/bolt.yml` file with global
options at the top level of the file. Configure transport specific options for
each transport. If a config option is set in the config file and passed with
the corresponding command-line flag, the flag takes precedence.

Before using the global directory `$HOME/.puppetlabs/bolt` bolt will
search in the parent directories of the directory from which it was run looking
for a directory called `Boltdir`. If one is found this directory will be used as the
default location for config, inventory and modules instead of the global
path. By committing a Boltdir to a project you're working on you can
share bolt configuration and code between users.

- Bolt configuration options
  Your Bolt config file can contain global and transport options.
- Configuring Bolt to use orchestrator
  Configure Bolt to use the orchestrator API and perform actions on PE-managed nodes.
