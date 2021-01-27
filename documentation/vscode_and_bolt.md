# Setting up VS Code for Bolt

Bolt configuration and inventory files, as well as content such as plans and
task metadata, conform to particular specifications. Making your development
environment aware of these specifications gives you real-time validation and
data type checking as you write, speeding up the development cycle and reducing
errors.

## Validating configuration and inventory files with JSON schemas

You can validate Bolt's configuration and inventory files using JSON schemas
provided through the [Puppet Forge](https://forge.puppet.com). Configuring
Visual Studio Code (VS Code) to use Bolt's JSON schemas enables VS Code's live
IntelliSense feature, which gives you functionality like code completion and
parameter info for available fields in the files.

Bolt offers the following JSON schemas:

| Bolt file                                          | JSON schema                                             |
| -------------------------------------------------- | ------------------------------------------------------- |
| [`bolt-defaults.yaml`](bolt_defaults_reference.md) | https://forgeapi.puppet.com/schemas/bolt-defaults.json  |
| [`bolt-project.yaml`](bolt_project_reference.md)   | https://forgeapi.puppet.com/schemas/bolt-project.json   |
| [`inventory.yaml`](bolt_inventory_reference.md)    | https://forgeapi.puppet.com/schemas/bolt-inventory.json |
| [YAML plans](writing_yaml_plans.md)                | https://forgeapi.puppet.com/schemas/bolt-yaml-plan.json |

### Enabling schemas

To start using the JSON schemas with VS Code, follow these steps:

1. Install the [YAML
   extension](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml).

1. Open the [user or workspace settings
   file](https://code.visualstudio.com/docs/getstarted/settings) and add the
   following JSON:

    ```json
    {
      "yaml.schemas": {
        "https://forgeapi.puppet.com/schemas/bolt-defaults.json": [
          "bolt-defaults.yaml"
        ],
        "https://forgeapi.puppet.com/schemas/bolt-project.json": [
          "bolt-project.yaml"
        ],
        "https://forgeapi.puppet.com/schemas/bolt-inventory.json": [
          "inventory.yaml"
        ],
        "https://forgeapi.puppet.com/schemas/bolt-yaml-plan.json": [
          "plans/**/*.yaml"
        ]
      }
    }
    ```

📖 **Related information**

- [Configuring Bolt](configuring_bolt.md)
- [Inventory files](inventory_files.md)
- [VS Code settings
  file](https://code.visualstudio.com/docs/getstarted/settings)
- [VS Code YAML
  extension](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)

## Developing Bolt content with the Puppet VS Code Extension

Puppet offers a VS Code Extension that you can use when developing content for
your Bolt project. The Puppet VS Code Extension includes many powerful
features, including validation for task metadata files, live Intellisense for
Puppet plans, validating Puppetfiles, and more.

To install the Puppet VS Code Extension, see [How to start using the Puppet VS
Code Extension](https://puppet-vscode.github.io/docs/getting-started/).

📖 **Related information**

- [Puppet VS Code Extension
  documentation](https://puppet-vscode.github.io/docs/)
- [Puppet VS Code Extension
  features](https://puppet-vscode.github.io/docs/features/)
