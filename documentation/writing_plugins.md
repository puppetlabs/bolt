# Writing plugins

Users can write plugins that live within a module.

Include your own plugins within a module by adding a `bolt_plugin.json` file to the top level of that module. This file should describe the plugin's configuration and can optionally map specific hooks to tasks that implement them. In most cases those tasks will run on the default `localhost` target without any configuration from `inventory.yaml`. The only exception is the `puppet_library` hook, where the task will be run on the target that needs the Puppet library.

## Configuration

Plugins can use configuration from the `bolt.yaml` file. To allow a plugin to be configured, add a `parameters`
section to the [task metadata](writing_tasks.md#task-metadata).

```json
{ 
  "parameters": {
    "key1": {
      "type": "Optional[String]" 
    } 
  } 
} 
```

## Hooks

A plugin can implement hooks as tasks. Bolt will search for tasks in a plugin module matching the hook name, such as `my_plugin::resolve_reference`. Alternatively, you can map hooks to tasks in the `hooks` section of `bolt_plugin.json`. The `hooks` section is a JSON object where the keys are hook names and the values are objects with a key of `task` and a value containing the name of a task to run. You only have to specify a hook mapping in the `hooks` section if the task name does not match the hook name.

```json
{
  "hooks": {
    "resolve_reference": {
      "task": "my_module::secret_decrypt"
    }
  }
}
```

In this case the plugin will implement two hooks: the `resolve_reference` hook that is explicitly defined and the `secret_decrypt` hook that is discovered from the task name. Bolt passes two metaparameters to all task hooks: `_config`, which contains the plugin configuration, and `_boltdir`, which contains the path to the current Boltdir.

### `resolve_reference` tasks

Bolt passes the contents of the `_plugin` object minus `_plugin` as parameters to the `resolve_reference` task.

### `validate_resolve_reference` tasks

Use the `validate_resolve_reference` task to pre-validate the parameters that will be passed to the `resolve_reference` task. This lets Bolt raise any validation errors during inventory loading rather than in the middle of plan evaluation. Regardless of whether this hook is specified, Bolt tests the parameters to make sure they match the `parameters` of the `resolve_reference` task.

### `secret_decrypt` tasks

Bolt passes a single paramater `encrypted_value` to a `secret_decrypt` task.

### `secret_encrypt` tasks

Bolt passes a single parameter `plaintext_value` to a `secret_encrypt` task.

### `secret_createkeys` tasks

Bolt passes a single parameter `force` to a `secret_createkeys` task. When running the `bolt secret createkeys`
command, the `--force` option can be used to set the `force` parameter's value to `true`.

### `puppet_library` tasks

Bolt uses a `puppet_library` plugin to make sure the Puppet library is available on a target when `apply_prep` is called.

## Example
The simplest example of a plugin is the [YAML plugin](https://github.com/puppetlabs/puppetlabs-yaml). The `resolve_reference` task simply loads YAML from a file and returns the data under the `value` key in a hash.

```ruby

#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../ruby_task_helper/files/task_helper.rb"
require 'yaml'

class YAMLReference < TaskHelper
  def task(**opts)
    path = opts[:filepath]
    boltdir = opts[:_boltdir]
    full_path = if boltdir
                  File.expand_path(path, boltdir)
                else
                  File.expand_path(path)
                end
    data = YAML.safe_load(File.read(full_path))
    { value: data }
  end
end

if $PROGRAM_NAME == __FILE__
  YAMLReference.run
end
```
This task can, for example, be used to organize an inventory into multiple files. When the `_plugin` reference is encountered in the inventoryfile, the `filepath` is passed to the `yaml::resolve_reference` task and the data is read and injected into the inventory hierarchy.

```yaml
---
# inventory.yaml
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