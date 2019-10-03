# Inventory file version 2

Version 2 of the inventory file is experimental and might experience breaking changes in future releases.

## Migrating to version 2

Version 2 of the inventory file changes some terms and syntax. To convert to version 2, you must make these changes.

**`version: 2`**

The default version for inventory files is version 1. In order to have Bolt treat your inventory file as a version 2 inventory, specify `version: 2` at the top level.

**`nodes` =\> `targets`**

In order to standardize terminology across Bolt and capture the breadth of possible targets, such as web services, version 2 of the inventory file uses the `targets` section of a group to specify its members instead of `nodes`.

**`name` =\> `uri`**

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

The `Target.new` method may also be used to instantiate a `Target`:
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
In the `new_target_alternate` plan a new `Target` is created from a hash and added to the `all` group in inventory. **Note**: If a `Target` with name `new_target` had already existed in inventory, that `Target` would be destroyed and the new `Target` would take its place.

## `TargetSpec` parameters in plans

When a plan parameter has the type `TargetSpec`, Bolt will ensure that values for that parameter are included in inventory. 

For example:
```
plan auto_add(TargetSpec $nodes) {
  return get_targets('all')
}
```
The `auto_add` plan returns all of the targets in the `all` group, if the value of `$nodes` resolves to a `String` that does not match a `Target` name, a group name, a `Target` alias or a target regex, a new `Target` is created and added to the `all` group. 

## `Target` reference

A target object can be instantiated with `Target.new` from a plan with either a `String` representing the `Target` `name` and `uri` or a hash with the following structure:

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
In the `target_example` plan `target_1` is created from a URI, `target_2` is created from a hash. 

**Note:** In the case where a `Target` is instantiated with only a `String` `uri` value, consider using `get_target` which will create a target without having to use the `Target.new` syntax. 

When a target is instantiated from a `uri` and no `name` is provided, the `name` is set to the `uri`. The `Target` also gets assigned a `safe_name` which is the `uri` with the password redacted. 

For example:
```
plan safe_name(){
  $safe = get_target('ssh://user:secret@1.2.3.4:2222')
  out::message($safe.safe_name)
}
```
In the `safe_name` plan a new target with `name` and `uri` is created and added to inventory. The plan will print `ssh://urser@1.2.3.4:2222` as the safe name. 

It is important to note that the `safe_name` is only different from the `name` in the case where the `Target` is constructed from a URI and there is no `name` specified. When a `name` is supplied, the `safe_name` will always equal the `name`. 

For example:
```
plan unsafe_name(){
  $unsafe = Target.new('name' => 'ssh://user:secret@1.2.3.4:2222')
  out::message($unsafe.safe_name)
}
```
In the `unsafe_name` plan, a `Target` is instantiated with the `name` set to the full `uri` that contains the sensitive password and thus the `safe_name` contains the password. 

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

### Plugins and dynamic inventory

Inventory plugins can be used to dynamically load information into the inventory file.

To use a plugin, replace a static value in the inventory file with an Object containing a `_plugin` key and any required plugin- specific options. The location where you do this replacement determines how the plugin behaves. Currently, plugins are only supported for `inventory_targets`, in the `targets` section of inventory, and `inventory_config`, in the config section of inventory. Most plugins only work in one location or the other.

#### Target plugins

To use an`inventory_target` plugin, replace an item in the `targets` array with a plugin object.

```yaml
targets:
 - _plugin: my_plugin
   plugin_specific_option: exampleoption
            
```

Use the following optional plugins for targets:

-   `aws_inventory` - load running AWS EC2 instances to populate the targets.
-   `puppetdb` - query PuppetDB to populate the targets.
-   `terraform` - load a Terraform state file to populate the targets.

**Config plugins**

Use config plugins inside the `config` section of a target or group to look up a value. Config lookup plugins that return a value with a `_plugin` are not reevaluated.

```yaml
config: 
  transport:
   _plugin: my_plugin
   plugin_specific_option: exampleoption
            
```

These plugins can be used for `config`:

