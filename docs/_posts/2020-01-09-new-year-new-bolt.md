---
title: New Year, New Bolt
---

Welcome to 2020!

The team has been ~~on vacation~~ hard at work since the last update, adding a bevy of new features as well as formalizing and sanding the rough edges of existing features to prepare for the imminent Bolt 2.0 release.

A bulk of the work has been finalizing the v2 inventory, which will fittingly be the inventory API for Bolt 2.0. You can check out [the previous update](2019-09-26-the-road-to-bolt-2) for some more info on what that means.

We've made a number of enhancements to the plugin system, including adding more out-of-the-box integrations. These now include Azure, AWS, Terraform, and Vault among others.

Plugins can now be configured in both `bolt.yaml` and `inventory.yaml` using _other_ plugins. For instance, you can use the Vault plugin to lookup credentials to connect to AWS.

Several new commands have joined the CLI, including `bolt project init` and `bolt project migrate` to create and manage Bolt projects, as well as `bolt group show` to see the targets in a group.

## Bolt 2.0

The Bolt 2.0 release will be coming soon and we encourage everyone to upgrade. The `bolt project migrate` command will automatically translate your Bolt inventory file to the v2 format, which is a great way to prepare for the release.

The backward-incompatible changes will be minimal and primarily target under-used or downright unusable features. In particular, the changes include:

* The `bolt-inventory-pdb` command will be removed in favor of the `puppetdb` inventory plugin
* The `--nodes` flag will be replaced with `--targets`
* v1 inventory files will no longer be supported (use `bolt project migrate` to convert your inventory file)
* The low-level API for dynamically creating and modifying `Target` objects in a plan has been cleaned up and now works reliably

If you want to test your project against Bolt 2.0 today, set `future: true` in `bolt.yaml` to enable Bolt 2.0 compatibility mode.
