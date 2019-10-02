# Using Plugins

Plugins either ship with bolt or are installed as puppet modules with the same
name as the plugin. The plugin framework is based on a set of plugin hooks that
are implemented by plugin authors and called by bolt.

A plugin hook provides an API for a specific use case. A plugin can implement
multiple hooks. The way in which a plugin is used varies depending on the type
of hook used.

## Reference Plugins

Reference plugins are used to fetch data from an external source into a static
data object. For example they can be used to discover inventory targets from
AWS or PuppetDB in an inventory file or look up a password from Vault in
`bolt.yaml`. To use a reference add an object with a `_plugin` key where you
want the resolved value to be used. The `_plugin` value should be the name of
the plugin to use and the object should contain any plugin specific options
that are required.

Bolt currently supports references in the inventory file at the top level of
the `targets` array and in any location in a `config` object. References are
resolved only as needed which means that `targets` references will be resolved
when the inventory is loaded while `config` references will only be resolved
when a target that uses that config is loaded in a plan.

For example the following inventory will prompt a user for a password the first time
the `example.com` target is used.

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
          message: please enter your ssh password
```

The following example will use the terraform plugin to  populate a `cloud-webs`
group from terraform state.

```
groups:
  - name: cloud-webs
    targets:
      - _plugin: terraform
        dir: /path/to/terraform/project1
        resource_type: google_compute_instance.web
        uri: network_interface.0.access_config.0.nat_ip
```


## Secret plugins

Secret plugins can be used to encrypt and decrypt sensitive values in data. The
`bolt secret encrypt` and `bolt secret decrypt` commands are used to encrypt or
decrypt the data which can be used as a reference in data files.

## Puppet Library plugins

Puppet Library plugins install the necessary puppet libraries on target nodes
when a plan calls `apply_prep`.

## Configuring Plugins

Some plugins use configuration data from the `plugins` section of `bolt.yaml`.
Each plugin has it's own config section. For example the following `bolt.yaml`
will change where the pkcs7 plugin looks for the private key.

```
---
plugins:
  pkcs7:
    private-key: ~/bolt_private_key.pem
```

## Bundled Plugins

Bolt ships with a few plugins out of the box.

## Task

The Task plugin allows a task to be run for a bolt plugin hook. How this task
is run depends on the hook that is called. In most cases the task will run on
the `localhost` target without `inventory.yaml` specific configuration and be
passed the parameters that are configured. The Task plugin will extract the
`value` key and use that as the value of the plugin.


### Reference Hook

The referene hook accepts to options:
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

To use for targets the task `value` must return an array of target object in
the format that the inventory file accepts. When used to refer to a config the
`value` should match the whatever the reference expects. For example
`host-key-check` for ssh must be a boolean, `password` must be a string and
`run-as-command` must be an array of strings. This result would be appropriate
for an entire `ssh` section of config.

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
json.dump({'value': secret}, sys.stdout)
```

## PuppetDB

The PuppetDB plugin supports looking up targets from PuppetDB. It takes a
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

## Terraform

The Terraform plugin supports looking up targets from Terraform state. It
accepts several options:

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

## AWS Inventory

The AWS Inventory plugin supports looking up running AWS EC2 instances. It supports several fields:

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
      - _plugin: aws_inventory
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

## Prompt plugin

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

## pkcs7 plugin

This plugin allows config values to be stored in encrypted in the inventory
file and decrypted only as needed.

`_plugin`: The value of `_plugin` must be `pkcs7`
`encrypted_value`: The encrypted value. Generate encrypted values with `bolt secret encrypt <plaintext>`

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

Before using the pkcs7 plugin you need to create encryption keys. You can
create these keys automatically with `bolt secret createkeys` or reuse existing
hiera-eyaml pkcs7 keys with bolt secret. You can then encrypt values with `bolt
secret encrypt <plaintext>` command and copy the result into your inventory
file. If you need to inspect an encrypted value from the inventory you can
decrypt it with `bolt secret decrypt <encrypted_value>`.

### Configuration

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

## Vault plugin


This plugin allows config values to be set by accessing secrets from a Key/Value engine on a Vault server. It supports several fields:

- `_plugin`: The value of `_plugin` must be `vault`
- `server_url`: The URL of the Vault server (optional, defaults to `ENV['VAULT_ADDR']`)
- `auth`: The method for authorizing with the Vault server and any necessary parameters (optional, defaults to `ENV['VAULT_TOKEN']`)
- `path`: The path to the secrets engine (required)
- `field`: The specific secret being used (optional, defaults to a Ruby hash of all secrets at the `path`)
- `version`: The version of the K/V engine (optional, defaults to 1)
- `cacert`: Path to the CA certificate (required when using `https`, defaults to `ENV['VAULT_CACERT']`)


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
- `cacert`
- `auth`


```
---
plugins:
  vault:
    server_url: https://127.0.0.1:8200
    cacert: /path/to/cert
    auth:
      method: token
      token: xxxxx-xxxxx
```
