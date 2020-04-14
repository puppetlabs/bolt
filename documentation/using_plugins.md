# Using plugins

Use Plugins to dynamically load information into an inventory file or configuration file. Plugins either ship with Bolt or are installed as Puppet modules that have the same name as the plugin. The plugin framework is based on a set of plugin hooks that are implemented by plugin authors and called by Bolt.

A plugin hook provides an API for a specific use case. A plugin can implement multiple hooks. The way in which a plugin is used varies depending on the type of hook used.

> **Note:** Plugins are only available in configuration files and version 2 inventory files.


## Reference plugins

Reference plugins fetch data from an external source and store it in a static data object. For example, they can discover inventory targets from AWS or PuppetDB.

To use a reference, add an object with a `_plugin` key where you want to use the
resolved value. The `_plugin` value must be the name of the plugin you're using,
and the object must contain any required plugin-specific options.

Bolt currently supports references in an inventory file to define targets,
groups, and any data like `facts` or `config`. It resolves references only as
needed, which means that `targets` and `groups` references are resolved when the
inventory is loaded, while data, such as `vars`, `facts`, `features`, and `config`
references, are resolved when a target that uses that data is loaded in a plan.


### AWS

The `aws_inventory` plugin generates targets from AWS EC2 instances. 

It is a module-based plugin available on the Puppet Forge and is installed with
Bolt. [View the documentation on the Forge](https://forge.puppet.com/puppetlabs/aws_inventory).


### Azure

The `azure_inventory` plugin generates targets from Azure VMs and VM scale sets. 

It is a module-based plugin available on the Puppet Forge and is installed with
Bolt. [View the documentation on the forge](https://forge.puppet.com/puppetlabs/azure_inventory).


### Environment variable

The `env_var` plugin allows users to read values stored in environment variables and load
them into an inventory or configuration file.

#### Available fields

The following fields are available to the `env_var` plugin.

| Key | Description | Type | Default |
| --- | ----------- | ---- | ------- |
| `var` | The name of the environment variable to read from. | `String` | None |

#### Example usage

Looking up a value from an environment variable in an inventory file:

```yaml
targets:
  - target1.example.com
config:
  ssh:
    user: bolt
    password:
      _plugin: env_var
      var: BOLT_PASSWORD
```

### Prompt

The `prompt` plugin allows users to interactively enter sensitive configuration
information on the CLI instead of storing that data in the inventory file. Data
is looked up when the value is needed for the target. Once the value has been
stored, it is re-used for the rest of the Bolt run. The `prompt` plugin must 
be nested under the `config` field.

#### Available fields

The following fields are available to the `prompt` plugin.

| Key | Description | Type | Default |
| --- | ----------- | ---- | ------- |
| **`_plugin`** | The name of the plugin.<br> **Required.** Must be set to `prompt`. | `String` | None |
| **`message`** | The text to show when prompting the user.<br> **Required.** | `String` | None |

#### Example usage

Prompting for a password in an inventory file:

```yaml
targets:
  - target1.example.com
config:
  ssh:
    password:
      _plugin: prompt
      message: Enter your SSH password
```


### PuppetDB

The `puppetdb` plugin queries PuppetDB for a group of targets. 

If target-specific configuration is required, the `puppetdb` plugin can be used to lookup configuration values for the `alias`, `config`, `facts`, `features`, `name`, `uri` and `vars` inventory options for each target. These values can be set in the `target_mapping` field. The fact lookup values can be either `certname` to reference the `[certname]` of the target, or a [PQL dot notation](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html#dot-notation) facts string such as `facts.os.family` to reference a fact value. Dot notation is required for both structured and unstructured facts.

#### Available fields

The following fields are available to the `puppetdb` plugin.

> **Note:** If neither `name` nor `uri` is specified in `target_mapping`, then `uri` will be set to `certname`.

| Key | Description | Type | Default |
| --- | ----------- | ---- | ------- |
| **`_plugin`** | The name of the plugin.<br> **Required.** Must be set to `puppetdb`. | `String` | None |
| **`query`** | A string containing a [PQL query](https://puppet.com/docs/puppetdb/latest/api/query/v4/pql.html) or an array containing a [PuppetDB AST format query](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html).<br> **Required.** | `String` | None |
| `target_mapping` | A hash of target attributes (`name`, `uri`, `config`) to populate with fact lookup values. | `Hash` | None |

#### Available fact paths

The following values/patterns are available to use for looking up facts in the `target_mapping` field:

| Key | Description |
| --- | ----------- |
| `certname` | The certname of the node returned from PuppetDB. This is short hand for doing: `facts.trusted.certname`. |
| `facts.*` | [PQL dot notation](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html#dot-notation) facts string such as `facts.os.family` to reference fact value. Dot notation is required for both structured and unstructured facts. |

#### Example usage

Lookup targets with the fact `osfamily: RedHat` and setting:
 * The alias with the fact `hostname`
 * The name with the fact `certname`
 * A target fact called `custom_fact` with the `custom_fact` from PuppetDB
 * A feature from the fact `custom_feature`
 * The SSH hostname with the fact `networking.interfaces.en0.ipaddress`
 * The puppetversion var from the fact `puppetversion`

```yaml
targets:
  - _plugin: puppetdb
    query: "inventory[certname] { facts.osfamily = 'RedHat' }"
    target_mapping:
      alias: facts.hostname
      name: certname
      facts:
        custom_fact: facts.custom_fact
      features:
        - facts.custom_feature
      config:
        ssh:
          hostname: facts.networking.interfaces.en0.ipaddress
      vars:
        puppetversion: facts.puppetversion
```


### Task

The `task` plugin lets a Bolt plugin hook run a task. How this task is run depends on the hook called. In most cases the task will run on the localhost target without access to any configuration defined in an inventory file, but with access to any parameters that are configured. The plugin extracts the `value` key and uses that as the value.

To use the `task` plugin to load targets, the task value must return an array of
target objects in the format that the inventory file accepts. When referring to
another value, the type of value should match whatever the reference expects.
For example, `host-key-check` for SSH must be a boolean, `password` must be a
string, and `run-as-command` must be an array of strings. The following result
would be appropriate for the entire SSH section of a configuration.

```json
{
  "config": {
    "host-key-check": true,
    "password": "bolt",
    "run-as-command": [ "sudo", "-k", "-S", "-E", "-u", "user", "-p", "password"]
  }
}
```

#### Available fields

The following fields are available to the `task` plugin:

| Key | Description | Type | Default |
| --- | ----------- | ---- | ------- |
| **`_plugin`** | The name of the plugin.<br> **Required** and must be set to `task` | `String` | None |
| **`task`** | The name of the task to run.<br> **Required.** | `String` | None |
| `parameters` | The parameters to pass to the task. | `Hash` | None |

#### Example usage

Loading targets with a `my_json_file::targets` task and a password with a `my_db::secret_lookup` task:

```yaml
targets:
  - _plugin: task
    task: my_json_file::targets
    parameters:
      file: /etc/targets/data.json
      environment: production
      app: my_app
config:
  ssh:
    password:
      _plugin: task
      task: my_db::secret_lookup
      parameters:
        key: ssh_password
```

A python task to load a secret from a database:

```python
#!/usr/bin/env python
import json, sys
from my_secret import Client

params = json.load(sys.stdin)

client = Client
secret = client.get_secret(data['key'])
# secret can be any value that can be dumped to json.
json.dump({'value': secret}, sys.stdout)
```


### Terraform

The `terraform` plugin generates targets from local and remote Terraform state files. 

It is a module-based plugin available on the Puppet Forge and is installed with
Bolt. [View the documentation on the Forge](https://forge.puppet.com/puppetlabs/terraform).


### Vault

The `vault` plugin allows values to be set by accessing secrets from a Key/Value engine on a Hashicorp Vault server. 

It is a module-based plugin available on the Puppet Forge and is installed with
Bolt. [View the documentation on the Forge](https://forge.puppet.com/puppetlabs/vault).


### YAML

The `yaml` plugin composes multiple YAML files into a single file. This can be used to combine multiple inventory files or to separate sensitive data from the Bolt project directory.

It is a module-based plugin available on the Puppet Forge and is installed with
Bolt. [View the documentation on the Forge](https://forge.puppet.com/puppetlabs/yaml)


## Secret plugins

Secret plugins encrypt and decrypt sensitive values in data. The `bolt secret encrypt` and `bolt secret decrypt` commands encrypt or decrypt data that can be used as a reference in data files.


### pkcs7

The `pkcs7` plugin allows configuration values to be stored as encrypted text in the inventory file and decrypted only as needed.

Using the pkcs7 plugin requires encryption keys. These keys can be created automatically with the command `bolt secret createkeys` or by reusing existing hiera-eyaml pkcs7 keys. By default, Bolt stores these keys in a `keys/` directory in the current Bolt project.

Once keys are generated, values can be encrypted with the command `bolt secret encrypt <plaintext>` and the result can be copied into an inventory file. An encrypted value can be inspected by decrypting using the command `bolt secret decrypt <encrypted_value>`.

#### Available fields

The following fields are available to the `pkcs7` plugin in an inventory file:

| Key | Description | Type | Default |
| --- | ----------- | ---- | ------- |
| **`_plugin`** | The name of the plugin.<br> **Required** and must be set to `pkcs7` | `String` | None |
| **`encrypted_value`** | The encrypted value.<br> **Required.** | `String` | None |

The following fields are available to the pkcs7 plugin in a configuration file:

| Key | Description | Type | Default |
| --- | ----------- | ---- | ------- |
| `keysize` | The size of the key to generate with `bolt secret createkeys`. | `Integer` | `2048` |
| `private-key` | The path to the private key file. | `String` | `<boltdir>/keys/private_key.pkcs7.pem` |
| `public-key` | The path to the public key file. | `String` | `<boltdir>/keys/public_key.pkcs7.pem` |

#### Example usage

Encrypt a password in an inventory file:

```yaml
targets:
  - uri: target1.example.com
    config:
      ssh:
        password:
          _plugin: pkcs7
          encrypted_value: |
            MY ENCRYPTED DATA
```

Configure the pkcs7 plugin in a configuration file:

```yaml
plugins:
  pkcs7:
    keysize: 4096
    private_key: /path/to/key/private_key.pkcs7.pem
    public_key: /path/to/key/public_key.pkcs7.pem
```


## Puppet library plugins

Puppet library plugins install Puppet libraries on target nodes when a plan calls `apply_prep`.


## Configuring plugins

Some plugins use configuration data from the `plugins` section of a configuration file. Each plugin has its own configuration section. For example, the following configuration file will change where the `pkcs7` plugin looks for the private key.

```yaml
plugins:
  pkcs7:
    private-key: ~/bolt_private_key.pem
```

Plugin configuration can be derived from other plugins using `_plugin` references. For example, you can configure the `vault` plugin to use the `prompt` plugin to prompt for a password.

> **Note:** Plugins can only be used in a configuration file to configure other plugins under the `plugins` and `plugin_hooks` fields.

```yaml
plugins:
  vault:
    auth:
      method: userpass
      user: Developer
      password:
        _plugin: prompt
        message: Enter your Vault password
```
