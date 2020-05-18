# Bolt schemas

This directory includes several JSON schemas that can be used to validate
Bolt configuration files, including `bolt.yaml`, `inventory.yaml`, and
`bolt-project.yaml`.

## Using schemas with Visual Studio Code

### Prerequisites

- Install [Visual Studio Code](https://code.visualstudio.com/)

- Install the [YAML extension](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)

### Enabling schemas

Open the [user or workspace settings file](https://code.visualstudio.com/docs/getstarted/settings) and add
the following:

```json
"yaml.schemas": {
  "https://forgeapi.puppet.com/schemas/bolt-project.json": [
    "bolt-project.yaml"
  ],
  "https://forgeapi.puppet.com/schemas/bolt-config.json": [
    "bolt.yaml"
  ],
  "https://forgeapi.puppet.com/schemas/bolt-inventory.json": [
    "inventory.yaml"
  ]
}
```
