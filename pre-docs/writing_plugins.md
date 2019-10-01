---
author: Chris Cowell <christopher.w.cowell@gmail.com\>
---

# Writing plugins

Users can write plugins that live within a module.

Include your own plugins within a module by adding a `bolt_plugin.json` file to the top level of that module. This file should describe the plugin's configuration and can optionally map specific hooks to tasks that implement them. In most cases those tasks will run on the default `localhost` target without any configuration from `inventory.yaml`. The only exception is the `puppet_library` hook, where the task will be run on the target that needs the Puppet library.

## Configuration

Plugins can use configuration from the `bolt.yaml` file. To allow a plugin to be configured, add a `config` section to the `bolt_plugin.json` file. This section is similar to the `parameters` section in task metadata.

```
{ 
  "config": {
    "key1": {
      "type": "Optional[String]" 
    } 
  } 
} 
```

## Hooks

A plugin can implement hooks as tasks. Bolt will search for tasks in a plugin module matching the hook name, such as `my_plugin::resolve_reference`. Alternatively, you can map hooks to tasks in the `hooks` section of `bolt_plugin.json`. The `hooks` section is a JSON object where the keys are hook names and the values are objects with a key of `task` and a value containing the name of a task to run. You only have to specify a hook mapping in the `hooks` section if the task name does not match the hook name.

```
{
  "hooks": {
    "resolve_reference": {
      "task": "my_module::secret_decrypt"
    }
  }
}
```

In this case the plugin will implement two hooks: the `resolve_reference` hook that is explicitly defined and the `secret_decrypt` hook that is discovered from the task name. Bolt passes two metaparameters to all task hooks: `_config`, which contains the plugin configuration, and `_boltdir`, which contains the path to the current Boltdir.

**`resolve_reference` tasks**

Bolt passes the contents of the `_plugin` object minus `_plugin` as parameters to the `resolve_reference` task.

**`validate_resolve_reference` tasks**

Use the `validate_resolve_reference` task to pre-validate the parameters that will be passed to the `resolve_reference` task. This lets Bolt raise any validation errors during inventory loading rather than in the middle of plan evaluation. Regardless of whether this hook is specified, Bolt tests the parameters to make sure they match the `parameters` of the `resolve_reference` task.

**`secret_decrypt` tasks**

Bolt passes a single key `encrypted_value` to a secret decrypt task.

**`secret_encrypt` tasks**

Bolt passes a single parameter `plaintext_value` to a `secret_encrypt` task.

**`secret_createkeys` tasks**

Bolt passes no parameters other than the metaparameters to a `createkeys` task. It is expected to create the keys based on its `_config` and the `_boltdir` metaparameter.

**`puppet_library` tasks**

Bolt uses a `puppet_library` plugin to make sure the Puppet library is available on a target when `apply_prep` is called.

