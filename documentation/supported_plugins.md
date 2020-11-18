# Supported plugins

The following plugins are supported and maintained by Bolt. Supported plugins
are shipped with Bolt packages and do not need to be installed separately.

## Reference plugins

Reference plugins fetch data from an external source and store it in a static
data object. You can use reference plugins in configuration files, inventory
files, and plans.

| Plugin | Description | Documentation |
| --- | --- | --- |
| `aws_inventory` | Generate targets from Amazon Web Services EC2 instances. | [aws_inventory](https://forge.puppet.com/puppetlabs/aws_inventory) |
| `azure_inventory` | Generate targets from Azure VMs and VM scale sets. | [azure_inventory](https://forge.puppet.com/puppetlabs/azure_inventory) |
| `env_var` | Read values stored in environment variables. | [env_var](#env-var) |
| `gcloud_inventory` | Generate targets from Google Cloud compute engine instances. | [gcloud_inventory](https://forge.puppet.com/puppetlabs/gcloud_inventory) |
| `pkcs7` | Decrypt ciphertext. | [pkcs7](https://forge.puppet.com/puppetlabs/pkcs7) |
| `prompt` | Prompt the user for a sensitive value. | [prompt](#prompt) |
| `puppetdb` | Query PuppetDB for a group of targets. | [puppetdb](#puppetdb) |
| `task` | Run a task as a plugin. | [task](#task) |
| `terraform` | Generate targets from local and remote Terraform state files. | [terraform](https://forge.puppet.com/puppetlabs/terraform) |
| `vault` | Access secrets from a Key/Value engine on a Hashicorp Vault server. | [vault](https://forge.puppet.com/puppetlabs/vault) |
| `yaml` | Compose multiple YAML files into a single file. | [yaml](#yaml) |

## Secret plugins

Use secret plugins to create keys for encryption and decryption, to encrypt
plaintext, or to decrypt ciphertext. Secret plugins are used by Bolt's `secret`
command.

| Plugin | Description | Documentation |
| --- | --- | --- |
| `pkcs7` | Generate key pairs, encrypt plaintext, and decrypt ciphertext. | [pkcs7](https://forge.puppet.com/puppetlabs/pkcs7) |

## Puppet library plugins

Puppet library plugins ensure that the Puppet library is installed on a target
when a plan calls the `apply_prep` function.

| Plugin | Description | Documentation |
| --- | --- | --- |
| `puppet_agent` | Install Puppet libraries on target nodes when a plan calls `apply_prep`. | [puppet_agent](https://forge.puppet.com/puppetlabs/puppet_agent) |

## Built-in plugins

The following plugins are built into Bolt and are not available in modules.

### `env_var`

The `env_var` plugin allows users to read values stored in environment variables
and load them into an inventory or configuration file.

#### Parameters

The following parameters are available to the `env_var` plugin:

| Parameter | Description | Type | Default |
| --- | ----------- | ---- | ------- |
| `var` | **Required.** The name of the environment variable to read from. | `String` | None |
| `default` | A value to use if the environment variable `var` isn't set. | `String` | None |
| `optional` | Unless `true`, `env_var` raises an error when the environment variable `var` does not exist.  When `optional` is `true` and `var` does not exist, env_var returns `nil`. | `Boolean` | `false` |

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

### `prompt`

The `prompt` plugin allows users to interactively enter sensitive configuration
information on the CLI instead of storing that data in the inventory file. Data
is looked up when the value is needed for the target. Once the value has been
stored, it is re-used for the rest of the Bolt run.

#### Parameters

The following parameter is available to the `prompt` plugin:

| Parameter | Description | Type | Default |
| --- | --- | --- | --- |
| `message` | **Required.** The text to show when prompting the user. | `String` | None |

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

### `puppetdb`

The `puppetdb` plugin queries PuppetDB for a group of targets. 

If you require target-specific configuration, you can use the `puppetdb` plugin
to look up configuration values for the `alias`, `config`, `facts`, `features`,
`name`, `uri` and `vars` inventory options for each target. Set these values in
the `target_mapping` field. The fact look up values can be either `certname` to
reference the `[certname]` of the target, or a [PQL dot
notation](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html#dot-notation)
facts string such as `facts.os.family` to reference a fact value. Dot notation
is required for both structured and unstructured facts.

#### Parameters

The following parameters are available to the `puppetdb` plugin:

| Parameter | Description | Type | Default |
| --- | ----------- | ---- | ------- |
| `query` | **Required.** A string containing a [PQL query](https://puppet.com/docs/puppetdb/latest/api/query/v4/pql.html) or an array containing a [PuppetDB AST format query](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html). | `String` | None |
| `target_mapping` | **Required.** A hash of target attributes (`name`, `uri`, `config`) to populate with fact lookup values. | `Hash` | None |

> **Note:** If neither `name` nor `uri` is specified in `target_mapping`, then
> `uri` is set to `certname`.

#### Available fact paths

The following values/patterns are available to use for looking up facts in the
`target_mapping` field:

| Key | Description |
| --- | ----------- |
| `certname` | The certname of the node returned from PuppetDB. This is short hand for doing: `facts.trusted.certname`. |
| `facts.*` | [PQL dot notation](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html#dot-notation) facts string such as `facts.os.family` to reference fact value. Dot notation is required for both structured and unstructured facts. |

#### Example usage

Look up targets with the fact `osfamily: RedHat` and the following configuration
values:
 * The alias with the fact `hostname`
 * The name with the fact `certname`
 * A target fact called `custom_fact` with the `custom_fact` from PuppetDB
 * A feature from the fact `custom_feature`
 * The SSH hostname with the fact `networking.interfaces.en0.ipaddress`
 * The puppetversion variable from the fact `puppetversion`

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
          host: facts.networking.interfaces.en0.ipaddress
      vars:
        puppetversion: facts.puppetversion
```

### `task`

The `task` plugin lets Bolt run a task as a plugin and extracts the `value` key
from the task output to use as the plugin value. Plugin tasks run on the
`localhost` target without access to any configuration defined in an inventory
file, but with access to any parameters that you've configured.

For example, you could run a `task` plugin that collects target names from a
JSON file and interpolates them into a `target` array in your inventory file.

#### Parameters

The following parameters are available to the `task` plugin:

| Key | Description | Type | Default |
| --- | ----------- | ---- | ------- |
| `task` | **Required.** The name of the task to run. | `String` | None |
| `parameters` | The parameters to pass to the task. | `Hash` | None |

#### Example usage

Loading targets with a `my_json_file::targets` task and a password with a
`my_db::secret_lookup` task:

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
