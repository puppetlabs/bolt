# Using plugins

Plugins extend Bolt's functionality in various ways.

Plugins either ship with Bolt or are installed as Puppet modules that have the same name as the plugin. The plugin framework is based on a set of plugin hooks that are implemented by plugin authors and called by Bolt.

A plugin hook provides an API for a specific use case. A plugin can implement multiple hooks. The way in which a plugin is used varies depending on the type of hook used.

## Reference plugins

Reference plugins fetch data from an external source and store it in a static data object. For example, when added to `inventory.yaml` they can discover inventory targets from AWS or PuppetDB, and when added to `bolt.yaml` they can look up a password from Vault.

To use a reference, add an object with a `_plugin` key where you want to use the resolved value. The `_plugin` value must be the name of the plugin to use, and the object must contain any required plugin-specific options.

Bolt currently supports references in the `inventory.yaml` file to define targets, groups, and any data like facts or config. It resolves references only as needed, which means that `targets` and `groups` references are resolved when the inventory is loaded, while data (`vars`, `facts`, `features`, `config`) references are resolved when a target that uses that data is loaded in a plan.

For example, the following `inventory.yaml` will prompt a user for a password the first time the `example.com` target is used.

```
version: 2
targets:
  - uri: example.com
    config:
      transport: ssh
      ssh:
        user: root
        password:
          # The value of this hash will be replaced with the value returned by the reference plugin.
          _plugin: prompt
          message: please enter your SSH password
```

The following example uses the terraform plugin to populate a `cloud-webs` group from terraform state.

```
groups:
  - name: cloud-webs
    targets:
      - _plugin: terraform
        dir: /path/to/terraform/project1
        resource_type: google_compute_instance.web
        uri: network_interface.0.access_config.0.nat_ip
```

This reference will be resolved as soon as Bolt runs.

