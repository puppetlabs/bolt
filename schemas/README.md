# Bolt schemas

This directory includes several JSON schemas that can be used to validate
Bolt configuration files, including `bolt.yaml`, `inventory.yaml`, and
`bolt-project.yaml`.

## Using schemas with Visual Studio Code

### Prerequisites

- Install [Visual Studio Code](https://code.visualstudio.com/)

- Install the [YAML extension](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)

### Enabling schemas

1. Download and save each of the JSON files in this directory.

1. Open the [user or workspace settings file](https://code.visualstudio.com/docs/getstarted/settings).

1. Add the following content as a top-level key in the settings file:

    ```json
    "yaml.schemas": {
      "<path to bolt-project.schema.json>": [
        "bolt-project.yaml"
      ],
      "<path to bolt-config.schema.json>": [
        "bolt.yaml"
      ],
      "<path to bolt-inventory.schema.json>": [
        "inventory.yaml"
      ]
    }
    ```
