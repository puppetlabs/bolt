---
title: The Road to Bolt 2.0
---

The past few weeks have had some large features in flight and we're finally seeing them land, so it's time for another update.

We released Bolt 1.31 and the big news is that our so-called plugin system is now _actually_ pluggable!

You can now bundle and ship inventory plugins as ordinary Bolt tasks in modules. Currently that includes looking up targets and config (`resolve_reference`), and secret encryption/decryption.

To write a module with a plugin, you need to do two things:
1) Add a `bolt_plugin.json` at the root of the module to tell Bolt that it has plugins. For now, this can just contain `{}`.
2) Write a task with the same name as the plugin "hook" you want to implement (this can be overridden in `bolt_plugin.json` later) that returns an object with a `value` key.

For example, to turn the `mymodule` module into a plugin that can retrieve targets, just add `bolt_plugin.json` and write a task called `mymodule::resolve_reference`.

`mymodule` can then be referenced from the inventory. When Bolt runs, it will run the task with whatever parameters you set and will substitute the result in the inventory.

```yaml
groups:
  - name: mynodes
    targets:
      - _plugin: mymodule
        user: nick
        application: web
```

For a real world example, check out the [puppetlabs-azure_inventory module](https://github.com/puppetlabs/puppetlabs-azure_inventory).

## Bolt 2, Inventory 2

We also wanted to take some time to share some of our plans for the upcoming Bolt 2.0 release.

The marquee feature of Bolt 2.0 is already coming into existence in Bolt 1.x. That's the new v2 inventory format and Target API.

The biggest change in the v2 inventory is how targets are defined and managed. In inventory v1, a target always had a "name" field which was parsed as a URI to determine connection information. That mixing of identity with data caused trouble if you wanted to later change the connection information for the target in a plan. For instance, if you wanted to use a different transport.

In v2, a target separately has a "name" as well as connection information. You can set both a URI as well as individual connection fields like host and port. This makes it easier to dynamically modify and create new Targets within a plan, which is helpful for plans that provision new nodes.

A related improvement is that arguments to parameters of type `TargetSpec` will automatically be added to the inventory before the plan is run. For example, the following plan:

```puppet
plan test(TargetSpec $nodes) {
  return get_targets('all')
}
```

If you were to run this plan with an empty `inventory.yaml` file, for instance with `bolt plan run test --nodes foo,bar,baz`, it would have returned nothing, because the inventory was empty. With the v2 inventory, it will return `["foo", "bar", "baz"]`, because those targets are added to the inventory automatically.

Inventory v2 is also the only version which supports the plugin functionality mentioned above. Inventory v2 is available for you to try out in Bolt today and will be the only format in Bolt 2.0. [Check out the docs](https://puppet.com/docs/bolt/latest/inventory_file_v2.html) to see how to migrate your inventory.

Check back for more updates as Bolt 2.0 draws nearer. In the meantime, you can follow the [Bolt 2.0 milestone](https://github.com/puppetlabs/bolt/milestone/1) to see what's happening.
