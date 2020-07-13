# `inventory.yaml` fields

Use an [inventory file](inventory_file_v2.md) to store information about
your targets and arrange them into groups. Both targets and groups can
include data such as facts or vars and can configure the transports Bolt uses
to establish connections with targets.

## Top-level fields

The top level of your inventory file contains fields that configure the
implicit `all` group. These fields apply to all of the groups and targets in
the inventory file. For more information on inventory files, such as
precedence, see [Inventory files](inventory_file_v2.md)

### `config`

A map of configuration options for the implicit `all` group. Configuration
set at this level applies to all groups and targets in the inventory file.
For a detailed description of each option, their default values, and any
available sub-options, see [Transport configuration
reference](#bolt_transports_reference.md).

- **Type:** Hash

```yaml
config:
  transport: ssh
  ssh:
    host-key-check: false
  winrm:
    user: bolt
    password: hunter2!
```

### `facts`

A map of system information, also known as
[facts](https://puppet.com/docs/puppet/latest/lang_facts_and_builtin_vars.html),
for the implicit `all` group. Facts set at this level apply to all groups and
targets in the inventory file.

- **Type:** Hash

```yaml
facts:
  os:
    family: Darwin
```

### `features`

A list of available features for the implicit `all` group. Features set at this
level apply to all groups and targets in the inventory file.

- **Type:** Array

> 🔩 **Tip:** You can set the `puppet-agent` feature to indicate that Bolt
> should skip installing the Puppet agent on all targets when using
> `bolt apply` or the `apply_prep` plan function.

```yaml
features:
  - puppet-agent
```

### `groups`

A [list of groups](#group-objects) and their associated configuration.

- **Type:** Array

```yaml
groups:
  - name: linux
    targets:
      - linux-1.example.com
      - linux-2.example.com
  - name: windows
    targets:
      - windows-1.example.com
      - windows-2.example.com
```

### `targets`

A [list of targets](#target-objects) and their associated configuration.

- **Type:** Array

```yaml
targets:
  - target1.example.com
  - target2.example.com
```

### `vars`

A map of variables for the implicit `all` group. Variables set at this level
apply to all groups and targets in the inventory file.

- **Type:** Hash

```yaml
vars:
  ssh_config: /etc/ssh_config
```

## Group objects

Use a `groups` field to specify a list of groups, which contain a list of
targets. Each item in the `groups` list is a map of data and configuration for
the group. Group objects accept many of the same fields as the implicit `all`
group.

### `config`

A map of configuration options for the group. Configuration set at this level
applies to all groups and targets under the group. For a detailed description
of each option, their default values, and any available sub-options, see
[Transport configuration reference](#bolt_transports_reference.md).

- **Type:** Hash

```yaml
groups:
  - name: linux
    config:
      transport: ssh
      ssh:
        host-key-check: false
```

### `facts`

A map of system information, also known as
[facts](https://puppet.com/docs/puppet/latest/lang_facts_and_builtin_vars.html),
for the group. Facts set at this level apply to all groups and targets under
the group.

- **Type:** Hash

```yaml
groups:
  - name: windows
    facts:
      os:
        family: Windows
```

### `features`

A list of available features for the group. Features set at this level apply to
all groups and targets under the group.

- **Type:** Array

> 🔩 **Tip:** You can set the `puppet-agent` feature on the group to indicate
> that Bolt should skip installing the Puppet agent on all targets under the
> group when using `bolt apply` or the `apply_prep` plan function.

```yaml
groups:
  - name: agents
    features:
      - puppet-agent
```

### `groups`

A [list of groups](#group-objects) and their associated configuration.

- **Type:** Array

```yaml
groups:
  - name: servers
    groups:
      - name: linux
      - name: windows
```

### `name`

The name of the group. Group names must be unique and cannot conflict with the
name of another group or a target, including the implicit `all` group. **This
option is required.**

- **Type:** String

```yaml
groups:
  - name: linux
```

### `targets`

A [list of targets](#target-objects) and their associated configuration.

- **Type:** Array

```yaml
groups:
  - name: linux
    targets:
      - linux-1.example.com
      - linux-2.example.com
```

### `vars`

A map of variables for the group. Vars set at this level apply to all groups
and targets under the group.

- **Type:** Hash

```yaml
groups:
  - name: linux
    vars:
      ssh_config: /etc/ssh_config
```

## Target objects

The `targets` field is used to specify a list of targets. Each item in the
`targets` list must be one of the following:

- A string representation of the target's URI
- A map of data and configuration options for the target

When specifying a target using a map of data and configuration, the following
fields are available:

### `alias`

A unique alias to refer to the target. Aliases cannot conflict with the name
of a group, the name of a target, or another alias.

- **Type** Array

```yaml
targets:
  - uri: linux-1.example.com
    alias:
      - database
  - uri: linux-2.example.com
    alias:
      - webserver
```

### `config`

A map of configuration options for the target. A detailed description of each
option, their default values, and any available sub-options can be viewed in
[Transport configuration reference](bolt_transports_reference.md).

- **Type:** Hash

```yaml
targets:
  - uri: windows.example.com
    config:
      transport: winrm
      winrm:
        user: bolt
        password: hunter2!
```

### `facts`

A map of system information, also known as
[facts](https://puppet.com/docs/puppet/latest/lang_facts_and_builtin_vars.html),
for the target.

- **Type:** Hash

```yaml
targets:
  - uri: linux.example.com
    facts:
      os:
        architecture: x86_64
```

### `features`

A list of available features for the target.

- **Type:** Array

> 🔩 **Tip:** You can set the `puppet-agent` feature on the target to indicate
> that Bolt should skip installing the Puppet agent on the target when using
> `bolt apply` or the `apply_prep` plan function.

```yaml
targets:
  - uri: linux.example.com
    features:
      - puppet-agent
```

### `name`

A human-readable name for the target. This option is required unless the `uri`
option is set.

- **Type:** String

```yaml
targets:
  - name: database
```

### `uri`

The URI of the target. This option is required unless the `name` option is set.

- **Type:** String

```yaml
targets:
  - uri: linux.example.com
```

### `vars`

A map of variables for the target.

- **Type:** Hash

```yaml
targets:
  - uri: linux.example.com
    vars:
      ssh_config: /etc/ssh_config
```

## Example file

```yaml
# inventory.yaml
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