It is important to understand that plugins are used to reference data. The simplest example of this concept is the [YAML](#yaml) plugin. With the YAML plugin, you can effectively "insert" YAML from one file into another. This allows you to organize an inventory into multiple files.


```yaml
---
# inventory.yaml
version: 2
groups:
  - _plugin: yaml
    filepath: inventory.d/first_group.yaml
  - _plugin: yaml
    filepath: invenotry.d/second_group.yaml
```

```yaml
---
# inventory.d/first_group.yaml
name: first_group
targets:
  - one.example.com
  - two.example.com
```

```yaml
---
# inventory.d/second_group.yaml
name: second_group
targets:
  - three.example.com
  - four.example.com
```

## Secret plugins

Secret plugins encrypt and decrypt sensitive values in data. The `bolt secret encrypt` and `bolt secret decrypt` commands encrypt or decrypt data that can be used as a reference in data files.

## Puppet library plugins

Puppet library plugins install Puppet libraries on target nodes when a plan calls `apply_prep`.

## Configuring plugins

Some plugins use configuration data from the `plugins` section of `bolt.yaml`. Each plugin has its own config section. For example, the following `bolt.yaml` will change where the pkcs7 plugin looks for the private key.

```
plugins:
  pkcs7:
    private-key: ~/bolt_private_key.pem
```

Plugin configuration can be derived from other plugins using `_plugin` references. For example, you can encrypt the credentials used to configure the `vault` plugin.

```
plugins:
  vault:
    auth:
      token:
        _plugin: pkcs7
        encrypted_value: |
              ENC[PKCS7,MIIBiQYJKoZIhvcNAQcDoIIBejCCAXYCAQAxggEhMIIBHQIBADAFMAACAQEw
              DQYJKoZIhvcNAQEBBQAEggEARQNZqnN8ByTelBjokvkgOemMxyjmblWga8g6
              y0nYfmA5Hdqj1nC/wIJTZafbmfzCEtUQZ+Hf70YPV04OYy7PU1WtYp0u/B0t
              YCX7GgWHoXUSrEV+YtGyIpoa/pStvzzP12CBIaXwGh62TP6ZSbRnr/q/pnfk
              mOx6HghUoNXfKBLW+sq8KgyNN1DJDTl0KubHVLnJvTc1jjHX7YK+qxV4eb3B
              yklwuaDziPd+pipQOcUfjMnVW45THRUzE06iI8Q+DqVGA7/RsTEdG0HGtj5h
              P7i5wLUdZ2AhYBkP1sacW7yiUjqwPjwMwx0T/xn/DqVW02QOjFgqsaSwi1CD
              MOA3pDBMBgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBC87Iy6lvqGicslM6si
              994ogCDRAeJgS/0HTaFdhjdxC8CmMCADl7qVgxKDf1ztpXznyg==]
```

## Bundled plugins

Bolt ships with a few plugins out of the box: task, puppetdb, terraform, azure_inventory, aws ec2, prompt, pkcs7, and vault.

## Task plugin

The Task plugin lets a Bolt plugin hook run a task. How this task is run depends on the hook called. In most cases the task will run on the `localhost` target without access to any configuration defined in `inventory.yaml`, but with access to any parameters that are configured. The Task plugin extracts the `value` key and uses that as the value of the plugin.

**Reference hook**

The reference hook accepts two options:

-   `task`: The task to run.
-   `parameters`: The parameters to pass to the task.

For example, this will run the `my_json_file::targets` task to look up targets and the `my_db::secret_lookup` task to look up the SSH password.

```
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

To use for targets the task `value` must return an array of target objects in the format that the inventory file accepts. When referring to a config, the type of `value` should match whatever the reference expects. For example `host-key-check` for SSH must be a boolean, `password` must be a string and `run-as-command` must be an array of strings. This result would be appropriate for an entire `ssh` section of config.

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

```
#!/usr/bin/env python
import json, sys
from my_secret import Client

params = json.load(sys.stdin)

client = Client
secret = client.get_secret(data['key'])
# secret can be any value that can be dumped to json.
json.dump({'value': secret}, sys.stdout)
```

## PuppetDB

The PuppetDB plugin supports looking up targets from PuppetDB. It takes a `query` field, which is
either a string containing a [PQL](https://puppet.com/docs/puppetdb/latest/api/query/v4/pql.html)
query or an array containing a [PuppetDB
AST](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html) format query. The query
determines which targets should be included in the group. If `name` or `uri` is not specified with
a [fact lookup](#fact-lookup) then the `[certname]` for each target in the query result will be used as the `uri`
for the new target. Read the [Migrating to Version 2](inventory_file_v2.md#migrating-to-version-2)
section for more details on `uri` and `name` keys.

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

Make sure you have [configured PuppetDB](bolt_connect_puppetdb.md)

### Fact Lookup

If target-specific configuration is required the PuppetDB plugin can be used to lookup configuration values for the `name`, `uri`, and `config` inventory options for each target. The fact lookup values can be either `certname` to reference the `[certname]` of the target or a [PQL dot notation](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html#dot-notation) facts string such as `facts.os.family` to reference fact value. Dot notation is required for both structured and unstructured facts.

**Note:** If the `name` or `uri` values are set to a lookup the PuppetDB plugin will **not** set the `uri` to the certname of the target.

For example, to set the user to be the user from the [identity fact](https://puppet.com/docs/facter/latest/core_facts.html#identity):

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
## YAML

The `yaml` plugin is a module based plugin. For more information see [https://github.com/puppetlabs/puppetlabs-yaml](https://github.com/puppetlabs/puppetlabs-yaml)

## Terraform

The `terraform` plugin is a module based plugin. For more information see [https://github.com/puppetlabs/puppetlabs-terraform](https://github.com/puppetlabs/puppetlabs-terraform)

## Azure inventory

The `azure_inventory` plugin is a module based plugin. For more information see [https://github.com/puppetlabs/puppetlabs-azure_inventory](https://github.com/puppetlabs/puppetlabs-azure_inventory)

## AWS Inventory plugin
The `aws_inventory` plugin is a module based plugin. For more information see [https://github.com/puppetlabs/puppetlabs-aws_inventory](https://github.com/puppetlabs/puppetlabs-aws_inventory)

## Prompt plugin

The prompt plugin allows users to interactively enter sensitive configuration information on the CLI instead of storing that data in the inventoryfile. Data will only be looked up when the value is needed for the target and once the value has been stored it will be re-used for the rest of the Bolt run. The prompt plugin may only be used when nested under `config`. The prompt plugin can be used by replacing the `config` value with a hash that has the following keys:

`_plugin`: The value of `_plugin` must be `prompt` `message`: The value of `message` must be the text to show when prompting the user on the CLI

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

## pkcs7 plugin

This plugin allows config values to be stored in encrypted in the inventory file and decrypted only as needed.

`_plugin`: The value of `_plugin` must be `pkcs7` `encrypted_value`: The encrypted value. Generate encrypted values with `bolt secret encrypt <plaintext>`

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
          encrypted_value: |
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

Before using the pkcs7 plugin you need to create encryption keys. You can create these keys automatically with `bolt secret createkeys` or reuse existing hiera-eyaml pkcs7 keys with bolt secret. You can then encrypt values with `bolt secret encrypt <plaintext>` command and copy the result into your inventory file. If you need to inspect an encrypted value from the inventory you can decrypt it with `bolt secret decrypt <encrypted_value>`.

## Configuration

By default keys are stores in the `keys` directory of the Bolt project repo. If you're sharing your project directory you can move the private key outside the project directory by configuring the key location in `bolt.yaml`.

```
plugins:
  pkcs7:
    private-key: ~/bolt_private_key.pem
```

-   `keysize`: They size of the key to generate with `bolt secret createkeys`: default: `2048`
-   `private-key`: The path to the private key file. default: `<boltdir>/keys/private_key.pkcs7.pem`
-   `public-key`: The path to the public key file. default: `<boltdir>/keys/public_key.pkcs7.pem`

## Vault plugin

This plugin allows config values to be set by accessing secrets from a Key/Value engine on a Vault
server. The plugin ships in the [puppetlabs-vault module](https://forge.puppet.com/puppetlabs/vault)
and is automaticaly installed with the Bolt package. You can see the [git
repo](https://github.com/puppetlabs/puppetlabs-vault) for more information.
