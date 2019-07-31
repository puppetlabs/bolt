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

### Migrating Plans

In addition to inventory file changes, inventory functions such as `get_targets` might not work as expected when called from an [apply block](applying_manifest_blocks.md) using inventory version 2. `get_targets` returns an empty array when called with `'all'` as an argument. Otherwise, it creates a new Target object for that host. If you want to have the same behavior as the version 1 inventory, you can extract information outside of an apply block into a variable, and use that variable inside the apply block.

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


## Creating a node with a human readable name and ip address

With version 2 of the inventory you can create a node with a human readable
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

## Plugins and Dynamic Inventory

Inventory Plugins can be used to dynamically load information into the inventory file.
To use a plugin replace a static value in the inventory file with an Object
containing a `_plugin` key and any plugin specific options that are required.
The location in which you do this replacement will determine how the plugin
behaves. Currently plugins are only supported for `inventory_targets`, in the
`targets` section of inventory, and `inventory_config`, in the config section of
inventory. Most plugins only work in one location or the other.

#### Target plugins

To use a `inventory_target` plugin replace an item in the targets array with a plugin object.

```
---
targets:
  - _plugin: my_plugin
    plugin_specific_option: foo
```

The following plugins can be used for targets

* `puppetdb` - Query PuppetDB to populate the targets.
* `terraform` - Load a Terraform state file to populate the targets.
* `aws::ec2` - Load running AWS EC2 instances to populate the targets.
* `task` - Run a task to discover targets.

#### Config plugins

Config plugins can be used inside the `config` section of a target or group to
lookup a value. Config lookup plugins that return a value with a `_plugin` will
not be reevaluated.

```
---
config:
  transport:
    _plugin: my_plugin
    plugin_specific_option: foo
```

The Following plugins an be used for config:

* `prompt`: Prompt a user for a configuration value
* `pkcs7`: decrypt a pkcs7 encrypted value from the inventory file.
* `task` : Run a task to lookup a configuration value.

#### Task

The Task plugin will run a task on `localhost` to lookup configuration
information or target lists for the inventory.

For both use cases the plugin accepts two keys:
* `task`: The task to run.
* `parameters`: The parameters to pass to the task.

For example this will run the `my_json_file::targets` task to look up targets
and the `my_db::secret_lookup` task to look up the ssh password.

```
---
version: 2
targets:
  - _plugin: task
    task: my_json_file::targets
    parameters:
      # These parameters are specific to the task
      file: /etc/targets/data.json
      environment: production
      app: my_app
config:
  ssh:
    password:
      _plugin: task
      task: my_db::secret_lookup
      parameters:
        # These parameters are task specific
        key: ssh_password
```

##### Inventory Config Tasks

To look up configuration information for the inventory return a `config` key in
the task result containing the data that will be used in place where the plugin entry is.
The value of config can be any type of data that is appropriate for the
specific location in config. For example `host-key-check` for ssh must be a
boolean, `password` must be a string and `run-as-command` must be an array of
strings. This result would be appropriate for an entire `ssh` section of config.

```
{
  "config": {
    "host-key-check": true,
    "password": "hunter2",
    "run-as-command": [ "sudo", "-k", "-S", "-E", "-u", "user", "-p", "password"]
  }
}
```

This task looks up a password value from a secret database and returns it.

```python
#!/usr/bin/env python
import json, sys
from my_secret import Client

params = json.load(sys.stdin)

client = Client
secret = client.get_secret(data['key'])
# secret can be any value that can be dumped to json.
json.dump({'config': secret}, sys.stdout)
```

##### Inventory Target Tasks

To look up a list of targets for inventory return a hash or JSON object that
includes a targets key with an array value from task. Each item in this list
should be a Target JSON object matching the Object format you would use in a targets
section of the inventory file. Bare string targets are not valid.

This task reads in a JSON file and looks up a value.

```python
#!/usr/bin/env python
import json, sys

params = json.load(sys.stdin)
with open(params['file']) as fh:
  data = json.load(fh)
targets = data[params['environment']][params['app']]
json.dump({'targets': targets}, sys.stdout)
```

#### PuppetDB

