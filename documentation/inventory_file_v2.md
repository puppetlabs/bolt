# Inventory file version 2

Version 2 of the inventory file is experimental and might experience breaking changes in future releases.

## Migrating to version 2

Version 2 of the inventory file changes some terms and syntax. To convert to version 2, you must make these changes.

**`version: 2`**

The default version for inventory files is version 1. In order to have Bolt treat your inventory file as a version 2 inventory, specify `version: 2` at the top level.

**`nodes` => `targets`**

In order to standardize terminology across Bolt and capture the breadth of possible targets, such as web services, version 2 of the inventory file uses the `targets` section of a group to specify its members instead of `nodes`.

**`name` => `uri`**

Changing the `name` key to `uri` results in an inventory file that matches the behavior of version 1.

In version 1 of the inventory file, Bolt treated the `name` field of a node as its URI. This made it impossible to specify a `name` that did not include the hostname of a target, which proved limiting for remote targets. In version 2, the optional `uri` field sets the URI for a target. Any connection information from the URI, such as a user specified by `user@uri` can't be overridden with other configuration methods. If the `uri` is set, it's used as the default value for the `name` key. Every target requires a `name`, so either the `name` or `uri` field must be set.

If there is a bare string in the target's array, Bolt tries to resolve the string to a target defined elsewhere in the inventory. If no target has a name or alias matching the string, Bolt creates a new target with the string as its URI.

### Migrating plans

In addition to inventory file changes, inventory functions such as `get_targets` might not work as expected when called from a manifest block using inventory version 2. `get_targets` returns an empty array when called with `all` as an argument. When called with any other argument, it creates a new Target object for the host specified by the argument. To see the same behavior as `get_targets` displays with the version 1 inventory, extract information outside of a manifest block into a variable and use that variable inside the manifest block.

For example, the following plan:

```
plan setup_lb (
    TargetSpec $pool,
    TargetSpec $lb
) {
  apply_prep([$pool, $lb])

  apply($lb) {
    class { 'profile::lb':
      members => get_targets($pool).map |$targ| { $targ.host }
    }
  }
}

```

Would need to be converted to:

```
plan setup_lb (
   TargetSpec $pool,
   TargetSpec $lb
) {
   apply_prep([$pool, $lb])

   $members = get_targets($pool).map |$targ| { $targ.host }
   apply($lb) {
       class { 'profile::lb':
          members => $members
       }
   }
}
```

## Creating targets in plans

When using inventory version 2, a new and improved API for interacting with `Target`s in inventory is available. Two new plan functions have been added: `get_target` allows retrieving a single `Target` from inventory, and `set_config` allows setting config on a specific `Target`. The updated API also provides a way to instantiate new `Target`s with data that more closely resembles how targets are declared in an inventory file.

For example, consider the following `new_targets` plan:
```
plan new_targets(){
  $new_target = get_target('ssh://user:secret@1.2.3.4:2222')
  $new_target.set_config(['ssh', 'host-key-check'], false)
}
```
In the `new_targets` plan the `get_target` function returns a `Target` identified with the name `ssh://user:secret@1.2.3.4:2222`. If a `Target` with that name does not exist in inventory a new `Target` is instantiated with the `uri` and `name` attributes set to `ssh://user:secret@1.2.3.4:2222` and is added to the `all` group in inventory (where it inherits and configuration for the `all` group). If the `Target` with that name does exist, it is simply returned.

The `set_config` method is used to set a transport specific setting specified by the array of keys to that setting that matches the keys in the structured hash found in an inventory file under the `config` key. This illustrates how a new `Target` can be created from a URI and configuration options that are not able to be set in URI parts can be modified.