-   `prompt` - prompts a user for a configuration value.
-   `pkcs7` - decrypts a pkcs7 encrypted value from the inventory file.

**Task**

The Task plugin runs a task on `localhost` to look up configuration information or target lists for the inventory.

For both use cases, the plugin accepts two keys:

-   `task` - the task to run.
-   `parameters` - the parameters to pass to the task.

For example, the following runs the `my_json_file::targets` task to look up targets and the `my_db::secret_lookup` task to look up the SSH password.

```yaml
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

**Inventory config tasks**

To look up configuration information for the inventory, return a `config` key in the task result containing the data that will be used in place where the plugin entry is. The value of config can be any type of data that is appropriate for the specific location in config. For example `host-key-check` for SSH must be a Boolean, `password` must be a string, and `run-as-command` must be an array of strings. This result is appropriate for an entire `ssh` section of config.

```json
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
json.dump({'value': secret}, sys.stdout)
```

**Inventory target tasks**

To look up a list of targets for inventory, return a hash or JSON object that includes a `targets` key with an `array` value from task. Each item in this list should be a Target JSON object matching the `Object` format you use in a `targets` section of the inventory file. Bare string targets are not valid.

This task reads in a JSON file and looks up a value.

```python
#!/usr/bin/env python
import json, sys

params = json.load(sys.stdin)
with open(params['file']) as fh:
  data = json.load(fh)
targets = data[params['environment']][params['app']]
json.dump({'value': targets}, sys.stdout)

```

**Install library tasks**

To install a library on the remote system \(the Puppet agent\). Bolt executes this task when a plan calls `apply_prep()` to provision targets.

You can use an existing task for this, such as `puppet_agent::install` or `bootstrap::linux`:

**`bolt.yaml`**

```yaml
plugin_hooks:
  puppet_library:
    plugin: task
    task: puppet_agent::install
    parameters:
      version: 6.2.0
      yum_source: yum.customurl.net
```

**`bolt.yaml`**

```yaml
plugin_hooks:
  puppet_library:
    plugin: task
    task: bootstrap::linux
    parameters:
      master: mymaster.fqdn
      environment: dev
```

In the example below, the task installs the Puppet agent from a custom repository, sets some config, and starts the agent service:

**`inventory.yaml`**

```yaml
version: 2
groups:
  - name: custom_nodes
    targets:
      - foo
      - bar
    plugin_hooks:
      puppet_library:
        plugin: task
        task: custom_agent::install
        parameters:
          version: 6.2.0
```

**`site-modules/custom\_agent/tasks/install.sh`**

```shell script
#!/bin/sh
apt-get -y install wget
wget http://my.custom.repo.net/puppetlabs-release-precise.deb
dpkg -i puppetlabs-release-precise.deb
apt-get update
apt-get -y install puppet

echo "[main]
ssldir=/var/lib/puppet/ssl
factpath=\$vardir/lib/facter
server=$MASTER_HOSTNAME

[master]
ssl_client_header = SSL_CLIENT_S_DN
ssl_client_verify_header = SSL_CLIENT_VERIFY" > /etc/puppet/puppet.conf

puppet resource service puppet ensure=running enable=true
```

**PuppetDB**

The PuppetDB plugin supports looking up target objects from PuppetDB. It takes a `query` field, which is either a string containing a [PuppetDB AST](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html) query. The query is used to determine which targets are included in the group. If `name` or `uri` is not specified with a fact lookup, then the [certname](https://puppet.com/docs/puppet/latest/lang_facts_and_builtin_vars.html#trusted-facts) for each target in the query result will be used as the `uri` for the new target.

```yaml
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

Make sure you've [configured PuppetDB](bolt_connect_puppetdb.md).

