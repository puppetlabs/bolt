# Analytics

Bolt collects data about how you use it to help the Bolt team make decisions
about how to improve it. You can opt out of providing this data.

## Opt out of data collection

You can opt out of data collection by modifying Bolt's analytics configuration
file. This file is located in the user's home directory at `<HOME
DIRECTORY>/.puppetlabs/etc/bolt/analytics.yaml`. To opt out of data collection,
add the following line to the file:

```yaml
disabled: true
```

## Data collected

Each time you run Bolt, it collects the following information and associates it
with a randomly generated, non-identifiable user UUID:

- Bolt version
- User locale
- Operating system and version
- The name of the executed command, such as `command run` or `task show`
- The names of built-in functions called from a plan
- Transports used and the number of targets using each transport
- The number of targets and groups defined in the inventory
- The number of targets targeted with a command
- The output format selected, such as `human` or `json`
- Whether the Bolt project directory was determined from the location of a
  `bolt-project.yaml` file or with the `--project` command-line option
- The number of times built-in tasks and plans are run
- The number of statements in a manifest block and how many resources that
  produces for each target
- The number of steps in a YAML plan
- The return type of a YAML plan, such as an expression or a value
- Which built-in plugins Bolt is using
- Topics viewed with `bolt guide <TOPIC>`
- IDs of any deprecation warnings

## Viewing collected data

To see the data Bolt collects, add the `--log-level trace` option to your Bolt
command or use `-LogLevel trace` if you're using PowerShell.