The PuppetDB plugin supports looking up target object from PuppetDB. It takes a
`query` field, which is either a string containing a
[PQL](https://puppet.com/docs/puppetdb/latest/api/query/v4/pql.html) query or
an array containing a [PuppetDB
AST](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html) format
query. The query is used to determine which targets should be included in the
group. If `name` or `uri` is not specified with a [fact lookup](#fact-lookups)
then the [certname] for each target in the query result will be used as the
`uri` for the new target. Read the [Migrating to Version
2](#migrating-to-version-2) section for more details on `uri` and `name` keys.

```
groups:
  - name: windows
    targets:
      - _plugin: puppetdb
        query: "inventory[certname] { facts.osfamily = 'windows' }"
    config:
      transport: winrm
  - name: redhat
    targets:
      - _plugin: puppetdb
        query: "inventory[certname] { facts.osfamily = 'RedHat' }"
    config:
      transport: ssh
```

Make sure you have [configured PuppetDB](./bolt_connect_puppetdb.md)

If target-specific configuration is required the PuppetDB plugin can be used to
lookup configuration values for the `name`, `uri`, and `config` inventory
options for each target. The fact lookup values can be either `certname` to
reference the [certname] of the target or a [PQL dot
notation](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html#dot-notation)
facts string such as `facts.os.family` to reference fact value. Dot notation is
required for both structured and unstructured facts.

**Note:** If the `name` or `uri` values are set to a lookup the PuppetDB plugin
will **not** set the `uri` to the certname of the target.

For example, to set the user to be the user from the [identity
fact](https://puppet.com/docs/facter/latest/core_facts.html#identity):

```
version: 2
groups:
  - name: dynamic_config
    targets:
      - _plugin: puppetdb
        query: "inventory[certname] { facts.osfamily = 'RedHat' }"
        config:
          ssh:
            # Lookup config from PuppetDB facts
            user: facts.identity.user
    # And include static config
    config:
      ssh:
        tmpdir: /tmp/mytmp
```

And to use the certname of a target as the `name`:
```
version: 2
groups:
  - name: dynamic_config
    targets:
      - _plugin: puppetdb
        query: "inventory[certname] { facts.osfamily = 'RedHat' }"
        name: certname
        config:
          ssh:
            # Lookup config from PuppetDB facts
            hostname: facts.networking.interfaces.en0.ipaddress
```

#### Terraform

The Terraform plugin supports looking up target object from a Terraform state
file. It accepts several fields:

`dir`: The directory from which to load Terraform state
`resource_type`: The Terraform resources to match, as a regular expression
`uri`: The property of the Terraform resource to use as the target URI (optional)
`statefile`: The name of the Terraform state file to load within `dir` (optional, defaults to `terraform.tfstate`)
`name`: The property of the Terraform resource to use as the target name (optional)
`config`: A Bolt config map where each value is the Terraform property to use for that config setting

One of `uri` or `name` is required. If only `uri` is set, then the value of `uri` will be used as the `name`.

```
groups:
  - name: cloud-webs
    targets:
      - _plugin: terraform
        dir: /path/to/terraform/project1
        resource_type: google_compute_instance.web
        uri: network_interface.0.access_config.0.nat_ip
      - _plugin: terraform
        dir: /path/to/terraform/project2
        resource_type: aws_instance.web
        uri: public_ip
```

Multiple resources with the same name are identified <resource>.0, <resource>.1, etc.

The path to nested properties must be separated with `.`: for example, `network_interface.0.access_config.0.nat_ip`.

For example, the following truncated output creates two targets, named `34.83.150.52` and `34.83.16.240`. These targets are created by matching the resources `google_compute_instance.web.0` and `google_compute_instance.web.1`. The `uri` for each target is the value of their `network_interface.0.access_config.0.nat_ip` property, which corresponds to the externally routable IP address in Google Cloud.

```
google_compute_instance.web.0:
  id = web-0
  cpu_platform = Intel Broadwell
  machine_type = f1-micro
  name = web-0
  network_interface.# = 1
  network_interface.0.access_config.# = 1
  network_interface.0.access_config.0.assigned_nat_ip =
  network_interface.0.access_config.0.nat_ip = 34.83.150.52
  network_interface.0.address =
  network_interface.0.name = nic0
  network_interface.0.network = https://www.googleapis.com/compute/v1/projects/cloud-app1/global/networks/default
  network_interface.0.network_ip = 10.138.0.22
  project = cloud-app1
  self_link = https://www.googleapis.com/compute/v1/projects/cloud-app1/zones/us-west1-a/instances/web-0
  zone = us-west1-a
google_compute_instance.web.1:
  id = web-1
  cpu_platform = Intel Broadwell
  machine_type = f1-micro
  name = web-1
  network_interface.# = 1
  network_interface.0.access_config.# = 1
  network_interface.0.access_config.0.assigned_nat_ip =
  network_interface.0.access_config.0.nat_ip = 34.83.16.240
  network_interface.0.address =
  network_interface.0.name = nic0
  network_interface.0.network = https://www.googleapis.com/compute/v1/projects/cloud-app1/global/networks/default
  network_interface.0.network_ip = 10.138.0.21
  project = cloud-app1
  self_link = https://www.googleapis.com/compute/v1/projects/cloud-app1/zones/us-west1-a/instances/web-1
  zone = us-west1-a
google_compute_instance.app.1:
  id = app-1
  cpu_platform = Intel Broadwell
  machine_type = f1-micro
  name = app-1
  network_interface.# = 1
  network_interface.0.access_config.# = 1
  network_interface.0.access_config.0.assigned_nat_ip =
  network_interface.0.access_config.0.nat_ip = 35.197.93.137
  network_interface.0.address =
  network_interface.0.name = nic0
  network_interface.0.network = https://www.googleapis.com/compute/v1/projects/cloud-app1/global/networks/default
  network_interface.0.network_ip = 10.138.0.23
  project = cloud-app1
  self_link = https://www.googleapis.com/compute/v1/projects/cloud-app1/zones/us-west1-a/instances/app-1
  zone = us-west1-a
```

#### AWS EC2

The AWS EC2 plugin supports looking up running AWS EC2 instances. It supports several fields:

- `profile`: The [named profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html) to use when loading from AWS `config` and `credentials` files. (optional, defaults to `default`)
- `region`: The region to look up EC2 instances from.
- `name`: The [EC2 instance attribute](https://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Instance.html) to use as the target name. (optional)
- `uri`: The [EC2 instance attribute](https://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Instance.html) to use as the target URI. (optional)
- `filters`: The [filter request parameters](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DescribeInstances.html) used to filter the EC2 instances by. Filters are name-values pairs, where the name is a request parameter and the values are an array of values to filter by. (optional)
- `config`: A Bolt config map where the value for each config setting is an EC2 instance attribute.

One of `uri` or `name` is required. If only `uri` is set, then the value of `uri` will be used as the `name`.

```
groups:
  - name: aws
    targets:
      - _plugin: aws::ec2
        profile: user1
        region: us-west-1
        name: public_dns_name
        uri: public_ip_address
        filters:
          - name: tag:Owner
            values: [Devs]
          - name: instance-type
            values: [t2.micro, c5.large]
        config:
          ssh:
            host: public_dns_name
    config:
      ssh:
        user: ec2-user
        private-key: ~/.aws/private-key.pem
        host-key-check: false
```

Accessing EC2 instances requires a region and valid credentials to be specified. The following locations are searched in order until a value is found:

**Region**
- `region: <region>` in the inventory file
- `ENV['AWS_REGION']`
- `credentials: <filepath>` in the config file
- `~/.aws/credentials`

**Credentials**
- `ENV['AWS_ACCESS_KEY_ID']` and `ENV['AWS_SECRET_ACCESS_KEY']`
- `credentials: <filepath>` in the config file
- `~/.aws/credentials`

If the region or credentials are located in a shared credentials file, a `profile` can be specified in the inventory file to choose which set of credentials to use. For example, if the inventory file were set to `profile: user1`, the second set of credentials would be used:

```
[default]
aws_access_key_id=...
aws_secret_access_key=...
region=...

[user1]
aws_access_key_id=...
aws_secret_access_key=...
region=...
```

AWS credential files stored in a non-standard location (`~/.aws/credentials`) can be specified in the Bolt config file:

```
plugins:
  aws:
    credentials: ~/alternate_path/credentials
```

#### Prompt plugin

The 'prompt' plugin can be used to allow users to interactively enter sensitive configuration information on the CLI instead of storing that data in the inventoryfile. Data will only be looked up when the value is needed for the target and once the value has been stored it will be re-used for the rest of the Bolt run. The `prompt` plugin may only be used when nested under `config`. The prompt plugin can be used by replacing the config value with a hash that has the following keys:

`_plugin`: The value of `_plugin` must be `prompt`
`message`: The value of `message` must be the text to show when prompting the user on the CLI

Example
```
version: 2
targets:
  - uri: 192.168.100.179
    config:
      transport: ssh
      ssh:
        user: root
        password:
          _plugin: prompt
          message: please enter your ssh password
```

#### pkcs7 plugin

This plugin allows config values to be stored in encrypted in the inventory
file and decrypted only as needed.

`_plugin`: The value of `_plugin` must be `pkcs7`
`encrypted-value`: The encrypted value. Generate encrypted values with `bolt secret encrypt <plaintext>`

Example

```
version: 2
targets:
  - uri: 192.168.100.179
    config:
      transport: ssh
      ssh:
        user: root
        password:
          _plugin: pkcs7
          encrypted-value: |
                ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw
                DQYJKoZIhvcNAQEBBQAEggEAdCVkiddtK8jHz4g1y1pkB27VHCZx7dVzEiyT
                33BgFv9atk8Ns/WE1tveFvyuEaDpk9y/FKisuh8DsTnR2mfGvHtX+BQdNqV6
                L8/nIdwoEqYFd5sKFJnOlpdm7BMX4QDoCfGb+b2UB8A/7eJJ5AcgBVtrJLLE
                VvqSCtqME12ltifdMivMP1hnVJOAhIpib8CwOIIP+Dtv7P7cPaHGTdQpR6Dp
                jbe+AUDM6kcKGADLOYriPQ1UV6zDz5aeUbrwbr4FicHL/sQBPDcWIJR2elwY
                bh8hCDe/IIWE7TOiauXOPyMPKohz622KNoJDJbmv5MhBwNFHSjgKAlOAxL3i
                DK7XXzA8BgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBCvjDMKTjsHloKP04WO
                Dq0ogBAUjTZMjbKjkndMSqPC5mGC]
```

Before using the pkcs7 plugin you need to create encryption keys. You can
create these keys automatically with `bolt secret createkeys` or reuse existing
hiera-eyaml pkcs7 keys with bolt secret. You can then encrypt values with `bolt
secret encrypt <plaintext>` command and copy the result into your inventory
file. If you need to inspect an encrypted value from the inventory you can
decrypt it with `bolt secret decrypt <encrypted-value>`.

##### Configuration

By default keys are stores in the `keys` directory of bolt project repo. If
you're sharing your project directory you can move the private key outside the
project directory by configuring the key location in bolt.yaml

```
---
plugins:
  pkcs7:
    private-key: ~/bolt_private_key.pem
```

* `keysize`: They size of the key to generate with `bolt secret createkeys`: default: `2048`
* `private-key`: The path to the private key file. default: `keys/private_key.pkcs7.pem`
* `public-key`: The path to the public key file. default: `keys/public_key.pkcs7.pem`

#### Vault plugin


This plugin allows config values to be set by accessing secrets from a Key/Value engine on a Vault server. It supports several fields:

- `_plugin`: The value of `_plugin` must be `vault`
- `server_url`: The URL of the Vault server (optional, defaults to `ENV['VAULT_ADDR']`)
- `auth`: The method for authorizing with the Vault server and any necessary parameters (optional, defaults to `ENV['VAULT_TOKEN']`)
- `path`: The path to the secrets engine (required)
- `field`: The specific secret being used (optional, defaults to a Ruby hash of all secrets at the `path`)
- `version`: The version of the K/V engine (optional, defaults to 1)


**Authentication Methods**

Vault requires a token to assign an identity and set of policies to a user before accessing secrets. The Vault plugin offers 2 authentication methods:


`token`

Authenticate using a token. This method requires the following fields:

- `method`: The value of `method` must be `token`
- `token`: The token to authenticate with


`userpass`

Request a token by logging into the Vault server with a username and password. This method requires the following fields:

- `method`: The value of `method` must be `userpass`
- `user`: The username
- `pass`: The password


You can add any Vault plugin field to the inventory configuration. The following example shows how you would access the `private-key` secret on a KVv2 engine mounted at `secrets/bolt`:


```
---
version: 2
targets:
  - ...
config:
  ssh:
    user: root
    private-key:
      key-data:
        _plugin: vault
        server_url: http://127.0.0.1:8200
        auth:
          method: userpass
          user: bolt
          pass: bolt
        path: secrets/bolt
        field: private-key
        version: 2
```


You can also set configuration in the config file (typically `bolt.yaml`) under the `plugins` field. If a field is set in both the inventory file and the config file, Bolt will use the value set in the inventory file. The available fields for the config file are:

- `server_url`
- `auth`


```
---
plugins:
  vault:
    server_url: http://127.0.0.1:8200
    auth:
      method: token
      token: xxxxx-xxxxx
```

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
            realm: MYDOMAIN
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

[certname]: https://puppet.com/docs/puppet/latest/lang_facts_and_builtin_vars.html#trusted-facts
