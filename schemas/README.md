# Bolt schemas

This directory includes several JSON schemas that can be used to validate Bolt
configuration and inventory files. These schemas are distributed via the Puppet
Forge.

More information about using the schemas can be found in [Setting up VS Code for
Bolt](../documentation/vscode_and_bolt.md).

## Generating schemas

Changes made to Bolt's source code may require regenerating the schemas. Bolt
includes a Rake task for generating the schemas from Bolt's source code.

To regenerate the schemas, run the following command:

```shell
$ bundle exec rake schemas:all
```

You can also regenerate individual schemas using the corresponding Rake task in
the `schemas` namespace. To view a list of available Rake tasks in the `schemas`
namespace, run the following command:

```shell
$ bundle exec rake -T schemas
```

## Schema definitions

Bolt's schemas are generated directly from Bolt source code and are built from
an array of top-level options and a hash of definitions for options available in
the given file. You can find Bolt's schema definitions in the following files:

- [Configuration definitions](https://github.com/puppetlabs/bolt/blob/main/lib/bolt/config/options.rb)
- [Transport configuration definitions](https://github.com/puppetlabs/bolt/blob/main/lib/bolt/config/transport/options.rb)
- [Inventory definitions](https://github.com/puppetlabs/bolt/blob/main/lib/bolt/inventory/options.rb)

The definitions hash is composed of key-value pairs, where the key is the name
of the configuration option and the value is the definition itself. A definition
includes keys defined by JSON Schema Draft 07 as well as some metadata keys used
by Bolt to generate documentation or validate configuration files.

For example, the following definition defines the `foo` option. The definition
restricts the value for this option to an array of strings and does not accept a
plugin reference:

```ruby
{
  "foo" => {
    description: "The foo option.",
    type: Array,
    items: {
      type: String
    },
    _plugin: false
  }
}
```

### Schema definition keys

The following keys are supported.

- **`:type`** `Class`

  **Required.** The expected type of a value. These should be Ruby classes, as
  this field is used to perform automatic type validation in Bolt. If an option
  can accept more than one type, this should be an array of classes. Boolean
  values shoudl set the `:type` key to `[TrueClass, FalseClass]`, as Ruby does
  not have a single Boolean class.

- **`:description`** `String`

  **Required.** A detailed description of the option and what it does. This
  field is used in both documentation and the JSON schemas, and should provide
  as much detail as possible, including links to relevant documentation.

- **`:properties`** `Hash`

  A hash where keys are sub-options and values are definitions for the
  sub-option. Similar to top-level options, properties can have a
  `:description`, `:type`, or any other key in this list.

- **`:additionalProperties`** `Hash`

  A variation of the `:properties` key, where the hash is a definition for any
  properties not explicitly listed under `:properties`. This can be used to
  permit arbitrary sub-options that still require a definition, such as log
  files for the `log` config option.

- **`:required`** `Array`

  An array of properties that are required for a hash value. In other words,
  sub-options that must be specified for the option.

- **`:items`** `Hash`

  A definition hash for items in an array. Only used when the value's type is an
  array. Similar to other definitions, this definition hash can use any other
  key, but must include the `:type` key at a minimum.

- **`:uniqueItems`** `Boolean`

  Whether or not an array should contain only unique items. Only used when the
  value's type is an array.

- **`:enum`** `Array`

  An array of acceptable values for a string.

- **`:pattern`** `String`

  A JSON regex pattern that the option's value should match. This key is only
  used by the generated JSON schemas and not by Bolt's validator.

- **`:format`** `String`

  Requires that a string matches a format defined by the JSON Schema draft. This
  key is only used by the generated JSON schemas and not by Bolt's validator.

- **`:minimum`** `Integer`

  An inclusive minimum for an integer value.

- **`:maximum`** `Integer`

  An inclusive maximum for an integer value.

- **`:_plugin`** `Boolean`

  Whether the option accepts a plugin reference. This is used when generating
  the JSON schemas to determine whether or not to include a reference to the
  `_plugin` definition. If `:_plugin` is set to `true`, the script that
  generates JSON schemas will automatically recurse through the `:items` and
  `:properties` keys and add a plugin reference if applicable.

  This key is also supported by Bolt's validator. If `:_plugin` is set to
  `true`, Bolt will not validate the option.

- **`:_ref`** `String`

  A reference to another definition in the schema. When Bolt's validator sees
  this key, it pulls the definition for the specified option and uses it for
  validation. This key is useful for options that can be nested within
  themselves, such as `groups` in an inventory file.

- **`:_example`** `Any`

  An example value for the option. This is used to generate reference
  documentation for Bolt's configuration files.

- **`:_default`** `Any`

  The documented default value for the option. This is _only_ used to generate
  reference documentation for Bolt's configuration files and is not used to
  actually set default values.
