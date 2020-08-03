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