If target-specific configuration is required, the PuppetDB plugin can be used to look up configuration values for the `name`, `uri`, and `config` inventory options for each target. The fact lookup values can be either `certname`, to reference the [certname](https://puppet.com/docs/puppet/latest/lang_facts_and_builtin_vars.html#trusted-facts) of the target, or a [PQL dot notation](https://puppet.com/docs/puppetdb/latest/api/query/v4/ast.html#dot-notation) facts string, such as `facts.os.family`, to reference fact value. Dot notation is required for both structured and unstructured facts.

**Note:** If the `name` or `uri` values are set to a lookup, the PuppetDB plugin will **not** set the `uri` to the certname of the target.

For example, to set the user to be the user from the [identity fact](https://puppet.com/docs/facter/latest/core_facts.html#identity):

```yaml
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

```yaml
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

**Terraform**

The Terraform plugin supports looking up target objects from a Terraform state file. It accepts several fields:

-   `dir`: The directory containing either a local Terraform state file or Terraform configuration to read remote state from.
-   `resource_type`: The Terraform resources to match, as a regular expression.
-   `uri`: \(Optional\) The property of the Terraform resource to use as the target URI.
-   `statefile`: \(Optional\) The name of the local Terraform state file to load, relative to `dir` \(defaults to `terraform.tfstate)`.
-   `name`: \(Optional\) The property of the Terraform resource to use as the target name.
-   `config`: A Bolt config map where each value is the Terraform property to use for that config setting.
-   `backend`: \(Optional\) The type of backend to load the state form, either `remote` or `local` \(defaults to `local`\).

Either `uri` or `name` is required. If only `uri` is set, the value of `uri` is used as the `name`.

```yaml
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

Multiple resources with the same name are identified as <resource\>.0, <resource\>.1, etc.

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

**AWS inventory**

The AWS inventory plugin looks up running AWS EC2 instances. It supports several fields:

-   `profile`: the [named profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html) to use when loading from AWS `config` and `credentials` files \(optional, defaults to `default`\)
-   `region`: the region to look up EC2 instances from
-   `name`: the [EC2 instance attribute](https://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Instance.html) to use as the target name \(optional\)
-   `uri`: the [EC2 instance attribute](https://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Instance.html) to use as the target URI. \(optional\)
-   `filters`: the [filter request parameters](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DescribeInstances.html) to filter the EC2 instances. Filters are name-values pairs, where the name is a request parameter and the values are an array of values to filter by. \(optional\)
-   `config`: a Bolt config map where the value for each config setting is an EC2 instance attribute

Either`uri` or `name` is required. If only `uri` is set, the value of `uri` is used as the `name`.

```yaml
groups:
  - name: aws
    targets:
      - _plugin: aws_inventory
        profile: user1
        region: us-west-1
        name: <PUBLIC_DNS_NAME>
        uri: <PUBLIC_IP_ADDRESS>
        filters:
          - name: tag:Owner
            values: [Devs]
          - name: instance-type
            values: [t2.micro, c5.large]
        config:
          ssh:
            host: <PUBLIC_DNS_NAME>
    config:
      ssh:
        user: ec2-user
        private-key: ~/.aws/private-key.pem
        host-key-check: false
```

Accessing EC2 instances requires you to specify a region and valid credentials. Bolt searches the following locations in order until a value is found:

**Region**

-   `region: <region>` in the inventory file
-   `ENV['AWS_REGION']`
-   `credentials: <FILEPATH>` in the config file
-   `~/.aws/credentials`

**Credentials**

-   `ENV['AWS_ACCESS_KEY_ID']` and `ENV['AWS_SECRET_ACCESS_KEY']`
-   `credentials: <FILEPATH>` in the config file
-   `~/.aws/credentials`

If the region or credentials are located in a shared credentials file, you can set a `profile` in the inventory file to choose which set of credentials to use. For example, if the inventory file were set to `profile: user1`, the second set of credentials would be used:

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

To use AWS credential files stored in a non-standard location \(anywhere other than `~/.aws/credentials`\), specify the location in the Bolt config file:

```yaml
plugins:
  aws_inventory:
    credentials: ~/alternate_path/credentials
```

**Prompt plugin**

The `prompt` plugin can be used to allow users to interactively enter sensitive configuration information on the CLI instead of storing that data in the inventory file. Data is looked up only when the value is needed for the target and once the value has been stored, it is re-used for the rest of the run. The `prompt` plugin can be used only when nested under `config`. The prompt plugin can be used by replacing the config value with a hash that has the following keys:

-   `_plugin`: The value of `_plugin` must be `prompt`
-   `message`: The value of `message` must be the text to show when prompting the user on the CLI

```yaml
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

**pkcs7 plugin**

This plugin allows config values to be stored in encrypted in the inventory file and decrypted only as needed.

- `_plugin`: The value of `_plugin` must be `pkcs7`
- `encrypted_value`: The encrypted value. Generate encrypted values with `bolt secret encrypt <plaintext>`

```yaml
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

Before using the pkcs7 plugin you need to create encryption keys. You can create these keys automatically with `bolt secret createkeys` or reuse existing hiera-eyaml pkcs7 keys with `bolt secret`. You can then encrypt values with the `bolt secret encrypt <plaintext>` command and copy the result into your inventory file. If you need to inspect an encrypted value from the inventory, you can decrypt it with `bolt secret decrypt <encrypted_value>`.

**Configuration**

By default, keys are stored in the `keys` directory of the Bolt project repo. If you're sharing your project directory, you can move the private key outside the project directory by configuring the key location in `bolt.yaml`

```yaml
plugins:
  pkcs7:
    private-key: ~/bolt_private_key.pem
```

-   `keysize`: They size of the key to generate with `bolt secret createkeys`. The default is `2048`
-   `private-key`: The path to the private key file. The default is `keys/private_key.pkcs7.pem`
-   `public-key`: The path to the public key file. The default is `keys/public_key.pkcs7.pem`

**Vault plugin**

This plugin allows configuration values to be set by accessing secrets from a key/value engine on a Vault server. It supports several fields:

-   `_plugin`: The value of `_plugin` must be `vault`
-   `server_url`: The URL of the Vault server \(optional, defaults to `ENV['VAULT_ADDR']`\)
-   `auth`: The method for authorizing with the Vault server and any necessary parameters \(optional, defaults to `ENV['VAULT_TOKEN']`\)
-   `path`: The path to the secrets engine \(required\)
-   `field`: The specific secret being used \(optional, defaults to a Ruby hash of all secrets at `path`\)
-   `version`: The version of the key/value engine \(optional, defaults to 1\)
-   `cacert`: The path to the CA certificate \(required when using `https`, defaults to `ENV['VAULT_CACERT']`\)

**Authentication methods**

Vault requires a token to assign an identity and a set of policies to a user before accessing secrets. The Vault plugin offers two authentication methods:

-   **Token-based**. Authenticate using a token. This method requires the following fields:
    -   `method`: The value of `method` must be `token`
    -   `token`: The token to authenticate with
-   **Username- and password-based**. Request a token by logging into the Vault server with a username and password. This method requires the following fields:
    -   `method`: The value of `method` must be `userpass`
    -   `user`: The username
    -   `pass`: The password

You can add any Vault plugin field to the inventory configuration. For example, this is how you would access the `private-key` secret on a Vault key-value engine \(version 2\) mounted at `secrets/bolt`:

```yaml
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

You can also set configuration values in the config file \(typically `bolt.yaml`\) under the `plugins` field. If a field is set in both the inventory file and the config file, Bolt uses the value set in the inventory file. The available fields for the config file:

-   `server_url`
-   `cacert`
-   `auth`

```yaml
plugins:
  vault:
    server_url: https://127.0.0.1:8200
    cacert: /path/to/cert
    auth:
      method: token
      token: <XXXX-XXXX>
```

## Inventory config

You can set transport configuration only in the inventory file. This means using a top level `transport` value to assign a transport to the target and all values in the section named for the transport. You can set config on targets or groups in the inventory file. Bolt performs a depth first search of targets, followed by a search of groups, and uses the first value it finds. Nested hashes are merged.

This inventory file example defines two top-level groups: `ssh_targets` and `win_targets`. The `ssh_targets` group contains two other groups: `webservers` and `memcached`. Five targets are configured to use ssh transport and four other nodes to use WinRM transport.

```yaml
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

``` yaml
targets:
  - uri: linux1.example.com
    config:
      ssh:
        user: me
```

### Provide an alias to a target

The inventory can be used to create aliases to refer to a target. Aliases can be useful to refer to nodes with long or complicated names, like db.uswest.acme.example.com, or for targets that include protocol or port for uniqueness, such as `127.0.0.1:2222` and `127.0.0.1:2223`. Aliases can also be useful when generating targets in a dynamic environment to give generated targets stable names to refer to.

An alias can be a single name or list of names. Each alias must match the regex `/[a-zA-Z]\w+/`. When using Bolt, you may refer to a target by its alias anywhere the target name would be applicable, such as the `--targets` command line argument or a `TargetSpec`.

``` yaml
targets:
  - uri: linux1.example.com
    alias: linux1
    config:
      ssh:
        port: 2222
```

Aliases must be unique across the entire inventory. You can use the same alias multiple places, but they must all refer to the same target. Alias names must not match any group or target names used in the inventory.

A list of targets may refer to a target by its alias, for example:

``` yaml
targets:
  - uri: 192.168.110.10
    alias: linux1
groups:
  - name: group1
    targets:
      - linux1
```

## Inventory facts, vars, and features

In addition to config values you can store information relating to `facts`, `vars` and `features` for targets in the inventory. `facts` represent observed information about the target including what can be collected by Facter. `vars` contain arbitrary data that may be passed to run\\\_\\\* functions or used for logic in plans. `features` represent capabilities of the target that can be used to select a specific task implementation.

```yaml
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

-   **Config:** A config is a map that contains transport specific configuration options.
-   **Group:** A group is a map that requires a `name` and can contain any of the following:
    -   `targets` : `Array[Node]`
    -   `groups` : Groups object
    -   `config` : Config object
    -   `facts` : Facts object
    -   `vars` : Vars object
    -   `features` : `Array[Feature]`

    A group name must match the regular expression values `/[a-zA-Z]\w+/`. These are the same values used for environments.

    A group may contain other groups. Any nodes in the nested groups will also be in the parent group. The configuration of nested groups will override the parent group.

-   **Groups:** An array of group objects.
-   **Facts:** A map of fact names and values. Values may include arrays or nested maps.
-   **Feature:** A string describing a feature of the target.
-   **Target:** A target can be just the string of its target URI or a map that requires a name key and can contain a config. For example, a target block can contain any of the following:
    ```yaml
    "host1.example.com"
    ```
    ```yaml
    uri: "host1.example.com"
    ```
    ```yaml
    uri: "host1.example.com"
    config:
      transport: "ssh"
    ```

    If the target entry is a map, it may contain any of the following:
    -   `alias`: `String` or `Array[String]`
    -   `config`: Config object
    -   `facts`: Facts object
    -   `vars`: Vars object
    -   `features`: `Array[Feature]`

-   **Target name:** The name used to refer to a target.
-   **Targets:** An array of target objects.
-   **Vars**: A map of value names and values. Values may include arrays or nested maps.

## File format

The inventory file is a yaml file that contains a single group. This group can be referred to as "all". In addition to the normal group fields, the top level has an inventory file version key that defaults to 1.

## Precedence

If a target specifies a `uri` or is created from a URI string any URI-based configuration information like host, transport or port will override config values even those defined in the same block. For config values, the first value found for a target is used. Node values take precedence over group values and are searched first. Values are searched for in a depth first order. The first item in an array is searched first.

Configure transport for targets.

```yaml
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

```yaml
targets:
  - uri: host1.example.com
    config:
      ssh:
          user: me
          run-as: root
```

## Remote targets

Configure a remote target. When using the remote transport, the protocol of the target name does not have to map to the transport if you set the transport config option. This is useful if the target is an http API, for example:

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

[certname](https://puppet.com/docs/puppet/latest/lang_facts_and_builtin_vars.html#trusted-facts)
