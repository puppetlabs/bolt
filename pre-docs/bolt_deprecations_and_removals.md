# Deprecations and removals

A list of the features and functions deprecated or removed from Bolt 1.x.

## Configuration location ~/.puppetlab/bolt.yaml \(0.21.0\)

When the directory Boltdir was added as the local default configuration directory, the previous directory, `~/.puppetlab/bolt.yaml`, was deprecated in favor of `~/.puppetlabs/bolt/bolt.yaml`. For more information on the current default directory for configfile, inventoryfile and modules, see [Configuring Bolt](configuring_bolt.md). \([BOLT-503](https://tickets.puppetlabs.com/browse/BOLT-503)\)

