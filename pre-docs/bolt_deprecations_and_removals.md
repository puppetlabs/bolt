# Deprecations and removals

A list of the features and functions deprecated or removed from Bolt 1.x.

## WARNING: changes to `aws::ec2`, `pkcs7`, and `task` plugins

To improve consistency of plugin behavior, there are three changes to plugins. The `aws::ec2` plugin is now named `aws_inventory`. The `pkcs7` plugin now expects `encrypted_value` rather than `encrypted-value`. The `task` plugin now expects tasks to return both Target lists and config data under the `value` key instead of the `targets` or `values` keys.

## WARNING: Ubuntu 14.04 is deprecated \(1.30.0\)

Bolt will drop support for Ubuntu 14.04 in the near future. Users can install Bolt from the Ubuntu 16.04 package.

## `lookups` removed from `target_lookups` \(0.25.0\)

We have deprecated the `target-lookups` key in the experimental inventory file v2. To address this change, migrate any `target-lookups` entries to `targets` and move the `plugin` key in each entry to `_plugin`.

## Configuration location ~/.puppetlab/bolt.yaml \(0.21.0\)

When the directory Boltdir was added as the local default configuration directory, the previous directory, `~/.puppetlab/bolt.yaml`, was deprecated in favor of `~/.puppetlabs/bolt/bolt.yaml`. For more information on the current default directory for configfile, inventoryfile and modules, see [Configuring Bolt](configuring_bolt.md). \([BOLT-503](https://tickets.puppetlabs.com/browse/BOLT-503)\)

**Parent topic:**[Bolt release notes](bolt_release_notes.md)

