# Inventory files

Use an inventory file to store information about your targets, control how Bolt
connects to them, and arrange them into groups. Grouping your targets lets you
aim your Bolt commands at the group instead of having to reference each target
individually.

An inventory file is part of a Bolt project and must exist alongside a
`bolt-project.yaml` file. For more information, see [Bolt projects](projects.md).

## Inventory file structure

### Top-level fields

The top level of an inventory file acts as the implicit `all` group and has
similar fields as a `groups` object.

The following fields are available at the top level of an inventory file:

| Key | Description | Type |
| --- | ----------- | ---- |
| `config` | The transport configuration for the `all` group. Optional. For more information see [Configuring Bolt](configuring_bolt.md#inventoryyaml).  | `Hash` |
| `facts` | The facts for the `all` group. Optional. | `Hash` |
| `features` | The features for the `all` group. Optional. | `Array[String]`
| `groups` | A list of targets and groups and their associated configuration. Optional. | `Array[Group]` |
| `targets` | A list of targets and their associated configuration. Optional. | `Array[Target]` |
| `vars` | The vars for the `all` group. Optional. | `Hash` |

### Group object

A group lists a set of `targets` and `groups` and their associated
configuration. Each group is a map that can contain any of the following fields:

| Key | Description | Type |
| --- | ----------- | ---- |
| `config` | The transport configuration for the group. Optional. For more information see [Configuring Bolt](configuring_bolt.md#inventoryyaml). | `Hash` |
| `facts` | The facts for the group. Optional. | `Hash` |
| `features` | The features for the group. Optional. | `Array[String]`
| `groups` | A list of groups and their associated configuration. Optional. | `Array[Group]` |
| `name` | The name of the group. **Required.** | `String` |
| `targets` | A list of targets and their associated configuration. Optional. | `Array[Target]` |
| `vars` | The variables for the group. Optional. | `Hash` |

An example of an inventory file with two groups named `linux` and `windows`:
```yaml
groups:
  - name: linux
    targets:
      - target1.example.com
      - target2.example.com
    config:
      transport: ssh
  - name: windows
    targets:
      - target3.example.com
      - target4.example.com
    config:
      transport: winrm
```

### Target object

Specify a target under the `targets` key. The `targets` key accepts an array
where each element is either a string or a hash. 
- For a string, use the string representation of the target's Universal Resource
  Identifier (URI).
- A hash must specify either the `uri` for a hash, or a `name`. If you don't
  specify a `name`, Bolt uses the `uri` as the target's name. To make it easier to run Bolt commands
  on the target, specify both a `uri` and a `name` and run your commands against
  the `name`.

Bolt uses the target's `uri` to establish a connection to the target. If you set
a `name` and no `uri`, you must specify the hostname for the target using the
`host` key in your transport configuration. If the transport you're using does
not support hostname configuration, you must set a `uri`.

An example of two targets specified with the string representations of
their URIs:

```yaml
targets:
  - target1.example.com
  - target2.example.com
```

An example of two targets specified with `uri` and `name` in hashes:

```yaml
targets:
  - uri: target1.example.com
    name: target1
    config:
      transport: ssh
  - uri: target2.example.com
    name: target2
    config:
      transport: winrm
```

An example of a target specified with `name` and no `uri`. In this case, Bolt
uses the hostname of the target from the transport's `host` key to establish a
connection with the target:

```yaml
targets:
  - name: target1
    config:
      transport: ssh
      ssh:
        host: target1.example.com
```

Similar to `name`, you can specify an `alias` as another way to refer to a
target. In the following example, you could run a command using the target's
`uri`, `name`, or `alias`.

```yaml
targets:
  - uri: target1.example.com
    name: target1
    alias: dashboard
    config:
      transport: ssh
  - uri: target2.example.com
    name: target2
    alias: database
    config:
      transport: winrm
```

Targets specified with a hash accept the following fields:

| Key | Description | Type |
| --- | ----------- | ---- |
| `alias` | A unique alias to refer to the target. Optional. | `String` |
| `config` | The configuration for the target. Optional. | `Hash` |
| `facts` | The facts for the target. Optional. | `Hash` |
| `features` | The features for the target. Optional. | `Array[String]`
| `name` | A human-readable name for a target.<br> **Required** when specifying a target using a hash. Optional if using `uri`. If you don't specify a `name`, Bolt uses the `uri` as the target name. | `String` |
| `uri` | The URI of the target. Bolt uses the `uri` to establish a connection to the target. <br> **Required** when specifying a target using a hash, unless you specify a `name` **and** configure a hostname using `host` in the target's transport configuration.| `String` |
| `vars` | The variables for the target. Optional. | `Hash` |

## Transport configuration

Use the `config` field to configure the transports that Bolt uses to connect to
targets in your inventory file. For example, you can use this section to specify
a transport like SSH, configure authentication options like passwords or the
path to your private key file, or specify a proxy. 

You can configure the transport at multiple levels of your inventory file:
- Put `config` at the top (`all` group) level to configure settings that apply
  to all targets in the inventory file.
- Put `config` at the `groups` level to configure settings that apply to all
  targets in a group.
- Put `config` at the `target` level to configure settings that apply to a
  specific target.

For a full list of the available transports and fields, see [Transport
  configuration options](bolt_transports_reference.md).

## Showing inventory

The following command provides a quick way to view the resolved values for a
target or group of targets:

- _\*nix shell command_

  ```shell
  bolt inventory show --targets <TARGET LIST> --detail
  ```

- _PowerShell cmdlet_

  ```powershell
  Get-BoltInventory -Targets <TARGET LIST> -Detail
  ```

## Precedence

When searching for a target's configuration data, Bolt matches a target's URI
with its name. Bolt uses depth-first search and uses the first value it finds.

The `config` values for a target object, such as `host`, `transport`, and
`port`, take precedent and override any `config` values at the group level. Bolt
merges non-`config` data in the target object, such as `facts` and `vars`, with
data in the group object.

```yaml
groups:
  - name: group1
    targets:
      - name: mytarget
        uri: target.example.com
        config:
          ssh:
            user: puppet
        facts:
          hardwaremodel: x86_64
      - name: myothertarget
        uri: target2.example.com
    config:
      ssh:
        host-key-check: false
  - name: group2
    targets:
      - name: mytarget
        uri: target.example.com
        config:
          ssh:
            password: bolt
    config:
      ssh:
        password: password
    facts:
      operatingsystem: CentOS

```

In the example above,  `mytarget` in `group1` contains the fact, `hardwaremodel:
x86_64.` The fact `operatingsystem: CentOS` is set in `group2` which also
contains `mytarget`.

Showing the detailed inventory for `mytarget` will return both facts:

```json
…

"facts": {
  "operatingsystem": "CentOS",
  "hardwaremodel": "x86_64"
},
```

Inventory files are not context-aware. Any data set for a target, whether in a
target definition or a group, apply to all definitions of the target. For
example, the inventory file above contains two definitions of `mytarget`. The
values for `user` and `host-key-check` are set in `group1`. The value for
`password` is set in `group2`. If you ran a Bolt command on `group2`, all three
values would be set on `mytarget`.

Showing the detailed inventory for `group` will return all three configuration
values:


```json
{
  "targets": [
    {
      "name": "mytarget",
      "uri": "target.example.com",
      "config": {
        "ssh": {
          "host-key-check": false,
          "password": "bolt",
          "user": "puppet"
        },
        "transport": "ssh"
      }
    }
  ]
}
```
> **Note**: The password for mytarget is defined at the target level in
> `group2`, and overrides the password set at the group level.

## Plugins

Use plugins to dynamically load information into the inventory file. Plugins
either ship with Bolt, or are installed as Puppet modules that have the same
name as the plugin. The plugin framework is based on a set of plugin hooks that
are implemented by plugin authors and called by Bolt.

📖 **Related information**

- For more information on plugins that ship with Bolt, see [Supported
  plugins](supported_plugins.md).
- For more information about how plugins work, see [Using
  plugins](./using_plugins.md).

## Inventory file versioning

This page documents version 2 inventory files. Version 1 inventory files are
deprecated and lack features like plugins. If you're using Bolt 2.0 or later,
use version 2 inventory files. If you need to migrate your inventory files from
version 1, you can use the `migrate` command documented at [Migrate a Bolt
project](projects.md#migrate-a-bolt-project).

## Inventory file examples

### Basic inventory file

The following inventory file contains a basic hierarchy of groups and targets.
As with all inventory files, it has a top-level group named `all`, which refers
to all targets in the inventory. The `all` group has two subgroups named `linux`
and `windows`.

The `linux` group lists its targets and sets the default transport for the
targets to the SSH protocol.

The `windows` group lists its targets and sets the default transport for the
targets to the WinRM protocol.

The inventory file sets top-level configuration that applies to the `all` group.
It sets default configuration for the `ssh` and `winrm` transports.

```yaml
groups:
  - name: linux
    targets:
      - target1.example.com
      - target2.example.com
    config:
      transport: ssh
      ssh:
        private-key: /path/to/private_key.pem
  - name: windows
    targets:
      - name: win1
        uri: target3.example.com
      - name: win2
        uri: target4.example.com
    config:
      transport: winrm
config:
  ssh:
    host-key-check: false
  winrm:
    user: Administrator
    password: Bolt!
    ssl: false
```

### Detailed inventory file

The following inventory file contains a more detailed hierarchy of groups and
targets. As with all inventory files, it has a top-level group named `all`,
which refers to all targets in the inventory. The `all` group has two subgroups
named `ssh_nodes` and `win_nodes`.

The `ssh_nodes` group has two subgroups - `webservers` and `memcached` - and
sets the default transport for targets in the group to the SSH protocol. It also
specifies a few configuration options for the SSH transport. Each of the
subgroups lists the targets in the group and the `memcached` group has
additional SSH transport configuration for its targets.

The `win_nodes` group also has two subgroups - `domaincontrollers` and
`testservers` - and sets the default transport for targets in the group to the
WinRM protocol. It also specifies a few configuration options for the WinRM
transport. Each of the subgroups lists the targets in the group and the
`testservers` group has additional WinRM transport configuration for its
targets.

```yaml
groups:
  - name: ssh_nodes
    groups:
      - name: webservers
        targets:
          - 192.168.100.179
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
  - name: win_nodes
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
            realm: MYDOMAIN
            ssl: false
    config:
      transport: winrm
      winrm:
        user: DOMAIN\opsaccount
        password: S3cretP@ssword
        ssl: true
```

### Inventory file with plugins

The following inventory file uses several bundled plugins.

* The `yaml` plugin composes `aws_inventory.yaml` and `azure_inventory.yaml`
  into a single inventory file loaded by Bolt.
* The `aws_inventory` plugin generates targets from AWS EC2 instances.
* The `azure_inventory` plugin generates targets from Azure VMs.
* The `vault` plugin loads a secret from a Hashicorp Vault server and uses it as
  a password.
* The `prompt` plugin configures the `vault` plugin in a configuration file and
  prompts for the user's Vault password.

The `inventory.yaml` file:

```yaml
groups:
  - _plugin: yaml
    filepath: inventory/aws_inventory.yaml
  - _plugin: yaml
    filepath: inventory/azure_inventory.yaml
```

The `aws_inventory.yaml` file:

```yaml
name: aws
targets:
  - _plugin: aws_inventory
    region: us-west-1
    target_mapping:
      uri: public_ip_address
config:
  transport: ssh
  ssh:
    user: ec2-user
    password:
      _plugin: vault
      path: secrets/aws
      field: password
```

The `azure_inventory.yaml` file:

```yaml
name: azure
targets:
  - _plugin: azure_inventory
    location: westus
config:
  transport: winrm
  winrm:
    user: Administrator
    password:
      _plugin: vault
      path: secrets/azure
      field: password
```

The `bolt-project.yaml` configuration file:

```yaml
plugins:
  vault:
    server_url: https://127.0.0.1:8200
    cacert: /path/to/cert/cacert.pem
    auth:
      method: userpass
      user: developer
      pass:
        _plugin: prompt
        message: Enter your Vault password
```

### Share inventory between projects

Because projects are used to run a specific workflow on a list of targets, it's
common to have multiple projects that each run a different workflow on the same
list of targets. If you have multiple projects that all use the same inventory,
it can be useful to use a shared inventory file so you don't need to maintain
your inventory in each project individually.

#### Using the command line

The simplest way to specify a shared inventory is to save the inventory file in
an accessible location such as the Bolt user configuration directory and then
specify the inventory file from the command line.

Save the shared inventory file to
`~/.puppetlabs/etc/bolt/shared_inventory.yaml`:

```yaml
targets:
  - server-1.example.org
  - server-2.example.org
  - server-3.example.org
config:
  ssh:
    user: puppet
    password: Bolt!
    host-key-check: false
```

Specify the shared inventory file from the command line:

_\*nix shell command_

```shell
bolt inventory show --targets all --inventoryfile ~/.puppetlabs/etc/bolt/shared_inventory.yaml
```

_PowerShell cmdlet_

```powershell
Get-BoltInventory -Targets 'all' -Inventoryfile 'C:\Users\Administrator\.puppetlabs\etc\bolt\shared_inventory.yaml'
```

#### Using the `yaml` plugin

Instead of specifying the path to the shared inventory file for every command,
you can load the shared inventory into each project's inventory dynamically.
To do this, create an `inventory.yaml` file for each project and use the `yaml`
plugin to load the shared inventory.

Save the shared inventory file to
`~/.puppetlabs/etc/bolt/shared_inventory.yaml`:

```yaml
targets:
  - server-1.example.org
  - server-2.example.org
  - server-3.example.org
config:
  ssh:
    user: puppet
    password: Bolt!
    host-key-check: false
```

Save an inventory file to each project that loads the shared inventory file:

```yaml
_plugin: yaml
filepath: ~/.puppetlabs/bolt/shared_inventory.yaml
```

When the project loads the inventory, it injects the shared inventory file,
allowing you to reference the same list of targets across multiple projects.

#### Composing project-specific inventory

If your projects only share some inventory in common, or have project-specific
configuration for targets, you can use the `yaml` plugin to compose an inventory
for each project.

For example, you might have two projects where both projects run on a set of web
servers, but one of the projects also runs on a set of database servers. Both
projects also specify different login credentials.

To compose an inventory for each project, you can save each set of targets to a
separate shared inventory, and then reference them as needed using the `yaml`
plugin in each project's inventory file.

Save the set of web servers to
`~/.puppetlabs/etc/bolt/server_inventory.yaml`:

```yaml
- server-1.example.org
- server-2.example.org
- server-3.example.org
```

Save the set of database servers to
`~/.puppetlabs/etc/bolt/database_inventory.yaml`:

```yaml
- db-1.example.org
- db-2.example.org
- db-3.example.org
```

Save an inventory file to each project that loads the necessary targets:

```yaml
# ~/projects/servers/inventory.yaml
groups:
  - name: servers
    targets:
      _plugin: yaml
      filepath: ~/.puppetlabs/etc/bolt/server_inventory.yaml
config:
  ssh:
    user: admin
    password: admin
```

```yaml
# ~/projects/webapp/inventory.yaml
groups:
  - name: servers
    targets:
      _plugin: yaml
      filepath: ~/.puppetlabs/etc/bolt/server_inventory.yaml
  - name: databases
    targets:
      _plugin: yaml
      filepath: ~/.puppetlabs/etc/bolt/database_inventory.yaml
config:
  ssh:
    user: puppet
    password: Bolt!
```

#### Specifying target defaults

Shared inventory files allow you to specify default configuration and data for
targets that can be overridden with project-specific configuration and data. If
you list a target multiple times in an inventory file, the first instance of the
target in the inventory file [takes precedence](#precedence) over subsequent
instances of the target.

For example, the following inventory file includes the `example.org` target. The
target is defined in the project's inventory file and is also defined in a
shared inventory file with some default configuration and data.

```yaml
# ~/projects/example/inventory.yaml
groups:
  - name: servers
    targets:
      - uri: example.org
        name: example
        config:
          ssh:
            password: Bolt!
  - name: _defaults
    targets:
      _plugin: yaml
      filepath: ~/.puppetlabs/etc/bolt/shared_inventory.yaml
```

```yaml
# ~/.puppetlabs/etc/bolt/shared_inventory.yaml
- uri: example.org
  name: example
  config:
    ssh:
      user: admin
      password: Puppet!
  vars:
    role: server
```

Bolt uses the password `Bolt!` because the project-specific target definition
comes before the target definition in the shared inventory.

📖 **Related information**

- For more information on configuration options, see [Configuring
  Bolt](configuring_bolt.md).
- For a comprehensive list of inventory fields and their descriptions, see
  [inventory.yaml fields](bolt_inventory_reference.md).
- For more information on transport options, see [Transport configuration
  options](bolt_transports_reference.md).