You can also use the `Target.new` method to instantiate a `Target`:
```
plan new_target_alternate(){
  $config = { 'transport' => 'ssh',
              'ssh' => {
                'user' => 'user',
                'password' => 'secret',
                'host' => '1.2.3.4'
                'port' => 2222,
                'host-key-check' => false
                }}
  $new_target = Target.new('name' => 'new_target', 'config' => $config)
  $another_new_target = target.new('name' => 'another_new_target', 'uri' => ssh://foo:bar@baz.com:123, 'facts' => { 'datacenter' => 'east' })
}
```

In the `new_target_alternate` plan a new `Target` is created from a hash and is added to the `all` group in inventory. Note that if a `Target` with name `new_target` already exists in inventory, that `Target` is destroyed and the new `Target` takes its place.

## `TargetSpec` parameters in plans

When a plan parameter has the type `TargetSpec`, Bolt includes values for that parameter in inventory.

For example:
```
plan auto_add(TargetSpec $targets) {
  return get_targets('all')
}
```

The `auto_add` plan returns all of the targets in the `all` group. If the value of `$targets` resolves to a `String` that does not match a `Target` name, a group name, a `Target` alias or a target regex, it creates a new `Target` and adds it to the `all` group.

## `Target` reference

Instantiate a target object with `Target.new` from a plan with either a `String` representing the `Target` `name` and `uri`, or a hash with the following structure:

- `uri`: `String`, Target URI (will be used as the `Target` name if a name is not specified)
- `name`: `String`, The name of the target
- `target_alias`: `Variant[String, Array[String]]`, The alias to refer to a target by
- `config`: `Hash`, Configuration options for the Target
- `facts`: `Hash`, Target facts
- `vars`: `Hash`, Target vars
- `features`: `Array`, Target features

For example:
```
plan target_example(){
  # From URI
  $target_1 = Target.new('docker:://root:root@localhost:20024')
  # From hash
  $target_2 = Target.new('name' = 'new-pcp', 'target_alias' = 'test', 'config' => {'transport' => 'pcp'}, 'features' => [puppet-agent])
}
```

The `target_example` plan creates `target_1` from a URI and `target_2` from a hash.

**Note:** In the case where a `Target` is instantiated with only a `String` `uri` value, consider using `get_target`. This creates a `Target` without having to use the `Target.new` syntax.

When you instantiate a `Target`from a `uri` and provide no `name`, the function sets the `name` to the `uri`. It also assigns the `Target` a `safe_name`, which is the `uri` with the password redacted.

For example:
```
plan safe_name(){
  $safe = get_target('ssh://user:secret@1.2.3.4:2222')
  out::message($safe.safe_name)
}
```

The `safe_name` plan creates a new target with `name` and `uri`, and adds it to inventory. The plan prints `ssh://urser@1.2.3.4:2222` as the safe name.

It is important to note that the value of `safe_name` is only different from the value of `name` in the case where the `Target` is constructed from a `uri` and no `name` is specified. When you supply a `name`, the `safe_name` is always set to the value of `name`.

For example:
```
plan unsafe_name(){
  $unsafe = Target.new('name' => 'ssh://user:secret@1.2.3.4:2222')
  out::message($unsafe.safe_name)
}
```

In the `unsafe_name` plan, a `Target` is instantiated with the `name` set to the full `uri` that contains the sensitive password and thus the `safe_name` contains the password.

## Creating a target with a human-readable name and IP address

With version 2 of the inventory you can create a target with a human readable
name even when an ip address is used for connecting. This can be accomplished
either by setting both a `uri` and `name` or by setting `host` in the transport
config in addition to the `name`.

```
targets:
  - name: my_device
    config:
      transport: remote
      remote:
        host: 192.168.100.179
  - name: my_device2
    uri: 192.168.100.179
```

## Plugins and dynamic inventory

Inventory plugins can be used to dynamically load information into the inventory file. See
[Using Plugins](using_plugins.md) for more information on using Bolt's built-in plugins, and
[Writing Plugins](writing_plugins.md) for more information on writing your own plugins.

## Inventory Files

For more information about configuring connections in the inventory and how the inventory file
works, see [Inventory File](inventory_file.md). 
