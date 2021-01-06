# Writing plugins

A plugin is a special task that Bolt loads from a module on each run. Before you
write a plugin, get familiar with [writing tasks](writing_tasks.md).

## Supported languages

Bolt runs plugin tasks on the `localhost` target without any configuration from
the inventory file. You can write your plugin in any scripting language, as long
as your workstation can interpret that scripting language.

For Unix-like controllers, you should include a shebang line at the top of the
plugin file to ensure that Bolt executes the plugin with the correct
interpreter.

```python
#!/usr/bin/env python

import json, os, sys

...
```

## Module structure

Package your plugin in a module. A simple module with a plugin named `my_plugin`
looks like this:

```shell
my_plugin/
├── bolt_plugin.json
├── metadata.json
└── tasks
    ├── resolve_reference.py
    └── resolve_reference.json
```

Modules that include a plugin must have a plugin configuration file,
`bolt_plugin.json`, in the module's root directory. Typically, the plugin
configuration file contains an empty JSON object:

```json
{}
```

📖 **Related information**

- [Module structure](module_structure.md)

### Project-level plugins

You can also write plugins at the project level. To write a project-level
plugin, you will first need to [create a Bolt
project](https://puppet.com/docs/bolt/latest/projects.html#create-a-bolt-project).
Project-level plugins are referred to by the project's name, similar to how
module plugins are referred to by the module's name.

A simple project named `my_project` with a plugin looks like this:

```shell
my_project/
├── bolt_plugin.json
├── bolt-project.yaml
├── inventory.yaml
└── tasks
    ├── resolve_reference.py
    └── resolve_reference.json
```

Similar to modules that include plugins, a project that includes plugins must
include a plugin configuration file, `bolt_plugin.json`, in the project
directory. Typically, the plugin configuration file contains an empty JSON
object:

```json
{}
```

## Plugin hooks

There are three types of plugins: reference plugins, secret plugins, and Puppet
library plugins. Each type of plugin has an associated plugin hook. Bolt uses
these hooks to determine how it should load and run the plugin. In most cases,
you only need to know what type of hook to use when naming the plugin task.

To create a plugin that automatically uses a specific plugin hook, give the task
a name matching the name of the hook. For example, to create a plugin named
`read_yaml` that uses the `resolve_reference` hook, your module would look like
this:

```shell
read_yaml/
├── bolt_plugin.json
├── metadata.json
└── tasks
    ├── resolve_reference.py
    └── resolve_reference.json
```

### Reference plugins

Reference plugins fetch data from an external source and store it in a static
data object. For example, you might use a reference plugin to fill in the
password field of a configuration file with the contents of an environment
variable, or to query AWS for a list of targets to populate your inventory file.

There are two plugin hooks associated with reference plugins:

- `resolve_reference`

  This hook is used by the reference plugin itself. Most plugins use this hook.

- `validate_resolve_reference`

  Use this hook to pre-validate the parameters that Bolt will pass to the
  `resolve_reference` plugin. These plugins let Bolt raise any validation
  errors during inventory loading, rather than in the middle of a plan run.
  Regardless of whether your specify this hook, Bolt tests parameters to
  make sure they match the parameters for the `resolve_reference` plugin.

📖 **Related information**

- For an example of a reference plugin, see the built-in [yaml
  plugin](https://github.com/puppetlabs/puppetlabs-yaml/tree/master/tasks).

### Secret plugins

Use a secret plugin to create keys for encryption and decryption, to encrypt
plaintext, or to decrypt ciphertext. You can configure Bolt to use specific
secret plugins when you run the `bolt secret` command.

There are three plugin hooks associated with secret plugins:

- `secret_createkeys`

  Use the `secret_createkeys` hook for plugins that create keys for encryption
  and decryption. Bolt always passes a `force` parameter to plugins using this
  hook. When running the `bolt secret createkeys --force` command or
  `New-BoltSecretKey -Force` cmdlet, the `force` parameter has a value of
  `true`.

- `secret_decrypt`

  Use the `secret_decrypt` hook for plugins that decrypt ciphertext and return
  plaintext. Bolt always passes an `encrypted_value` parameter to plugins using
  this hook. The `encrypted_value` parameter is set when you run the `bolt
  secret decrypt` command or `Unprotect-BoltSecret` cmdlet.

- `secret_encrypt`

  Use the `secret_encrypt` hook for plugins that encrypt plaintext and return
  ciphertext. Bolt always passes a `plaintext_value` parameter to plugins using
  this hook. The `plaintext_value` parameter is set when you run the `bolt
  secret encrypt` command or `Protect-BoltSecret` cmdlet.

📖 **Related information**

- For an example of a secret plugin, see the built-in [pkcs7
  plugin](https://github.com/puppetlabs/puppetlabs-pkcs7/tree/master/tasks).

### Puppet library plugins

Puppet library plugins install Puppet libraries on a target when a plan calls
the `apply_prep` function.

Puppet library plugins behave differently from other types of plugins. While
Bolt runs other types of plugins on `localhost`, Bolt runs Puppet library
plugins on each target that you are running `apply_prep` on. Because of this
behavior, each target you run the plugin on must be able to interpret the
scripting language the plugin uses.

There is a single plugin hook associated with Puppet library plugins:

- `puppet_library`

  Use the `puppet_library` hook for plugins that make sure the Puppet library is
  available on a target.

📖 **Related information**

- For an example of a Puppet library plugin, see the built-in [puppet_agent
  plugin](https://github.com/puppetlabs/puppetlabs-puppet_agent/tree/master/tasks).

## Configuring hooks

The `bolt_plugin.json` file not only indicates to Bolt that the module includes
a plugin, but also allows you to map tasks to specific plugin hooks. Mapping a
task to a plugin hook allows you to give the task any valid name you want while
still having Bolt recognize the task as a plugin. You can also use the
`bolt_plugin.json` file to configure multiple hooks for a single plugin.

For example, if you have a task named `my_module::my_plugin` that you want to
use as a reference plugin, you would add the following to your
`bolt_plugin.json` file:

```json
{
  "hooks": {
    "resolve_reference": {
      "task": "my_module::my_plugin"
    }
  }
}
```

Plugins can also support multiple hooks. For example, you might want to use
a `secret_decrypt` plugin as a `resolve_reference` plugin:

```json
{
  "hooks": {
    "resolve_reference": {
      "task": "pkcs7::secret_decrypt"
    }
  }
}
```

## Plugin input

Plugins can accept structured input. For example, a plugin that retrieves a list
of targets from a service may need credentials to authenticate with the service,
while a plugin that decrypts a value may need a path to a key pair.

Because plugins are written as tasks, you can pass input to a plugin by defining
parameters in the task metadata file and then specifying the parameters when you
use the plugin. A simple plugin that loads a YAML file may include a single
`filepath` parameter in the task metadata:

```json
{
  "description": "Read YAML data from a file.",
  "input_method": "stdin",
  "parameters": {
    "filepath": {
      "type": "String",
      "description": "The path to the YAML file."
    }
  }
}
```

Depending on the `input_method` defined in the task metadata, you can access the
plugin's input in a few different ways.

- `"stdin"`: Read the input parameters from standard input (stdin) and parse as
  JSON.
- `"environment"`: Read the input parameters from environment variables matching
  the parameters' names and prefixed with `PT_`, for example `PT_filepath`.
- `"powershell"`: Read the input parameters from named arguments matching the
  parameters' names

Because the task metadata from the YAML plugin above uses the stdin input
method, the task needs to read parameters from stdin and parse the input as
JSON:

```python
#!/usr/bin/env python
import json, sys, yaml

params = json.load(sys.stdin)
filepath = params['filepath']

...
```

If the task metadata used the environment input method instead of stdin, the
task could read the parameter from the `PT_filepath` environment variable:

```python
#!/usr/bin/env python
import json, os, sys, yaml

filepath = os.environ['PT_filepath']

...
```

### Metaparameters

Like all tasks, plugins receive metaparameters from Bolt by default. These
metaparameters are helpful if your plugin task uses other files or needs to
locate files relative to the Bolt project directory. The following
metaparameters are available:

- `_boltdir`

  The absolute path to the Bolt project directory. This is useful when you need
  to expand a path relative to the Bolt project directory.

- `_installdir`

  The temporary directory that the task is installed to. This is useful when the
  task uses additional files specified in the task metadata.

📖 **Related information**

- [Writing tasks: Using structured input and
  output](writing_tasks.md#using-structured-input-and-output)

## Plugin output

Plugins should return output. The format of the plugin output depends on how you
are using the plugin. For example, a plugin that encrypts a string should return
an encrypted string, while a plugin that looks up a list of targets from a
service should return structured data similar to what would be written in an
inventory file.

As a plugin author, it's important that you consider the use case for your
plugin and the data it is expected to output. For example, you might want to
write a plugin that reads an environment variable and returns the value. Since
this value will be a string, and tasks should return structured output, we can
return an object that includes the value under the `value` key:

```json
{
  "description": "Read the value for an environment variable.",
  "parameters": {
    "variable": {
      "description": "The name of the environment variable to read.",
      "type": "String"
    }
  }
}
```

```python
#!/usr/bin/env python
import json, os, sys

variable = os.environ['PT_variable']
value = os.environ[variable]

json.dump({"value": value}, sys.stdout)
```

The above plugin returns the value of the environment variable under the `value`
key. Bolt automatically parses this object and adds the value wherever the
plugin is used.

Because plugins might return sensitive information, such as passwords, Bolt sets
the log level for plugin task output to `trace`. This prevents Bolt from
accidentally printing sensitive information to the command line or default
debugging log, `bolt-debug.log`. If you need to see a plugin task's output, you
can [set Bolt's log level](logs.md#setting-log-level).

### Returning target data

A common application for plugins is to query an external service for a list of
targets. The output of these plugins must adhere to a specific format, otherwise
Bolt will be unable to create target objects from the data and will raise an
error.

Plugins that return lists of targets should format the data in the same way they
would appear in an inventory file. For example, if an inventory file used a
plugin to retrieve a list of targets:

```yaml
targets:
  _plugin: inventory_plugin
```

And the plugin returned the following structured data:

```json
{
  "value": [
    {
      "uri": "http://win.example.com",
      "name": "windows",
      "config": {
        "transport": "winrm",
        "winrm": {
          "password": "bolt",
          "user": "Administrator"
        }
      }
    },
    {
      "uri": "http://nix.example.com",
      "name": "linux",
      "config": {
        "transport": "ssh",
        "ssh": {
          "private-key": "/path/to/key"
        }
      }
    }
  ]
}
```

Adding the plugin output would result in the following inventory file data:

```yaml
targets:
  - uri: http://win.example.com
    name: windows
    config:
      transport: winrm
      winrm:
        password: bolt
        user: Administrator
  - uri: http://nix.example.com
    name: linux
    config:
      transport: ssh
      ssh:
        private-key: /path/to/key
```

Plugins aren't limited to just returning lists of targets. As long as the data
returned by the plugin is in the correct format for where it is being used, it
is considered valid. For example, you can return inventory groups from a plugin
that include lists of targets and configuration:

```yaml
groups:
  _plugin: inventory_plugin
```

The output from the plugin may look similar to this:

```json
{
  "value": [
    {
      "name": "windows",
      "config": {
        "transport": "winrm"
      },
      "targets": [
        "https://win-1.example.com",
        "https://win-2.example.com"
      ]
    }
  ]
}
```

Which would result in an inventory that looks like this:

```yaml
groups:
  - name: windows
    config:
      transport: winrm
    targets:
      - https://win-1.example.com
      - https://win-2.example.com
```

📖 **Related information**

- [Writing tasks: Using structured input and
  output](writing_tasks.md#using-structured-input-and-output)

## Returning errors

For all but the most simple plugins, it can be helpful to validate input, handle
exceptions, and generally ensure that nothing goes wrong during the execution of
the plugin. If something does go wrong, your plugin should return an error
object, which is the standard way of returning errors from tasks.

Error objects include a single `_error` key, which accepts an object that must
include a `msg` key. For example, a minimal error object may look like this:

```json
{
  "_error": {
    "msg": "Something went horribly, horribly wrong."
  }
}
```

Bolt would parse this error object and raise an error similar to this:

```shell
Error executing plugin example from resolve_reference in example:
Something went horribly, horribly wrong.
```

📖 **Related information**

- [Writing tasks: Returning errors in
  tasks](writing_tasks.md#returning-errors-in-tasks)

## Examples

### Returning a value from an environment variable

The following reference plugin reads a value from an environment variable and
returns it.

_resolve\_reference.json_

```json
{
  "description": "Read the value for an environment variable.",
  "parameters": {
    "variable": {
      "description": "The name of the environment variable to read.",
      "type": "String"
    }
  }
}
```

_resolve\_reference.py_

```python
#!/usr/bin/env python
import json, os, sys

variable = os.environ['PT_variable']

try:
  value = os.environ[variable]
  json.dump({"value": value}, sys.stdout)
except KeyError:
  error = { "_error": { "msg": f'No value for environment variable {variable}' } }
  json.dump(error, sys.stdout)
```
