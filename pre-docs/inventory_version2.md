# Inventory Version 2

The second version of the inventory file format is currently experimental but
is available for early adopters to play with. There may be breaking changes to
this format in minor versions of bolt.

## Migrating from version 1

In order to convert a version 1 inventory file to version 2 make the following changes.

### `version: 2`

The default version for inventory files is version 1. In order to have bolt
treat your inventory file as a version 2 inventory you must specify `version:
2` at the top level.

### `nodes` => `targets`

In order to standardize terminology across bolt and capture the breadth of
possible targets(such as web services) inventory v2 uses the `targets` section
of a group to specify it's members instead of `nodes`.

### `name` => `uri`

Changing the `name` key to `uri` will result in an inventory file that matches
the behavior of version 1.

In version 1 of inventory bolt treated the `name` field of a node as it's uri.
This made it impossible to specify a `name` that did not include the hostname
of a target which proved limiting for remote targets. In version 2 the optional
`uri` field will set the URI for a target. Any connection information from the
URI (ie. a user specified by 'user@uri') cannot be overridden with other
configuration methods. If the `uri` is set it will be the default value for the
`name` key. Every target requires a `name`, either the `name` or `uri` field
must be set.

If there is a bare string in the targets array bolt will try to resolve the
string to a target defined elsewhere in the inventory. If no target has a name
or alias matching the string bolt will create a new target with the string as
it's uri.

## Version 2 only features

### Creating a node with a human readable name and ip address

With version 2 of the inventory you can create a node with a human readable
name even when an ip address is used for connecting. This can be accomplished
either by setting both a `uri` and `name` or by setting `host` in the transport
config in addition to the `name`.

```
targets:
  - name: my_device
    config:
      tranport: remote
      remote:
        host: 192.168.100.179
  - name: my_device2
    uri: 192.168.100.179
```

### `target-lookups` and dynamic puppetdb queries

`target-lookups` is a new key at the group level that allows you to dynamically
lookup the targets in the node. The lookup method is eventually expected to be
pluggable but for now Bolt only ships a single builtin plugin `puppetdb` that
can use a puppetdb query to populate the targets.

```
groups:
  - name: windows
    target-lookups:
      - plugin: puppetdb
        query: "inventory[certname] { facts.osfamily = 'windows' }"
    config:
      transport: winrm
  - name: redhat
    target-lookups:
      - plugin: puppetdb
        query: "inventory[certname] { facts.osfamily = 'RedHat' }"
    config:
      transport: ssh
```

`target-lookups` contains an array of target lookup objects. Each
`target-lookup` entry must include a `plugin` key that defines which plugin
should be used for the lookup. The rest of the keys are specific to the plugin
being used.

For the puppetdb plugin The query field is a string containing a pql query or an array containing a
query in the puppetdb ast syntax.

Make sure you have [configured puppetdb](./bolt_connect_puppetdb.md)



## Inventory config

You can only set transport configuration in the inventory file. This means using a top level `transport` value to assign a transport to the target and all values in the section named for the transport (`ssh`, `winrm`, `remote`, etc.). You can set config on targets or groups in the inventory file. Bolt performs a depth first search of targets, followed by a search of groups, and uses the first value it finds. Nested hashes are merged.

This inventory file example defines two top-level groups: `ssh_targets` and `win_targets`. The `ssh_targets` group contains two other groups: `webservers` and `memcached`. Five targets are configured to use ssh transport and four other targets to use WinRM transport.

```
groups:
  - name: ssh_targets
    groups:
      - name: webservers
        targets:
          - name: my_node1
            uri: 192.168.100.179
          - 192.168.100.180
          - 192.168.100.181
      - name: memcached
        targets:
          - 192.168.101.50
          - 192.168.101.60
        config:
          ssh:
            user: root
    config:
      transport: ssh
      ssh:
        user: centos
        private-key: ~/.ssh/id_rsa
        host-key-check: false
  - name: win_targets
    groups:
      - name: domaincontrollers
        targets:
          - 192.168.110.10
          - 192.168.110.20
      - name: testservers
        targets:
          - 172.16.219.20
          - 172.16.219.30
        config:
          winrm:
            user: vagrant
            password: vagrant
            ssl: false
    config:
      transport: winrm
      winrm:
        user: DOMAIN\opsaccount
        password: S3cretP@ssword
        ssl: true

```

### Override a user for a specific target

```
targets:
  - uri: linux1.example.com
    config:
      ssh:
        user: me
```

### Provide an alias to a target

