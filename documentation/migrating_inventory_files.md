# Upgrading to Bolt 2.0

Welcome to Bolt 2.0! 

You can read about new features and changes in our [Bolt 2.0 blog post](https://puppet.com/blog/introducing-bolt-2-0/).

**Before you upgrade:**
- Take a look at the [Changelog](https://github.com/puppetlabs/bolt/blob/master/CHANGELOG.md).
- Make sure you've [migrated your inventory files to version 2](#migrating-inventory-files-from-version-1-to-version-2). 

You can view upgrade instructions for your operating system at [Installing Bolt](bolt_installing.md).

## Migrating inventory files from version 1 to version 2

To maintain compatibility with Bolt, migrate your Version 1
inventory files to Version 2. You can complete this process manually by
changing the names of some of the keys in the inventory file, or automatically
using a Bolt command.

### Automatic migration

To automatically migrate a Version 1 inventory file to Version 2, use the `bolt
project migrate` command. Bolt will locate the inventory file for the current
Bolt project and migrate it in place. You can specify the projects and inventory
files you want to migrate using the `--boltdir` and `--inventoryfile` options.

> **Note:** The `bolt project migrate` command modifies an inventory file in place and does not preserve comments or formatting. Before using the command, make sure to backup the inventory file.

### Manual migration

To manually migrate a Version 1 inventory file, begin by changing all instances of `nodes` keys to `targets` keys.

`nodes` => `targets`

Then, change any instance of a `name` key in a `Target` object to a `uri` key.

`name` => `uri`

#### Version 1 inventory file

```yaml
groups:
  - name: linux
    nodes:
      - name: target1.example.com
        alias: target1
      - name: target2.example.com
        alias: target2
```

#### Version 2 inventory file

```yaml
groups:
  - name: linux
    targets:
      - uri: target1.example.com
        alias: target1
      - uri: target2.example.com
        alias: target2
```
