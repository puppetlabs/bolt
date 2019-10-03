# Writing Plugins

Users can define their own plugins in module by adding a `bolt_plugin.json`
file to a module that describes the plugin's configuration and may map specific
hooks to tasks that implement them. In most cases those tasks will run on the
default `localhost` target without any configuration from `inventory.yaml`. The
exception to this is the `puppet_library` hook where the task will be run on
the target that needs the puppet library.

## Configuration

Plugins can use configuration from the `bolt.yaml` file. To allow a plugin to
be configured, add a `config` section to the `bolt_plugin.json` file. This
section is similar to the `parameters` section in task metadata.

```json
{
  "config": {
    "key1": {
      "type": "Optional[String]"
    }
  }
}
```
## Hooks

A plugin can implement hooks as tasks. Bolt will search for tasks in a plugin
module matching the hook name for example `my_plugin::resolve_reference` or
hooks can be mapped to tasks in the `hooks` section of `bolt_plugin.json`. The
`hooks` section is a JSON object where the keys are hooks names and the values
are objects with a `task` key with the name of a task to run. You only have to
specify a hook mapping in the `hooks` section if the task name does match the
hook name.

```json
{
  "hooks": {
    "resolve_reference": {
      "task": "my_module::secret_decrypt"
    }
  }
}
```

In this case the plugin will implement two hooks the `resolve_reference` hook
that is explicitly defined and the `secret_decrypt` hook that is discovered
from the task name.

All task hooks will be passed the metaparameters `_config` that contains the
plugins configuration and `_boltdir` that contains the path to the current
boltdir.

### `resolve_reference` tasks

A `resolve_reference` task will be passed the contents of the `_plugin` object
minus `_plugin` as parameters.

### `validate_resolve_reference` tasks

The `validate_resolve_reference` task can be used to prevalidate the parameters
that will be passed to the `resolve_reference` task so that any validation
errors can be raised during inventory loading rather than in the middle of plan
evaluation. Regardless of whether this hook is specified the parameters will be
tested to make sure they match the `parameters` of the `resolve_reference`
task.

### `secret_decrypt` tasks

A secret decrypt will be passed a single key `encrypted_value`.

### `secret_encrypt` tasks

A `secret_encrypt` task will be passed a single parameter `plaintext_value`.

### `secret_createkeys` tasks

A createkeys task will be passed no parameters other than the metaparameters.
In general it is expected to create the keys based on it's `_config` and the
`_boltdir` metaparams.

### `puppet_library` tasks

A puppet library is used to make sure the puppet library is available on a
target when `apply_prep` is called.