The inventory can be used to create aliases to refer to a target. This can be useful to refer to targets with long or complicated names - `db.uswest.acme.example.com` - or for targets that include protocol and/or port for uniqueness - `127.0.0.1:2222` and `127.0.0.1:2223`. It can also be useful when generating targets in a dynamic environment to give generated targets stable names to refer to.

An alias can be a single name or list of names. Each alias must match the regex `/[a-zA-Z]\w+/`. When using Bolt, you may refer to a target by its alias anywhere the target name would be applicable, such as the `--targets` command-line argument or a `TargetSpec`.

```
targets:
  - uri: linux1.example.com
    alias: linux1
    config:
      ssh:
        port: 2222
```

Aliases must be unique across the entire inventory. You can use the same alias multiple places, but they must all refer to the same target. Alias names must not match any group or target names used in the inventory.

A list of targets may refer to a target by its alias, as in:
```
targets:
  - uri: 192.168.110.10
    alias: linux1
groups:
  - name: group1
    targets:
      - linux1
```

## Inventory facts, vars, and features

In addition to config values you can store information relating to `facts`, `vars` and `features` for targets in the inventory. `facts` represent observed information about the target including what can be collected by Facter. `vars` contain arbitrary data that may be passed to run\_\* functions or used for logic in plans. `features` represent capabilities of the target that can be used to select a specific task implementation.

```
groups:
  - uri: centos_targets
    targets:
      - foo.example.com
      - bar.example.com
      - baz.example.com
    facts:
      operatingsystem: CentOS
  - name: production_targets
    vars:
      environment: production
    features: ['puppet-agent']

```

## Objects

The inventory file uses the following objects.

-   **Config**

    A config is a map that contains transport specific configuration options.

-   **Group**

    A group is a map that requires a `name` and can contain any of the following:

    -   `targets` : `Array[Node]`

    -   `groups` : Groups object
    -   `config` : Config object

    -   `facts` : Facts object

    -   `vars` : Vars object

    -   `features` : `Array[Feature]`

    A group name must match the regular expression values `/[a-zA-Z]\w+/`. These are the same values used for environments.

    A group may contain other groups. Any targets in the nested groups will also be in the parent group. The configuration of nested groups will override the parent group.

-   **Groups**

    An array of group objects.

-   **Facts**

    A map of fact names and values. values may include arrays or nested maps.

-   **Feature**

    A string describing a feature of the target.

-   **Target**

    A target can be just the string of its target uri or a map that requires a name key and can contain a config. For example, a target block can contain any of the following:

    ```
    "host1.example.com"
    ```

    ```
    uri: "host1.example.com"
    ```

    ```
    uri: "host1.example.com"
    config:
      transport: "ssh"
    ```

    If the target entry is a map, it may contain any of:
    - `alias` : `String` or `Array[String]`
    - `config` : Config object
    - `facts` : Facts object
    - `vars` : Vars object
    - `features` : `Array[Feature]`

-   **Target name**

    The name used to refer to a target.

-   **Targets**

    An array of target objects.

-   **Vars**

    A map of value names and values. Values may include arrays or nested maps.


## File format

The inventory file is a yaml file that contains a single group. This group can be referred to as "all". In addition to the normal group fields, the top level has an inventory file version key that defaults to 1.

## Precedence

If a target specifies a `uri` or is created from a URI string any URI-based configuration information like host, transport or port will override config values even those defined in the same block. For config values, the first value found for a target is used. Node values take precedence over group values and are searched first. Values are searched for in a depth first order. The first item in an array is searched first.

Configure transport for targets.

```
groups:
  - name: linux
    targets:
      - linux1.example.com
      - linux2.example.com
      - linux3.example.com
  - name: win
    targets:
      - win1.example.com
      - win2.example.com
      - win3.example.com
    config:
      transport: winrm
```

Configure login and escalation for a specific target.

```
targets:
  - uri: host1.example.com
    config:
      ssh:
          user: me
          run-as: root
```

## Remote Targets

Configure a remote target. When using the remote transport the protocol of the
target name does not have to map to the transport if you set the transport config
option. This is useful if the target is an http API as in the following example.

```yaml
targets:
  - host1.example.com
  - uri: https://user1:secret@remote.example.com
    config:
      transport: remote
      remote:
        # The remote transport will use the host1.example.com target from
        # inventory to proxy tasks execution on.
        run-on: host1.example.com
  # This will execute on localhost.
  - remote://my_aws_account
```

**Related information**


[Naming tasks](writing_tasks.md#)
