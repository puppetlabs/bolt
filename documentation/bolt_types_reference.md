# Bolt data types

This page lists custom data types used in Bolt plans and their functions.

## `ApplyResult`

An [apply action](applying_manifest_blocks.md#return-value-of-apply-action)
returns an `ApplyResult`. An `ApplyResult` is part of a `ResultSet` object and
contains information about the apply action. 

You can access `ApplyResult` functions with dot notation, using the syntax:
`$apply_result.function`.

The following functions are available to `ApplyResult` objects. 

| Function | Type returned | Description |
|---|---|---|
| `action` | `String` | The action performed. `$apply_result.action` always returns the string `apply`. |
| `error` | `Error` | An object constructed from the `_error` field of the result's value. |
| `message` | `String` | The `_output` field of the result's value. |
| `ok` | `Boolean` | Whether the result was successful. |
| `report` | `Hash` | The Puppet report from the apply action. |
| `target` | `Target` | The target the result is from. |
| `to_data` | `Hash` | A serialized representation of `ApplyResult`. |

## `ResourceInstance`

`ResourceInstance` objects are used to store the observed and desired state of a
target's resource and to track events for the resource. These objects do not
modify or interact with a target's resources.

> 🧪 The `ResourceInstance` data type is experimental and might change in a future
  release. You can learn more about this data type and how to use it in the
  [experimental features
  documentation](experimental_features.md#resourceinstance-data-type).

You can access `ResourceInstance` functions with dot notation, using the syntax:
`$resource.function`.

The following functions are available to `ResourceInstance` objects.

| Function | Type returned | Description |
|---|---|---|
| `[]` | `Data` | Accesses the `state` hash directly and returns the value for the specified attribute. This function does not use dot notation. Call the function directly on the `ResourceInstance`. For example, `$resource['ensure']`. |
| `add_event` | `Array[Hash]` | Add an event for the resource. |
| `desired_state` | `Hash` | [Attributes](https://puppet.com/docs/puppet/latest/lang_resources.html#attributes) describing the desired state of the resource. |
| `events` | `Array[Hash]` | Events for the resource. |
| `overwrite_desired_state` | `Hash` | Overwrites the desired state of the resource. |
| `overwrite_state` | `Hash` | Overwrites the observed state of the resource. |
| `reference` | `String` | The resource's reference string, e.g. `File[/etc/puppetlabs]` |
| `set_desired_state` | `Hash` | Sets attributes describing the desired state of the resource. Performs a shallow merge with existing desired state. |
| `set_state` | `Hash` | Sets attributes describing the observed state of the resource. Performs a shallow merge with existing state. |
| `state` | `Hash` | [Attributes](https://puppet.com/docs/puppet/latest/lang_resources.html#attributes) describing the observed state of the resource. |
| `target` | `Target` | The resource's target. |
| `title` | `String` | The [resource title](https://puppet.com/docs/puppet/latest/lang_resources.html#title).
| `type` | `String` | The [resource type](https://puppet.com/docs/puppet/latest/lang_resources.html#resource-types). |

## `Result`

For each target that you execute an action on, Bolt returns a `Result` object
and adds the `Result` to a `ResultSet` object. A `Result` object contains
information about the action you executed on the target.

You can access `Result` functions with dot notation, using the syntax:
`$result.function`.

The following functions are available to `Result` objects.

| Function | Type returned | Description |
|---|---|---|
| `[]` | `Data` | Accesses the value hash directly and returns the value for the key. This function does not use dot notation. Call the function directly on the `Result`. For example, `$result[key]`. |
| `action` | `String` | The type of result. For example, `task` or `command`. |
| `error` | `Error` | An object constructed from the `_error` field of the result's value. |
| `message` | `String` | The `_output` field of the result's value. |
| `sensitive` | `Sensitive` | The `_sensitive` field of the result's value, wrapped in a `Sensitive` object. Call `unwrap()` to extract the value. |
| `ok` | `Boolean` | Whether the result was successful. |
| `status` | `String` | Either `success` if the result was successful or `failure`. |
| `target` | `Target` | The target the result is from. |
| `to_data` | `Hash` | A serialized representation of `Result`. |
| `value` | `Hash` | The output or return of executing on the target. |

## `ResultSet`

For each target that you execute an action on, Bolt returns a `Result` object
and adds the `Result` to a `ResultSet` object. In the case of [apply
actions](applying_manifest_blocks.md), Bolt returns a `ResultSet` with one or
more `ApplyResult` objects.

You can access `ResultSet` functions with dot notation, using the syntax:
`$result_set.function`.

The following functions are available to `ResultSet` objects:

| Function | Parameters (if applicable) | Type returned | Description |
|---|---|---|---|
| `[]` || `Variant[Result, ApplyResult, Array[Variant[Result, ApplyResult]]]` | The accessed results. This function does not use dot notation. Call the function directly on the `Result`. For example, `$result_set[0]`, `$result_set[0, 2]`. |
| `count` || `Integer` | The number of results in the set. |
| `empty` || `Boolean` | Whether the set is empty. |
| `error_set` || `ResultSet` | The set of failing results. |
| `filter_set(block)` | `block` | `ResultSet` | Filters a set of results by `block`. |
| `find(String $target_name)` | `String $target_name` | `Variant[Result, ApplyResult]` | Retrieves a result for a specific target. |
| `first` || `Variant[Result, ApplyResult]` | The first result in the set. Useful for unwrapping single results. |
| `names` || `Array[String]` | The names of all targets that have results in the set. |
| `ok` || `Boolean` | Whether all results were successful. Equivalent to `$result_set.error_set.empty`. |
| `ok_set` || `ResultSet` | The set of successful results. |
| `results` || `Array[Variant[Result, ApplyResult]]` | All results in the set. |
| `targets` || `Array[Target]` | The list of targets that have results in the set. |
| `to_data` || `Array[Hash` | An array of serialized representations of each result in the set. |

## `Target`

The `Target` object represents a target and its specific connection options.

You can access `Target` functions using dot notation, using the syntax:
`$target.function`.

The following functions are available to `Target` objects:

| Function | Type returned | Description | Note |
|---|---|---|---|
| `config` | `Hash[String, Data]` | The inventory configuration for the target. | This function returns the configuration set directly on the target in `inventory.yaml` or set in a plan using `Target.new` or `set_config()`. It does not return default configuration values or configuration set in Bolt configuration files.  |
| `facts` | `Hash[String, Data]` | The target's facts. | This function does not look up facts for a target and only returns the facts specified in an `inventory.yaml` file or set on a target during a plan run. |
| `features` | `Array[String]` | The target's features. ||
| `host` | `String` | The target's hostname. ||
| `name` | `String` | The target's human-readable name, or its URI if a name was not given. ||
| `password` | `String` | The password to use when connecting to the target. ||
| `plugin_hooks` | `Hash[String, Data]` | The target's `plugin_hooks` [configuration options](bolt_configuration_reference.md#plugin-hooks-configuration-options). ||
| `port` | `Integer` | The target's connection port. ||
| `protocol` | `String` | The protocol used to connect to the target. | This is equivalent to the target's `transport`, except for targets using the `remote` transport. For example, a target with the URI `http://example.com` using the `remote` transport would return `http` for the `protocol`. |
| `resources` | `Hash[String, ResourceInstance]` | The target's resources. | This function does not look up resources for a target and only returns resources set on a target during a plan run. |
| `safe_name` | `String` | The target's safe name. Equivalent to `name` if a name was given, or the target's `uri` with any password omitted. ||
| `target_alias` | `Variant[String, Array[String]]` | The target's aliases. ||
| `transport` | `String` | The transport used to connect to the target. ||
| `transport_config` | `Hash[String, Data]` | The merged configuration for the target's `transport`. | This function returns the merged configuration for a target's transport. This includes defaults, configuration set in `inventory.yaml`, configuration set in `bolt-defaults.yaml`, and configuration set in a plan using `set_config()`.|
| `uri` | `String` | The target's URI. ||
| `user` | `String` | The user to connect to the target. ||
| `vars` | `Hash[String, Data]` | The target's variables. ||
