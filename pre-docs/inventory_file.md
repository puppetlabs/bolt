# Inventory file

In Bolt, you can use an inventory file to store information about your nodes. For example, you can organize your nodes into groups or set up connection information for nodes or node groups.

The inventory file is a yaml file stored by default at `inventory.yaml` inside the `Boltdir`. At the top level it contains an array of nodes and groups. Each node can have a config, facts, vars, and features specific to that node. Each group can have an array of nodes and a config hash. node. Each group can have an array of nodes, an array of child groups, and can set default config, vars, and features for the entire group.

**Note:** Config values set at the top level of inventory will only apply to targets included in that inventory file. Set config for unknown targets in the bolt config file.

## Inventory config

You can only set transport configuration in the inventory file. This means using a top level `transport` value to assign a transport to the target and all values in the `transports` sections. You can set config on nodes or groups in the inventory file. Bolt performs a depth first search of nodes, followed by a search of groups, and uses the first value it finds. Nested hashes are merged.

This inventory file example defines two top-level groups: `ssh_nodes` and `win_nodes`. The `ssh_nodes` group contains two other groups: `webservers` and `memcached`. Five nodes are configured to use ssh transport and four other nodes to use WinRM transport.

```
groups:
  - name: ssh_nodes
    groups:
      - name: webservers
        nodes:
          - 192.168.100.179
          - 192.168.100.180
          - 192.168.100.181
      - name: memcached
        nodes:
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
        nodes:
          - 192.168.110.10
          - 192.168.110.20
      - name: testservers
        nodes:
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

## Override a user for a specific node

```
nodes: 
  - name: linux1.example.com
    config: 
      ssh:
        user: me
```

## Inventory facts, vars, and features

In addition to config values you can store information relating to `facts`, `vars` and `features` for nodes in the inventory. `facts` represent observed information about the node including what can be collected by Facter. `vars` contain arbitrary data that may be passed to run\_\* functions or used for logic in plans. `features` represent capabilities of the target that can be used to select a specific task implementation.

```
groups:
  - name: centos_nodes
    nodes:
      - foo.example.com
      - bar.example.com
      - baz.example.com
    facts:
      operatingsystem: CentOS
  - name: production_nodes
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

    -   `nodes` : `Array[Node]`

    -   `groups` : Groups object
    -   `config` : Config object

    -   `facts` : Facts object

    -   `vars` : Vars object

    -   `features` : `Array[Feature]`

    A group name must match the regular expression values `/[a-zA-Z]\w+/`. These are the same values used for environments.

    A group may contain other groups. Any nodes in the nested groups will also be in the parent group. The configuration of nested groups will override the parent group.

-   **Groups**

    An array of group objects.

-   **Facts**

    A map of fact names and values. values may include arrays or nested maps.

-   **Features**

    A string describing a feature of the target.

-   **Node**

    A node can be just the string of its node name or a map that requires a name key and can contain a config. For example, a node block can contain any of the following:

    ```
    "host1.example.com"
    ```

    ```
    name: "host1.example.com"
    ```

    ```
    name: "host1.example.com"
    config:
      transport: "ssh"
    ```

-   **Node name**

    The URI used to create the node.

-   **Nodes**

    An array of node objects.

-   **Vars**

    A map of value names and values. Values may include arrays or nested maps.


## File format

The inventory file is a yaml file that contains a single group. This group can be referred to as "all". In addition to the normal group fields, the top level has an inventory file version key that defaults to 1.0.

## Precedence

When searching for node config, the URI used to create the target is matched to the node-name. Any URI-based configuration information like host, transport or port will override config values even those defined in the same block. For config values, the first value found for a node is used. Node values take precedence over group values and are searched first. Values are searched for in a depth first order. The first item in an array is searched first.

Configure transport for nodes.

```
groups:
  - name: linux
    nodes:
      - linux1.example.com
      - linux2.example.com
      - linux3.example.com
  - name: win
    nodes:
      - win1.example.com
      - win2.example.com
      - win3.example.com
    config:
      transport: winrm
```

Configure login and escalation for a specific node.

```
nodes:
  - name: host1.example.com
    config:
      ssh:
          user: me
          run-as: root
```

-   **[Generating inventory files](inventory_file_generating.md)**  
 Use the `bolt-inventory-pdb` script to generate inventory files based on PuppetDB queries.

**Related information**  


[Naming tasks](writing_tasks.md#)

